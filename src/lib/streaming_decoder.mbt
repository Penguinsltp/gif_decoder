// GIF 流式解码器：面向大文件的增量解析

///|
pub struct StreamingDecoderOptions {
  decompress_image_data : Bool
  strict_mode : Bool
  compact_threshold : Int
} derive(Show)

///|
pub fn default_streaming_options() -> StreamingDecoderOptions {
  { decompress_image_data: true, strict_mode: true, compact_threshold: 4096 }
}

///|
pub enum StreamingEvent {
  Header(GifHeader, LogicalScreenDescriptor)
  GlobalColorTable(@list.List[ColorTableEntry])
  GraphicControl(GraphicControlExtension)
  Comment(CommentExtension)
  PlainText(PlainTextExtension)
  Application(ApplicationExtension)
  Image(ImageData, GraphicControlExtension?)
  Trailer
} derive(Show)

///|
pub struct StreamingGifDecoder {
  options : StreamingDecoderOptions
  mut buffer : Array[Byte]
  mut consumed : Int
  mut finished : Bool
  mut header : GifHeader?
  mut logical_screen : LogicalScreenDescriptor?
  mut global_table_emitted : Bool
  mut pending_graphic_control : GraphicControlExtension?
} derive(Show)

///|
pub fn StreamingGifDecoder::new(
  options : StreamingDecoderOptions,
) -> StreamingGifDecoder {
  {
    options,
    buffer: [],
    consumed: 0,
    finished: false,
    header: None,
    logical_screen: None,
    global_table_emitted: false,
    pending_graphic_control: None,
  }
}

///|
/// 处理一个输入数据块并产出流式事件
pub fn StreamingGifDecoder::process_chunk(
  self : StreamingGifDecoder,
  chunk : Bytes,
) -> Result[@list.List[StreamingEvent], GifError] {
  if self.finished {
    return Ok(@list.new())
  }
  for i = 0; i < chunk.length(); i = i + 1 {
    self.buffer.push(chunk[i])
  }
  let produced : Array[StreamingEvent] = []
  while true {
    let mut progressed = false
    let header_missing = match self.header {
      Some(_) => false
      None => true
    }
    if header_missing {
      if self.buffer.length() - self.consumed < 13 {
        break
      }
      let header_bytes = slice_to_bytes(self.buffer, 0, 13)
      let header = match parse_gif_header(header_bytes) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      let (logical_screen, _) = match
        parse_logical_screen_descriptor_block(header_bytes) {
        Ok(result) => result
        Err(err) => return Err(err)
      }
      self.header = Some(header)
      self.logical_screen = Some(logical_screen)
      self.consumed = 13
      produced.push(Header(header, logical_screen))
      progressed = true
    } else if !self.global_table_emitted {
      match self.logical_screen {
        Some(screen) =>
          if has_global_color_table(screen) {
            let entries = calculate_color_table_size(
              screen.global_color_table_size,
            )
            let total_bytes = entries * 3
            if self.buffer.length() - self.consumed < total_bytes {
              break
            }
            let parse_result = parse_color_table_from_bytes(
              slice_to_bytes(self.buffer, self.consumed, total_bytes),
              0,
              entries,
            )
            match parse_result {
              Ok((colors, _)) => {
                self.consumed = self.consumed + total_bytes
                self.global_table_emitted = true
                produced.push(GlobalColorTable(colors))
                progressed = true
              }
              Err(err) => return Err(err)
            }
          } else {
            self.global_table_emitted = true
            progressed = true
          }
        None => break
      }
    } else {
      if self.buffer.length() - self.consumed == 0 {
        break
      }
      let tag = self.buffer[self.consumed]
      if tag == trailer {
        self.consumed = self.consumed + 1
        self.finished = true
        produced.push(Trailer)
        progressed = true
      } else if tag == image_separator {
        match self.try_parse_image_block() {
          Some((image_data, consumed_bytes)) => {
            self.consumed = self.consumed + consumed_bytes
            produced.push(Image(image_data, self.pending_graphic_control))
            self.pending_graphic_control = None
            progressed = true
          }
          None => break
        }
      } else if tag == extension_introducer {
        match self.try_parse_extension_block() {
          Some((event, consumed_bytes)) => {
            self.consumed = self.consumed + consumed_bytes
            match event {
              Some(GraphicControl(gce)) => {
                self.pending_graphic_control = Some(gce)
                produced.push(GraphicControl(gce))
              }
              Some(Comment(comment)) => produced.push(Comment(comment))
              Some(PlainText(plain)) => produced.push(PlainText(plain))
              Some(Application(app)) => produced.push(Application(app))
              None => ()
            }
            progressed = true
          }
          None => break
        }
      } else {
        return Err(InvalidFormat)
      }
    }
    if !progressed {
      break
    }
  }
  self.compact_buffer()
  Ok(events_array_to_list(produced))
}

///|
pub fn StreamingGifDecoder::is_finished(self : StreamingGifDecoder) -> Bool {
  self.finished
}

///|
pub fn StreamingGifDecoder::finish(
  self : StreamingGifDecoder,
) -> Result[Unit, GifError] {
  if !self.finished && self.buffer.length() - self.consumed > 0 {
    return Err(UnexpectedEndOfFile)
  }
  Ok(())
}

///|
fn StreamingGifDecoder::available(self : StreamingGifDecoder) -> Int {
  self.buffer.length() - self.consumed
}

///|
fn StreamingGifDecoder::compact_buffer(self : StreamingGifDecoder) -> Unit {
  if self.consumed == 0 {
    return
  }
  if self.consumed >= self.buffer.length() {
    self.buffer = []
    self.consumed = 0
    return
  }
  if self.buffer.length() > self.options.compact_threshold {
    let new_buffer : Array[Byte] = []
    for i = self.consumed; i < self.buffer.length(); i = i + 1 {
      new_buffer.push(self.buffer[i])
    }
    self.buffer = new_buffer
    self.consumed = 0
  }
}

