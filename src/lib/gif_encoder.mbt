// GIF 编码支持

///|
pub struct GifEncoderOptions {
  width : Int
  height : Int
  global_color_table : @list.List[ColorTableEntry]?
  background_color_index : Int
  pixel_aspect_ratio : Int
  loop_count : Int // 0 = 无限循环
} derive(Show)

///|
pub fn create_gif_encoder_options(
  width : Int,
  height : Int,
  global_color_table : @list.List[ColorTableEntry]?,
  background_color_index : Int,
  pixel_aspect_ratio : Int,
  loop_count : Int,
) -> GifEncoderOptions {
  {
    width,
    height,
    global_color_table,
    background_color_index,
    pixel_aspect_ratio,
    loop_count,
  }
}

///|
pub struct GifFrameInput {
  descriptor : ImageDescriptor
  color_indexes : @list.List[Byte]
  local_color_table : @list.List[ColorTableEntry]?
  delay_time : Int
  disposal_method : Int
  transparent_index : Int?
} derive(Show)

///|
pub struct GifEncoder {
  options : GifEncoderOptions
  frames : Array[GifFrameInput]
} derive(Show)

///|
pub fn GifEncoder::new(options : GifEncoderOptions) -> GifEncoder {
  GifEncoder::{ options, frames: [] }
}

///|
pub fn GifEncoder::add_frame(
  self : GifEncoder,
  frame : GifFrameInput,
) -> Result[Unit, GifError] {
  if frame.descriptor.width <= 0 || frame.descriptor.height <= 0 {
    return Err(InvalidImageDescriptor)
  }
  let expected_pixels = frame.descriptor.width * frame.descriptor.height
  if frame.color_indexes.length() != expected_pixels {
    return Err(InvalidFormat)
  }
  if frame.disposal_method < 0 || frame.disposal_method > 7 {
    return Err(InvalidExtension)
  }
  self.frames.push(frame)
  Ok(())
}

///|
pub fn GifEncoder::frame_count(self : GifEncoder) -> Int {
  self.frames.length()
}

///|
pub fn GifEncoder::build(self : GifEncoder) -> Result[Bytes, GifError] {
  if self.options.width <= 0 || self.options.height <= 0 {
    return Err(InvalidLogicalScreen)
  }
  let buffer : Array[Byte] = []
  // header
  buffer.push(b'G')
  buffer.push(b'I')
  buffer.push(b'F')
  buffer.push(b'8')
  buffer.push(b'9')
  buffer.push(b'a')

  // logical screen descriptor
  append_u16_le(buffer, self.options.width)
  append_u16_le(buffer, self.options.height)
  let (global_flag, global_size_field, global_bytes) = match
    self.options.global_color_table {
    Some(table) => {
      let padded = pad_color_table(table)
      let size_field = calculate_table_size_field(padded.length())
      (true, size_field, Some(padded))
    }
    None => (false, 0, None)
  }
  let packed = pack_logical_screen_packed_field(
    global_flag, 7, false, global_size_field,
  )
  buffer.push(packed.to_byte())
  buffer.push(self.options.background_color_index.to_byte())
  buffer.push(self.options.pixel_aspect_ratio.to_byte())
  match global_bytes {
    Some(bytes) =>
      for b in bytes {
        buffer.push(b)
      }
    None => ()
  }
  if self.options.loop_count != 1 {
    write_loop_extension(buffer, self.options.loop_count)
  }
  for frame in self.frames {
    let has_transparency = match frame.transparent_index {
      Some(_) => true
      None => false
    }
    if frame.delay_time > 0 || has_transparency {
      write_graphic_control_ext(buffer, frame)
    }
    write_image_descriptor(buffer, frame.descriptor)
    match frame.local_color_table {
      Some(table) => {
        let padded = pad_color_table(table)
        for b in padded {
          buffer.push(b)
        }
      }
      None => ()
    }
    match write_image_data(frame, self.options.global_color_table) {
      Ok(bytes) =>
        for b in bytes {
          buffer.push(b)
        }
      Err(err) => return Err(err)
    }
  }
  buffer.push(trailer)
  Ok(Bytes::from_array(buffer))
}

