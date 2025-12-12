// GIF 解码器主模块 - 简化实用版本

///|
/// 基础的GIF解码功能
pub fn decode_gif_basic(data : Bytes) -> Result[String, String] {
  // 检查最小文件大小
  if data.length() < 13 {
    return Err("File too small to be a valid GIF")
  }

  // 检查GIF签名
  let signature = bytes_to_string(data, 0, 3)
  if signature != "GIF" {
    return Err("Invalid GIF signature")
  }

  // 检查版本
  let version = bytes_to_string(data, 3, 3)
  if version != "87a" && version != "89a" {
    return Err("Unsupported GIF version: " + version)
  }

  // 读取逻辑屏幕描述符
  let width = to_u16_le(data[6], data[7])
  let height = to_u16_le(data[8], data[9])

  // 读取packed字段
  let packed = data[10].to_int()
  let has_global_color_table = (packed & 0x80) != 0
  let global_color_table_size = 1 << ((packed & 0x07) + 1)
  let result = "GIF " +
    version +
    " - " +
    width.to_string() +
    "x" +
    height.to_string()
  if has_global_color_table {
    Ok(
      result +
      " (Global color table: " +
      global_color_table_size.to_string() +
      " colors)",
    )
  } else {
    Ok(result + " (No global color table)")
  }
}

///|
/// GIF信息结构
pub struct GifInfo {
  version : String
  width : Int
  height : Int
  has_global_color_table : Bool
  global_color_table_size : Int
  color_resolution : Int
  sort_flag : Bool
  bg_color_index : Int
  pixel_aspect_ratio : Int
} derive(Show)

///|
/// GIF 解析选项
pub struct GifParseOptions {
  decompress_image_data : Bool
  strict_mode : Bool
  max_pixels : Int?
} derive(Show)

///|
/// 默认解析选项
pub fn default_parse_options() -> GifParseOptions {
  { decompress_image_data: true, strict_mode: true, max_pixels: None }
}

///|
pub fn create_parse_options(
  decompress_image_data : Bool,
  strict_mode : Bool,
  max_pixels : Int?,
) -> GifParseOptions {
  { decompress_image_data, strict_mode, max_pixels }
}

///|
/// 更详细的GIF信息解析
pub fn parse_gif_info(data : Bytes) -> Result[GifInfo, String] {
  if data.length() < 13 {
    return Err("File too small")
  }

  // 解析头部
  let signature = bytes_to_string(data, 0, 3)
  let version = bytes_to_string(data, 3, 3)
  if signature != "GIF" {
    return Err("Not a GIF file")
  }
  if version != "87a" && version != "89a" {
    return Err("Unsupported version: " + version)
  }

  // 解析逻辑屏幕描述符
  let width = to_u16_le(data[6], data[7])
  let height = to_u16_le(data[8], data[9])
  let packed = data[10].to_int()
  let bg_color_index = data[11].to_int()
  let pixel_aspect_ratio = data[12].to_int()

  // 解析packed字段
  let has_global_color_table = (packed & 0x80) != 0
  let color_resolution = ((packed >> 4) & 0x07) + 1
  let sort_flag = (packed & 0x08) != 0
  let global_color_table_size = 1 << ((packed & 0x07) + 1)
  Ok(GifInfo::{
    version,
    width,
    height,
    has_global_color_table,
    global_color_table_size,
    color_resolution,
    sort_flag,
    bg_color_index,
    pixel_aspect_ratio,
  })
}

///|
/// 颜色表条目
pub struct ColorEntry {
  red : Int
  green : Int
  blue : Int
} derive(Show, Eq)

///|
/// 解析全局颜色表
pub fn parse_global_color_table(
  data : Bytes,
  offset : Int,
  size : Int,
) -> Result[Array[ColorEntry], String] {
  let total_bytes = size * 3
  if offset + total_bytes > data.length() {
    return Err("Insufficient data for color table")
  }
  let colors : Array[ColorEntry] = []
  for i = 0; i < size; i = i + 1 {
    let base = offset + i * 3
    colors.push(ColorEntry::{
      red: data[base].to_int(),
      green: data[base + 1].to_int(),
      blue: data[base + 2].to_int(),
    })
  }
  Ok(colors)
}