///|
fn StreamingGifDecoder::try_parse_image_block(
  self : StreamingGifDecoder,
) -> (ImageData, Int)? {
  let available = self.available()
  if available < 10 {
    return None
  }
  let start = self.consumed
  let (descriptor, after_descriptor) = match
    parse_image_descriptor_block(slice_to_bytes(self.buffer, start, 10), 0) {
    Ok(result) => (result.0, result.1)
    Err(_) => return None
  }
  let mut cursor = start + after_descriptor
  let mut local_table : @list.List[ColorTableEntry]? = None
  if has_local_color_table(descriptor) {
    let entries = calculate_color_table_size(descriptor.local_color_table_size)
    let total_bytes = entries * 3
    if self.buffer.length() - cursor < total_bytes {
      return None
    }
    match
      parse_color_table_from_bytes(
        slice_to_bytes(self.buffer, cursor, total_bytes),
        0,
        entries,
      ) {
      Ok((colors, _)) => {
        local_table = Some(colors)
        cursor = cursor + total_bytes
      }
      Err(_) => return None
    }
  }
  if self.buffer.length() - cursor < 1 {
    return None
  }
  let min_code_size = self.buffer[cursor].to_int()
  cursor = cursor + 1
  match self.try_collect_sub_blocks(cursor) {
    Some((compressed, next_cursor)) => {
      cursor = next_cursor
      if !self.options.decompress_image_data {
        let raw_indices = array_bytes_to_list(compressed)
        return Some(
          (
            ImageData::{
              descriptor,
              local_color_table: local_table,
              image_data: raw_indices,
            },
            cursor - start,
          ),
        )
      }
      let compressed_list = array_bytes_to_list(compressed)
      match decode_lzw(compressed_list, min_code_size) {
        Ok(decoded) => {
          let expected = descriptor.width * descriptor.height
          match
            normalize_pixel_data(decoded, expected, self.options.strict_mode) {
            Ok(pixels) =>
              Some(
                (
                  ImageData::{
                    descriptor,
                    local_color_table: local_table,
                    image_data: pixels,
                  },
                  cursor - start,
                ),
              )
            Err(_) => None
          }
        }
        Err(_) => None
      }
    }
    None => None
  }
}

///|
fn StreamingGifDecoder::try_parse_extension_block(
  self : StreamingGifDecoder,
) -> (ExtensionType?, Int)? {
  if self.available() < 2 {
    return None
  }
  let start = self.consumed
  let label = self.buffer[start + 1]
  if label == graphic_control_label {
    if self.buffer.length() - start < 8 {
      return None
    }
    match
      parse_graphic_control_block(slice_to_bytes(self.buffer, start, 8), 0) {
      Ok((gce, _)) => Some((Some(GraphicControl(gce)), 8))
      Err(_) => None
    }
  } else if label == comment_label {
    match self.try_collect_sub_blocks(start + 2) {
      Some((data, next)) =>
        Some(
          (
            Some(
              Comment(CommentExtension::{
                comment_data: array_bytes_to_list(data),
              }),
            ),
            next - start,
          ),
        )
      None => None
    }
  } else if label == plain_text_label {
    if self.buffer.length() - start < 15 {
      return None
    }
    match
      parse_plain_text_block(
        slice_to_end_bytes(self.buffer, start),
        0,
        self.options.strict_mode,
      ) {
      Ok((plain, consumed)) => Some((Some(PlainText(plain)), consumed))
      Err(_) => None
    }
  } else if label == application_extension_label {
    match
      parse_application_extension_block(
        slice_to_end_bytes(self.buffer, start),
        0,
        self.options.strict_mode,
      ) {
      Ok((app, consumed)) => Some((Some(Application(app)), consumed))
      Err(_) => None
    }
  } else {
    match self.try_collect_sub_blocks(start + 2) {
      Some((_, next)) => Some((None, next - start))
      None => None
    }
  }
}

///|
fn StreamingGifDecoder::try_collect_sub_blocks(
  self : StreamingGifDecoder,
  offset : Int,
) -> (Array[Byte], Int)? {
  let mut cursor = offset
  let collected : Array[Byte] = []
  while cursor < self.buffer.length() {
    let block_size = self.buffer[cursor].to_int()
    cursor = cursor + 1
    if block_size < 0 || block_size > 255 {
      return None
    }
    if block_size == 0 {
      return Some((collected, cursor))
    }
    if self.buffer.length() - cursor < block_size {
      return None
    }
    for i = 0; i < block_size; i = i + 1 {
      collected.push(self.buffer[cursor + i])
    }
    cursor = cursor + block_size
  }
  None
}

///|
fn events_array_to_list(
  events : Array[StreamingEvent],
) -> @list.List[StreamingEvent] {
  let mut list = @list.new()
  let mut index = events.length()
  while index > 0 {
    index = index - 1
    list = @list.cons(events[index], list)
  }
  list
}

///|
fn slice_to_bytes(buffer : Array[Byte], start : Int, length : Int) -> Bytes {
  let segment : Array[Byte] = []
  for i = 0; i < length; i = i + 1 {
    if start + i < buffer.length() {
      segment.push(buffer[start + i])
    }
  }
  Bytes::from_array(segment)
}

///|
fn slice_to_end_bytes(buffer : Array[Byte], start : Int) -> Bytes {
  let segment : Array[Byte] = []
  for i = start; i < buffer.length(); i = i + 1 {
    segment.push(buffer[i])
  }
  Bytes::from_array(segment)
}