///|
fn write_graphic_control_ext(
  buffer : Array[Byte],
  frame : GifFrameInput,
) -> Unit {
  buffer.push(extension_introducer)
  buffer.push(graphic_control_label)
  buffer.push(4) // block size
  let transparent_flag = match frame.transparent_index {
    Some(_) => 1
    None => 0
  }
  let packed = ((frame.disposal_method & 0x07) << 2) | transparent_flag
  buffer.push(packed.to_byte())
  append_u16_le(buffer, frame.delay_time)
  match frame.transparent_index {
    Some(idx) => buffer.push(idx.to_byte())
    None => buffer.push(0)
  }
  buffer.push(0)
}

///|
fn write_image_descriptor(
  buffer : Array[Byte],
  descriptor : ImageDescriptor,
) -> Unit {
  buffer.push(image_separator)
  append_u16_le(buffer, descriptor.left)
  append_u16_le(buffer, descriptor.top)
  append_u16_le(buffer, descriptor.width)
  append_u16_le(buffer, descriptor.height)
  let packed = pack_image_packed_field(
    descriptor.local_color_table_flag,
    descriptor.interlace_flag,
    descriptor.sort_flag,
    descriptor.local_color_table_size,
  )
  buffer.push(packed.to_byte())
}

///|
fn write_image_data(
  frame : GifFrameInput,
  global_color_table : @list.List[ColorTableEntry]?,
) -> Result[Array[Byte], GifError] {
  // 确定最小码长
  let color_table_size = match frame.local_color_table {
    Some(table) => table.length()
    None =>
      match global_color_table {
        Some(table) => table.length()
        None => 0
      }
  }
  let min_code_size = if color_table_size > 0 {
    max_int(2, required_bits(color_table_size))
  } else {
    8 // 没有调色板时回退
  }
  let compressed = match encode_indices(frame.color_indexes, min_code_size) {
    Ok(data) => data
    Err(err) => return Err(err)
  }
  let blocks : Array[Byte] = []
  blocks.push(min_code_size.to_byte())
  let mut cursor = 0
  while cursor < compressed.length() {
    let chunk = min_int(255, compressed.length() - cursor)
    blocks.push(chunk.to_byte())
    for i = 0; i < chunk; i = i + 1 {
      blocks.push(compressed[cursor + i])
    }
    cursor = cursor + chunk
  }
  blocks.push(0)
  Ok(blocks)
}

