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
    @list.of([b'T', b'e', b's', b't']),
  )
  let app_ext = ApplicationExtension::{
    application_identifier: "NETSCAPE",
    application_auth_code: "2.0",
    application_data: @list.of([b'1', b'0']),
  }
  @list.of([Extension(Application(app_ext)), Image(image_data), Trailer])
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