///|
/// 查找图像描述符
pub fn find_image_descriptor(
  data : Bytes,
  start_offset : Int,
) -> Result[Int, String] {
  let mut offset = start_offset
  while offset < data.length() {
    let separator = data[offset]
    if separator.to_int() == 0x2C { // Image Separator
      return Ok(offset)
    } else if separator.to_int() == 0x21 { // Extension Introducer
      // 跳过扩展
      if offset + 1 < data.length() {
        offset = offset + 2

        // 跳过数据子块
        match skip_data_sub_blocks(data, offset) {
          Ok(new_offset) => offset = new_offset
          Err(msg) => return Err("Extension parsing error: " + msg)
        }
      } else {
        return Err("Truncated extension")
      }
    } else if separator.to_int() == 0x3B { // Trailer
      return Err("No image found (reached trailer)")
    } else {
      offset = offset + 1
    }
  }
  Err("No image descriptor found")
}

///|
/// 跳过数据子块
fn skip_data_sub_blocks(
  data : Bytes,
  start_offset : Int,
) -> Result[Int, String] {
  let mut offset = start_offset
  while true {
    if offset >= data.length() {
      return Err("Unexpected end of data")
    }
    let block_size = data[offset].to_int()
    offset = offset + 1
    if block_size == 0 {
      return Ok(offset)
    }
    offset = offset + block_size
    if offset > data.length() {
      return Err("Block extends beyond data")
    }
  }
  Err("Should not reach here")
}

///|
/// 图像描述符（使用不同的名字避免冲突）
pub struct ImageDesc {
  left : Int
  top : Int
  width : Int
  height : Int
  has_local_color_table : Bool
  interlaced : Bool
  sorted : Bool
  local_color_table_size : Int
} derive(Show)

///|
/// 解析图像描述符
pub fn parse_image_descriptor(
  data : Bytes,
  offset : Int,
) -> Result[(ImageDesc, Int), String] {
  if offset + 9 > data.length() {
    return Err("Insufficient data for image descriptor")
  }
  if data[offset].to_int() != 0x2C {
    return Err("Invalid image separator")
  }
  let left = to_u16_le(data[offset + 1], data[offset + 2])
  let top = to_u16_le(data[offset + 3], data[offset + 4])
  let width = to_u16_le(data[offset + 5], data[offset + 6])
  let height = to_u16_le(data[offset + 7], data[offset + 8])
  let packed = data[offset + 9].to_int()
  let has_local_color_table = (packed & 0x80) != 0
  let interlaced = (packed & 0x40) != 0
  let sorted = (packed & 0x20) != 0
  let local_color_table_size = if has_local_color_table {
    1 << ((packed & 0x07) + 1)
  } else {
    0
  }
  let descriptor = ImageDesc::{
    left,
    top,
    width,
    height,
    has_local_color_table,
    interlaced,
    sorted,
    local_color_table_size,
  }
  Ok((descriptor, offset + 10))
}

///|
/// 创建 ImageData 结构（使用gif_types中的定义）
pub fn create_image_data(
  desc : ImageDesc,
  image_data : @list.List[Byte],
) -> ImageData {
  let descriptor = ImageDescriptor::{
    left: desc.left,
    top: desc.top,
    width: desc.width,
    height: desc.height,
    local_color_table_flag: desc.has_local_color_table,
    interlace_flag: desc.interlaced,
    sort_flag: desc.sorted,
    local_color_table_size: desc.local_color_table_size,
  }
  ImageData::{ descriptor, local_color_table: None, image_data }
}

///|
/// 创建 GIF 数据块列表
pub fn create_gif_data_blocks() -> @list.List[GifDataBlock] {
  let image_desc = ImageDesc::{
    left: 0,
    top: 0,
    width: 16,
    height: 16,
    has_local_color_table: false,
    interlaced: false,
    sorted: false,
    local_color_table_size: 0,
  }
  let image_data = create_image_data(
    image_desc,
    @list.List::from_array([b'T', b'e', b's', b't']),
  )
  let app_ext = ApplicationExtension::{
    application_identifier: "NETSCAPE",
    application_auth_code: "2.0",
    application_data: @list.List::from_array([b'1', b'0']),
  }
  @list.List::from_array([
    Extension(Application(app_ext)),
    Image(image_data),
    Trailer,
  ])
}

