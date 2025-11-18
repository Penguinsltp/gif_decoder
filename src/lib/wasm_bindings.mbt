// WebAssembly 导出接口

///|
pub fn wasm_decode_gif_summary(data : Bytes) -> Result[String, String] {
  match parse_gif_info(data) {
    Ok(info) => {
      let summary = "GIF ".to_string() +
        info.version +
        " " +
        info.width.to_string() +
        "x" +
        info.height.to_string() +
        " colors:" +
        info.global_color_table_size.to_string()
      Ok(summary)
    }
    Err(msg) => Err(msg)
  }
}

///|
pub fn wasm_optimize_gif(data : Bytes) -> Result[String, String] {
  match parse_gif(data) {
    Ok(gif) => {
      let (optimized, report) = optimize_gif(
        gif,
        default_optimization_options(),
      )
      let summary = "frames=".to_string() +
        optimized.data_blocks.length().to_string() +
        " removed=" +
        report.removed_frames.to_string()
      Ok(summary)
    }
    Err(err) => Err(gif_error_message(err))
  }
}

///|
pub fn wasm_stream_decode(
  data : Bytes,
  chunk_size : Int,
) -> Result[Int, String] {
  if chunk_size <= 0 {
    return Err("chunk_size must be > 0")
  }
  let decoder = StreamingGifDecoder::new(default_streaming_options())
  let mut processed = 0
  let mut emitted = 0
  while processed < data.length() {
    let remaining = data.length() - processed
    let size = if remaining < chunk_size { remaining } else { chunk_size }
    let slice = slice_bytes_range(data, processed, size)
    match decoder.process_chunk(slice) {
      Ok(events) => emitted = emitted + events.length()
      Err(err) => return Err(gif_error_message(err))
    }
    processed = processed + size
  }
  Ok(emitted)
}

///|
pub fn wasm_encode_single_frame(
  pixels : Array[RgbaColor],
  width : Int,
  height : Int,
) -> Result[Bytes, String] {
  match create_frame_from_rgba(width, height, 0, 0, pixels, 0, 0) {
    Ok(frame) => {
      let options = GifEncoderOptions::{
        width,
        height,
        global_color_table: None,
        background_color_index: 0,
        pixel_aspect_ratio: 0,
        loop_count: 0,
      }
      let encoder = GifEncoder::new(options)
      match encoder.add_frame(frame) {
        Ok(_) => ()
        Err(err) => return Err(gif_error_message(err))
      }
      match encoder.build() {
        Ok(bytes) => Ok(bytes)
        Err(err) => Err(gif_error_message(err))
      }
    }
    Err(err) => Err(gif_error_message(err))
  }
}

///|
fn slice_bytes_range(data : Bytes, start : Int, len : Int) -> Bytes {
  let array : Array[Byte] = []
  for i = 0; i < len && start + i < data.length(); i = i + 1 {
    array.push(data[start + i])
  }
  Bytes::from_array(array)
}

///|
fn gif_error_message(err : GifError) -> String {
  match err {
    InvalidHeader => "InvalidHeader".to_string()
    InvalidLogicalScreen => "InvalidLogicalScreen".to_string()
    InvalidColorTable => "InvalidColorTable".to_string()
    InvalidImageDescriptor => "InvalidImageDescriptor".to_string()
    InvalidExtension => "InvalidExtension".to_string()
    InvalidFormat => "InvalidFormat".to_string()
    LzwDecodingError => "LzwDecodingError".to_string()
    NoColorTable => "NoColorTable".to_string()
    UnsupportedFeature => "UnsupportedFeature".to_string()
    DataCorrupted => "DataCorrupted".to_string()
    UnexpectedEndOfFile => "UnexpectedEndOfFile".to_string()
    InvalidBlockSize(size) =>
      "InvalidBlockSize(".to_string() + size.to_string() + ")"
  }
}