///|
fn encode_indices(
  indices : @list.List[Byte],
  min_code_size : Int,
) -> Result[Array[Byte], GifError] {
  if min_code_size < 2 || min_code_size > 11 {
    return Err(InvalidFormat)
  }
  let clear_code = 1 << min_code_size
  let end_code = clear_code + 1
  let code_size = min_code_size + 1
  let codes : Array[Int] = []
  codes.push(clear_code)
  for byte in indices {
    codes.push(byte.to_int())
  }
  codes.push(end_code)
  let mut buffer = 0
  let mut bit_count = 0
  let output : Array[Byte] = []
  for code in codes {
    buffer = buffer | (code << bit_count)
    bit_count = bit_count + code_size
    while bit_count >= 8 {
      output.push((buffer & 0xFF).to_byte())
      buffer = buffer >> 8
      bit_count = bit_count - 8
    }
  }
  if bit_count > 0 {
    output.push((buffer & 0xFF).to_byte())
  }
  Ok(output)
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn append_u16_le(buffer : Array[Byte], value : Int) -> Unit {
  buffer.push((value & 0xFF).to_byte())
  buffer.push(((value >> 8) & 0xFF).to_byte())
}

///|

///|
fn pad_color_table(table : @list.List[ColorTableEntry]) -> Array[Byte] {
  let entries = table.to_array()
  let required_entries = 1 << (calculate_table_size_field(entries.length()) + 1)
  let result : Array[Byte] = []
  for entry in entries {
    result.push(entry.red.to_byte())
    result.push(entry.green.to_byte())
    result.push(entry.blue.to_byte())
  }
  let filler = if entries.length() > 0 {
    entries[entries.length() - 1]
  } else {
    { red: 0, green: 0, blue: 0 }
  }
  for _i = entries.length(); _i < required_entries; _i = _i + 1 {
    result.push(filler.red.to_byte())
    result.push(filler.green.to_byte())
    result.push(filler.blue.to_byte())
  }
  result
}

///|
fn calculate_table_size_field(entry_count : Int) -> Int {
  let size = max_int(1, entry_count)
  let mut power = 0
  while 1 << (power + 1) < size && power < 7 {
    power = power + 1
  }
  power
}

///|
fn write_loop_extension(buffer : Array[Byte], loop_count : Int) -> Unit {
  buffer.push(extension_introducer)
  buffer.push(application_extension_label)
  buffer.push(11)
  let identifier_bytes = [
    b'N', b'E', b'T', b'S', b'C', b'A', b'P', b'E', b'2', b'.', b'0',
  ]
  for b in identifier_bytes {
    buffer.push(b)
  }
  buffer.push(3)
  buffer.push(1)
  append_u16_le(buffer, loop_count)
  buffer.push(0)
}

///|
fn required_bits(value : Int) -> Int {
  let mut bits = 0
  let mut temp = max_int(1, value - 1)
  while temp > 0 {
    bits = bits + 1
    temp = temp >> 1
  }
  max_int(bits, 2)
}

///|
pub fn create_frame_from_rgba(
  width : Int,
  height : Int,
  left : Int,
  top : Int,
  pixels : Array[RgbaColor],
  delay : Int,
  disposal_method : Int,
) -> Result[GifFrameInput, GifError] {
  if width <= 0 || height <= 0 {
    return Err(InvalidImageDescriptor)
  }
  if pixels.length() != width * height {
    return Err(InvalidFormat)
  }
  let palette : Array[ColorTableEntry] = []
  let indexes : Array[Byte] = []
  let mut transparent_index : Int? = None
  for pixel in pixels {
    if pixel.alpha == 0 {
      match transparent_index {
        Some(idx) => indexes.push(idx.to_byte())
        None => {
          let entry : ColorTableEntry = { red: 0, green: 0, blue: 0 }
          let idx = match find_or_insert_color(entry, palette) {
            Ok(value) => value
            Err(err) => return Err(err)
          }
          transparent_index = Some(idx)
          indexes.push(idx.to_byte())
        }
      }
    } else {
      let entry : ColorTableEntry = {
        red: clamp_color(pixel.red),
        green: clamp_color(pixel.green),
        blue: clamp_color(pixel.blue),
      }
      let idx = match find_or_insert_color(entry, palette) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      indexes.push(idx.to_byte())
    }
  }
  if palette.length() == 0 {
    palette.push({ red: 0, green: 0, blue: 0 })
    transparent_index = Some(0)
  }
  let descriptor = ImageDescriptor::{
    left,
    top,
    width,
    height,
    local_color_table_flag: true,
    interlace_flag: false,
    sort_flag: false,
    local_color_table_size: calculate_table_size_field(palette.length()),
  }
  let mut local_table = @list.new()
  let mut idx = palette.length() - 1
  while true {
    local_table = @list.cons(palette[idx], local_table)
    if idx == 0 {
      break
    }
    idx = idx - 1
  }
  Ok(GifFrameInput::{
    descriptor,
    color_indexes: array_bytes_to_list(indexes),
    local_color_table: Some(local_table),
    delay_time: delay,
    disposal_method,
    transparent_index,
  })
}

///|
fn find_or_insert_color(
  entry : ColorTableEntry,
  palette : Array[ColorTableEntry],
) -> Result[Int, GifError] {
  for i = 0; i < palette.length(); i = i + 1 {
    if palette[i] == entry {
      return Ok(i)
    }
  }
  if palette.length() >= 256 {
    return Err(InvalidColorTable)
  }
  palette.push(entry)
  Ok(palette.length() - 1)
}

///|
fn clamp_color(value : Int) -> Int {
  if value < 0 {
    0
  } else if value > 255 {
    255
  } else {
    value
  }
}