///|
/// 主要的GIF解码函数
pub fn decode_gif_complete(data : Bytes) -> Result[String, String] {
  // 解析基本信息
  match parse_gif_info(data) {
    Ok(info) => {
      let mut result = "GIF " +
        info.version +
        " " +
        info.width.to_string() +
        "x" +
        info.height.to_string()
      let mut offset = 13 // 头部 + 逻辑屏幕描述符

      // 如果有全局颜色表，跳过它
      if info.has_global_color_table {
        offset = offset + info.global_color_table_size * 3
        result = result +
          " (Global colors: " +
          info.global_color_table_size.to_string() +
          ")"
      }

      // 查找图像
      match find_image_descriptor(data, offset) {
        Ok(img_offset) =>
          match parse_image_descriptor(data, img_offset) {
            Ok((img_desc, _)) => {
              result = result +
                " Image: " +
                img_desc.width.to_string() +
                "x" +
                img_desc.height.to_string()
              if img_desc.interlaced {
                result = result + " (interlaced)"
              }
              if img_desc.has_local_color_table {
                result = result +
                  " (local colors: " +
                  img_desc.local_color_table_size.to_string() +
                  ")"
              }
              Ok(result)
            }
            Err(msg) => Err("Image descriptor error: " + msg)
          }
        Err(msg) => Err("Image search error: " + msg)
      }
    }
    Err(msg) => Err("Header parsing error: " + msg)
  }
}

///|
/// 解析扩展块信息
pub fn parse_extension_info(
  data : Bytes,
  offset : Int,
) -> Result[(String, Int), String] {
  if offset + 1 >= data.length() {
    return Err("Extension data insufficient")
  }
  let label = data[offset + 1]
  let extension_name = match label.to_int() {
    0xF9 => "Graphic Control"
    0xFE => "Comment"
    0x01 => "Plain Text"
    0xFF => "Application"
    _ => "Unknown Extension"
  }
  match skip_data_sub_blocks(data, offset + 2) {
    Ok(new_offset) => Ok((extension_name, new_offset))
    Err(e) => Err("Failed to skip extension block: " + e)
  }
}

///|
/// 分析GIF文件结构
pub fn analyze_gif_structure(data : Bytes) -> Result[String, String] {
  match parse_gif_info(data) {
    Ok(info) => {
      let mut result = "GIF " + info.version + " Structure Analysis:\n"
      result = result +
        "Canvas: " +
        info.width.to_string() +
        "x" +
        info.height.to_string() +
        "\n"
      let mut offset = 13
      if info.has_global_color_table {
        result = result +
          "Global Color Table: " +
          info.global_color_table_size.to_string() +
          " colors\n"
        offset = offset + info.global_color_table_size * 3
      } else {
        result = result + "No Global Color Table\n"
      }
      let mut image_count = 0
      let mut extension_count = 0
      let extensions : Array[String] = []
      while offset < data.length() {
        let separator = data[offset]
        match separator.to_int() {
          0x2C => {
            // 图像块
            image_count = image_count + 1
            match parse_image_descriptor(data, offset) {
              Ok((desc, new_offset)) => {
                offset = new_offset
                if desc.has_local_color_table {
                  offset = offset + desc.local_color_table_size * 3
                }
                if offset < data.length() {
                  match skip_data_sub_blocks(data, offset + 1) {
                    Ok(next_offset) => offset = next_offset
                    Err(_) => break
                  }
                } else {
                  break
                }
              }
              Err(_) => break
            }
          }
          0x21 => {
            // 扩展块
            extension_count = extension_count + 1
            match parse_extension_info(data, offset) {
              Ok((ext_name, new_offset)) => {
                extensions.push(ext_name)
                offset = new_offset
              }
              Err(_) => break
            }
          }
          0x3B => {
            result = result + "Found trailer\n"
            break
          }
          _ => {
            result = result +
              "Unknown block type: " +
              separator.to_int().to_string() +
              "\n"
            break
          }
        }
      }
      result = result + "Images: " + image_count.to_string() + "\n"
      result = result + "Extensions: " + extension_count.to_string()
      if extensions.length() > 0 {
        result = result + " ("
        for i = 0; i < extensions.length(); i = i + 1 {
          if i > 0 {
            result = result + ", "
          }
          result = result + extensions[i]
        }
        result = result + ")"
      }
      Ok(result)
    }
    Err(e) => Err("Analysis failed: " + e)
  }
}

