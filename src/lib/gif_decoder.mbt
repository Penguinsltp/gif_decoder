// GIF 解码器主模块 - 简化实用版本

///| 将字节转换为字符串
fn bytes_to_string(data: Bytes, start: Int, len: Int) -> String {
  let chars : Array[Char] = []
  for i = 0; i < len; i = i + 1 {
    if start + i < data.length() {
      chars.push(Int::unsafe_to_char(data[start + i].to_int()))
    }
  }
  String::from_array(chars)
}

///| 基础的GIF解码功能
pub fn decode_gif_basic(data: Bytes) -> Result[String, String] {
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
  let has_global_color_table = (packed.land(0x80)) != 0
  let global_color_table_size = 1 << (packed.land(0x07) + 1)
  
  let result = "GIF " + version + " - " + width.to_string() + "x" + height.to_string()
  
  if has_global_color_table {
    Ok(result + " (Global color table: " + global_color_table_size.to_string() + " colors)")
  } else {
    Ok(result + " (No global color table)")
  }
}

///| GIF信息结构
pub struct GifInfo {
  version: String
  width: Int
  height: Int
  has_global_color_table: Bool
  global_color_table_size: Int
  color_resolution: Int
  sort_flag: Bool
  bg_color_index: Int
  pixel_aspect_ratio: Int
}

///| 更详细的GIF信息解析
pub fn parse_gif_info(data: Bytes) -> Result[GifInfo, String] {
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
  let has_global_color_table = (packed.land(0x80)) != 0
  let color_resolution = (packed >> 4).land(0x07) + 1
  let sort_flag = (packed.land(0x08)) != 0
  let global_color_table_size = 1 << (packed.land(0x07) + 1)
  
  Ok(GifInfo::{
    version,
    width,
    height,
    has_global_color_table,
    global_color_table_size,
    color_resolution,
    sort_flag,
    bg_color_index,
    pixel_aspect_ratio
  })
}

///| 颜色表条目
pub struct ColorEntry {
  red: Int
  green: Int
  blue: Int
}

///| 解析全局颜色表
pub fn parse_global_color_table(data: Bytes, offset: Int, size: Int) -> Result[Array[ColorEntry], String] {
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
      blue: data[base + 2].to_int()
    })
  }
  
  Ok(colors)
}

///| 查找图像描述符
pub fn find_image_descriptor(data: Bytes, start_offset: Int) -> Result[Int, String] {
  let mut offset = start_offset
  
  while offset < data.length() {
    let separator = data[offset]
    
    if separator.to_int() == 0x2C {  // Image Separator
      return Ok(offset)
    } else if separator.to_int() == 0x21 {  // Extension Introducer
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
    } else if separator.to_int() == 0x3B {  // Trailer
      return Err("No image found (reached trailer)")
    } else {
      offset = offset + 1
    }
  }
  
  Err("No image descriptor found")
}

///| 跳过数据子块
fn skip_data_sub_blocks(data: Bytes, start_offset: Int) -> Result[Int, String] {
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

///| 图像描述符（使用不同的名字避免冲突）
pub struct ImageDesc {
  left: Int
  top: Int
  width: Int
  height: Int
  has_local_color_table: Bool
  interlaced: Bool
  sorted: Bool
  local_color_table_size: Int
}

///| 解析图像描述符
pub fn parse_image_descriptor(data: Bytes, offset: Int) -> Result[(ImageDesc, Int), String] {
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
  
  let has_local_color_table = (packed.land(0x80)) != 0
  let interlaced = (packed.land(0x40)) != 0
  let sorted = (packed.land(0x20)) != 0
  let local_color_table_size = if has_local_color_table {
    1 << (packed.land(0x07) + 1)
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
    local_color_table_size
  }
  
  Ok((descriptor, offset + 10))
}

///| 主要的GIF解码函数
pub fn decode_gif_complete(data: Bytes) -> Result[String, String] {
  // 解析基本信息
  match parse_gif_info(data) {
    Ok(info) => {
      let mut result = "GIF " + info.version + " " + 
                      info.width.to_string() + "x" + info.height.to_string()
      
      let mut offset = 13  // 头部 + 逻辑屏幕描述符
      
      // 如果有全局颜色表，跳过它
      if info.has_global_color_table {
        offset = offset + info.global_color_table_size * 3
        result = result + " (Global colors: " + info.global_color_table_size.to_string() + ")"
      }
      
      // 查找图像
      match find_image_descriptor(data, offset) {
        Ok(img_offset) => {
          match parse_image_descriptor(data, img_offset) {
            Ok((img_desc, _)) => {
              result = result + " Image: " + img_desc.width.to_string() + "x" + img_desc.height.to_string()
              if img_desc.interlaced {
                result = result + " (interlaced)"
              }
              if img_desc.has_local_color_table {
                result = result + " (local colors: " + img_desc.local_color_table_size.to_string() + ")"
              }
              Ok(result)
            }
            Err(msg) => Err("Image descriptor error: " + msg)
          }
        }
        Err(msg) => Err("Image search error: " + msg)
      }
    }
    Err(msg) => Err("Header parsing error: " + msg)
  }
}

///| 简单测试函数
pub fn test_gif_decoder() -> String {
  // 创建一个简单的GIF89a文件头
  let test_header = Bytes::from_array([
    71, 73, 70, 56, 57, 97,  // "GIF89a"
    10, 0,                    // width = 10
    10, 0,                    // height = 10  
    128, 0, 0                 // packed, bg_index, aspect_ratio
  ])
  
  match decode_gif_basic(test_header) {
    Ok(result) => "Test passed: " + result
    Err(msg) => "Test failed: " + msg
  }
}