///|
/// 创建测试用的完整GIF数据
pub fn create_test_gif_data() -> Bytes {
  let data : Array[Byte] = []

  // GIF89a 签名
  data.append([b'G', b'I', b'F', b'8', b'9', b'a'])

  // 逻辑屏幕描述符: 16x16, 有2色全局颜色表
  data.append([16, 0, 16, 0]) // 宽度和高度 (小端序)
  data.append([0x80]) // 有全局颜色表，1位颜色深度
  data.append([0, 0]) // 背景色索引和像素宽高比

  // 全局颜色表 (2色: 黑色和白色)
  data.append([0, 0, 0]) // 黑色
  data.append([255, 255, 255]) // 白色

  // 图像描述符
  data.append([0x2C]) // 图像分隔符
  data.append([0, 0, 0, 0]) // 左上角位置
  data.append([16, 0, 16, 0]) // 图像大小
  data.append([0x00]) // 无局部颜色表，不交错

  // LZW 最小码长
  data.append([2])

  // 图像数据（简化的）
  data.append([4]) // 子块大小
  data.append([1, 1, 1, 1]) // 简单的图像数据
  data.append([0]) // 块终止符

  // GIF结束符
  data.append([0x3B])
  Bytes::from_array(data)
}

///|
pub fn rebuild_gif(gif : Gif, data_blocks : @list.List[GifDataBlock]) -> Gif {
  Gif::{
    header: gif.header,
    logical_screen: gif.logical_screen,
    global_color_table: gif.global_color_table,
    data_blocks,
  }
}

///|
/// 全新的 GIF 解析 API
pub fn parse_gif(data : Bytes) -> Result[Gif, GifError] {
  parse_gif_with_options(data, default_parse_options())
}

///|
/// 可配置选项的 Gif 解析流程
pub fn parse_gif_with_options(
  data : Bytes,
  options : GifParseOptions,
) -> Result[Gif, GifError] {
  if data.length() < 13 {
    return Err(InvalidFormat)
  }
  let header = match parse_gif_header(data) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (logical_screen, descriptor_offset) = match
    parse_logical_screen_descriptor_block(data) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let mut offset = descriptor_offset
  match validate_logical_screen(logical_screen) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  match options.max_pixels {
    Some(limit) => {
      let total_pixels = logical_screen.screen_width *
        logical_screen.screen_height
      if total_pixels > limit {
        return Err(InvalidFormat)
      }
    }
    None => ()
  }
  let mut global_color_table : @list.List[ColorTableEntry]? = None
  if has_global_color_table(logical_screen) {
    let entries = calculate_color_table_size(
      logical_screen.global_color_table_size,
    )
    match parse_color_table_from_bytes(data, offset, entries) {
      Ok((colors, next_offset)) => {
        global_color_table = Some(colors)
        offset = next_offset
      }
      Err(err) => return Err(err)
    }
  }
  let mut blocks = @list.new()
  let mut found_trailer = false
  while offset < data.length() {
    let tag = data[offset]
    match tag {
      b'\x2C' =>
        match
          parse_image_block(
            data,
            offset,
            options.decompress_image_data,
            options.strict_mode,
          ) {
          Ok((image_block, new_offset)) => {
            blocks = @list.cons(GifDataBlock::Image(image_block), blocks)
            offset = new_offset
          }
          Err(err) => return Err(err)
        }
      b'\x21' =>
        match parse_extension_block(data, offset, options.strict_mode) {
          Ok((extension, new_offset)) => {
            match extension {
              Some(ext) =>
                blocks = @list.cons(GifDataBlock::Extension(ext), blocks)
              None => ()
            }
            offset = new_offset
          }
          Err(err) => return Err(err)
        }
      b'\x3B' => {
        blocks = @list.cons(Trailer, blocks)
        offset = offset + 1
        found_trailer = true
        break
      }
      _ => return Err(InvalidFormat)
    }
  }
  if options.strict_mode && !found_trailer {
    return Err(InvalidFormat)
  }
  Ok({ header, logical_screen, global_color_table, data_blocks: blocks.rev() })
}

///|
pub fn parse_gif_header(data : Bytes) -> Result[GifHeader, GifError] {
  if data.length() < 6 {
    return Err(InvalidHeader)
  }
  let signature = bytes_to_string(data, 0, 3)
  let version = bytes_to_string(data, 3, 3)
  let header = GifHeader::{ signature, version }
  match validate_gif_header(header) {
    Ok(_) => Ok(header)
    Err(err) => Err(err)
  }
}

///|
pub fn parse_logical_screen_descriptor_block(
  data : Bytes,
) -> Result[(LogicalScreenDescriptor, Int), GifError] {
  if data.length() < 13 {
    return Err(InvalidLogicalScreen)
  }
  let width = to_u16_le(data[6], data[7])
  let height = to_u16_le(data[8], data[9])
  let packed = data[10].to_int()
  let bg_color_index = data[11].to_int()
  let aspect_ratio = data[12].to_int()
  let (
    global_color_table_flag,
    color_resolution,
    sort_flag,
    global_color_table_size,
  ) = unpack_logical_screen_packed_field(packed)
  let descriptor = LogicalScreenDescriptor::{
    screen_width: width,
    screen_height: height,
    global_color_table_flag,
    color_resolution,
    sort_flag,
    global_color_table_size,
    background_color_index: bg_color_index,
    pixel_aspect_ratio: aspect_ratio,
  }
  Ok((descriptor, 13))
}

///|
pub fn parse_color_table_from_bytes(
  data : Bytes,
  offset : Int,
  entry_count : Int,
) -> Result[(@list.List[ColorTableEntry], Int), GifError] {
  if entry_count == 0 {
    return Ok((@list.new(), offset))
  }
  let total_bytes = entry_count * 3
  if offset + total_bytes > data.length() {
    return Err(InvalidColorTable)
  }
  let mut colors = @list.new()
  for i = 0; i < entry_count; i = i + 1 {
    let base = offset + i * 3
    let entry = ColorTableEntry::{
      red: data[base].to_int(),
      green: data[base + 1].to_int(),
      blue: data[base + 2].to_int(),
    }
    colors = @list.cons(entry, colors)
  }
  Ok((colors.rev(), offset + total_bytes))
}

///|
fn parse_image_block(
  data : Bytes,
  offset : Int,
  decompress_pixels : Bool,
  strict_mode : Bool,
) -> Result[(ImageData, Int), GifError] {
  let (descriptor, descriptor_offset) = match
    parse_image_descriptor_block(data, offset) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let mut cursor = descriptor_offset
  let local_colors = if has_local_color_table(descriptor) {
    let entries = calculate_color_table_size(descriptor.local_color_table_size)
    match parse_color_table_from_bytes(data, cursor, entries) {
      Ok((colors, after_table)) => {
        cursor = after_table
        Some(colors)
      }
      Err(err) => return Err(err)
    }
  } else {
    None
  }
  if cursor >= data.length() {
    return Err(UnexpectedEndOfFile)
  }
  let min_code_size = data[cursor].to_int()
  cursor = cursor + 1
  let (compressed, next_cursor) = match collect_sub_blocks(data, cursor) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  cursor = next_cursor
  if !decompress_pixels {
    let raw_indices = array_bytes_to_list(compressed)
    return Ok(
      (
        ImageData::{
          descriptor,
          local_color_table: local_colors,
          image_data: raw_indices,
        },
        cursor,
      ),
    )
  }
  let compressed_list = array_bytes_to_list(compressed)
  let pixel_list = match decode_lzw(compressed_list, min_code_size) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let expected_pixels = descriptor.width * descriptor.height
  let normalized_pixels = match
    normalize_pixel_data(pixel_list, expected_pixels, strict_mode) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok(
    (
      ImageData::{
        descriptor,
        local_color_table: local_colors,
        image_data: normalized_pixels,
      },
      cursor,
    ),
  )
}

///|
pub fn parse_image_descriptor_block(
  data : Bytes,
  offset : Int,
) -> Result[(ImageDescriptor, Int), GifError] {
  if offset + 10 > data.length() {
    return Err(InvalidImageDescriptor)
  }
  if data[offset] != image_separator {
    return Err(InvalidImageDescriptor)
  }
  let left = to_u16_le(data[offset + 1], data[offset + 2])
  let top = to_u16_le(data[offset + 3], data[offset + 4])
  let width = to_u16_le(data[offset + 5], data[offset + 6])
  let height = to_u16_le(data[offset + 7], data[offset + 8])
  let packed = data[offset + 9].to_int()
  let (local_color_table_flag, interlace_flag, sort_flag, local_color_table_size
  ) = unpack_image_packed_field(packed)
  let descriptor = ImageDescriptor::{
    left,
    top,
    width,
    height,
    local_color_table_flag,
    interlace_flag,
    sort_flag,
    local_color_table_size,
  }
  match validate_image_descriptor(descriptor) {
    Ok(_) => Ok((descriptor, offset + 10))
    Err(err) => Err(err)
  }
}

///|
fn parse_extension_block(
  data : Bytes,
  offset : Int,
  strict_mode : Bool,
) -> Result[(ExtensionType?, Int), GifError] {
  if offset + 2 > data.length() {
    return Err(InvalidExtension)
  }
  let label = data[offset + 1]
  match label {
    b'\xF9' =>
      match parse_graphic_control_block(data, offset) {
        Ok((gce, next)) => Ok((Some(GraphicControl(gce)), next))
        Err(err) => Err(err)
      }
    b'\xFE' =>
      match parse_comment_block(data, offset) {
        Ok((comment, next_offset)) => Ok((Some(Comment(comment)), next_offset))
        Err(err) => Err(err)
      }
    b'\x01' =>
      match parse_plain_text_block(data, offset, strict_mode) {
        Ok((plain_text, next_offset)) =>
          Ok((Some(PlainText(plain_text)), next_offset))
        Err(err) => Err(err)
      }
    b'\xFF' =>
      match parse_application_extension_block(data, offset, strict_mode) {
        Ok((application_ext, next_offset)) =>
          Ok((Some(Application(application_ext)), next_offset))
        Err(err) => Err(err)
      }
    _ =>
      match collect_sub_blocks(data, offset + 2) {
        Ok((_, next)) => Ok((None, next))
        Err(err) => Err(err)
      }
  }
}

///|
pub fn parse_graphic_control_block(
  data : Bytes,
  offset : Int,
) -> Result[(GraphicControlExtension, Int), GifError] {
  if offset + 7 > data.length() {
    return Err(InvalidExtension)
  }
  let block_size = data[offset + 2].to_int()
  if block_size != 4 {
    return Err(InvalidBlockSize(block_size))
  }
  let packed = data[offset + 3].to_int()
  let disposal_method = (packed >> 2) & 0x07
  let user_input_flag = (packed & 0x02) != 0
  let transparent_color_flag = (packed & 0x01) != 0
  let delay_time = to_u16_le(data[offset + 4], data[offset + 5])
  let transparent_color_index = data[offset + 6].to_int()
  if data[offset + 7].to_int() != 0 {
    return Err(InvalidExtension)
  }
  let gce = GraphicControlExtension::{
    disposal_method,
    user_input_flag,
    transparent_color_flag,
    delay_time,
    transparent_color_index,
  }
  match validate_graphic_control(gce) {
    Ok(_) => Ok((gce, offset + 8))
    Err(err) => Err(err)
  }
}

///|
fn parse_comment_block(
  data : Bytes,
  offset : Int,
) -> Result[(CommentExtension, Int), GifError] {
  match collect_sub_blocks(data, offset + 2) {
    Ok((bytes, next)) =>
      Ok((CommentExtension::{ comment_data: array_bytes_to_list(bytes) }, next))
    Err(err) => Err(err)
  }
}

///|
pub fn parse_plain_text_block(
  data : Bytes,
  offset : Int,
  strict_mode : Bool,
) -> Result[(PlainTextExtension, Int), GifError] {
  if offset + 3 > data.length() {
    return Err(InvalidExtension)
  }
  let block_size = data[offset + 2].to_int()
  if block_size != 12 {
    return Err(InvalidBlockSize(block_size))
  }
  if offset + 15 > data.length() {
    return Err(InvalidExtension)
  }
  let left = to_u16_le(data[offset + 3], data[offset + 4])
  let top = to_u16_le(data[offset + 5], data[offset + 6])
  let width = to_u16_le(data[offset + 7], data[offset + 8])
  let height = to_u16_le(data[offset + 9], data[offset + 10])
  let cell_width = data[offset + 11].to_int()
  let cell_height = data[offset + 12].to_int()
  let fg_color = data[offset + 13].to_int()
  let bg_color = data[offset + 14].to_int()
  let (text_data, next_offset) = match collect_sub_blocks(data, offset + 15) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  if strict_mode && text_data.length() == 0 {
    return Err(DataCorrupted)
  }
  Ok(
    (
      PlainTextExtension::{
        text_grid_left_position: left,
        text_grid_top_position: top,
        text_grid_width: width,
        text_grid_height: height,
        character_cell_width: cell_width,
        character_cell_height: cell_height,
        text_foreground_color_index: fg_color,
        text_background_color_index: bg_color,
        plain_text_data: array_bytes_to_list(text_data),
      },
      next_offset,
    ),
  )
}

///|
pub fn parse_application_extension_block(
  data : Bytes,
  offset : Int,
  strict_mode : Bool,
) -> Result[(ApplicationExtension, Int), GifError] {
  if offset + 3 > data.length() {
    return Err(InvalidExtension)
  }
  let block_size = data[offset + 2].to_int()
  if block_size != 11 {
    return Err(InvalidBlockSize(block_size))
  }
  if offset + 14 > data.length() {
    return Err(InvalidExtension)
  }
  let identifier = bytes_to_string(data, offset + 3, 8)
  let auth_code = bytes_to_string(data, offset + 11, 3)
  let (app_data, next_offset) = match collect_sub_blocks(data, offset + 14) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  if strict_mode && app_data.length() == 0 {
    return Err(DataCorrupted)
  }
  Ok(
    (
      ApplicationExtension::{
        application_identifier: identifier,
        application_auth_code: auth_code,
        application_data: array_bytes_to_list(app_data),
      },
      next_offset,
    ),
  )
}

///|
fn collect_sub_blocks(
  data : Bytes,
  offset : Int,
) -> Result[(Array[Byte], Int), GifError] {
  let mut cursor = offset
  let collected : Array[Byte] = []
  while cursor < data.length() {
    let block_size = data[cursor].to_int()
    cursor = cursor + 1
    if block_size < 0 || block_size > 255 {
      return Err(InvalidBlockSize(block_size))
    }
    if block_size == 0 {
      return Ok((collected, cursor))
    }
    if cursor + block_size > data.length() {
      return Err(UnexpectedEndOfFile)
    }
    for i = 0; i < block_size; i = i + 1 {
      collected.push(data[cursor + i])
    }
    cursor = cursor + block_size
  }
  Err(UnexpectedEndOfFile)
}

///|
pub fn normalize_pixel_data(
  decoded : @list.List[Byte],
  expected : Int,
  strict_mode : Bool,
) -> Result[@list.List[Byte], GifError] {
  if expected <= 0 {
    return Ok(@list.new())
  }
  let decoded_array = decoded.to_array()
  if decoded_array.length() < expected && strict_mode {
    return Err(DataCorrupted)
  }
  let mut pixels = @list.new()
  let usable = if decoded_array.length() < expected {
    decoded_array.length()
  } else {
    expected
  }
  for i = 0; i < usable; i = i + 1 {
    pixels = @list.cons(decoded_array[i], pixels)
  }
  if decoded_array.length() < expected {
    for _i = decoded_array.length(); _i < expected; _i = _i + 1 {
      pixels = @list.cons(b'\x00', pixels)
    }
  }
  Ok(pixels.rev())
}

///|
pub fn array_bytes_to_list(data : Array[Byte]) -> @list.List[Byte] {
  let mut list = @list.new()
  let mut index = data.length()
  while index > 0 {
    index = index - 1
    list = @list.cons(data[index], list)
  }
  list
}
