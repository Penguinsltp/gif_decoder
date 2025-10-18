// GIF 文件格式的数据结构定义

///|
/// GIF 头部
pub struct GifHeader {
  signature : String // "GIF"
  version : String // "87a" 或 "89a"
} derive(Show)

///|
/// 逻辑屏幕描述符
pub struct LogicalScreenDescriptor {
  screen_width : Int
  screen_height : Int
  global_color_table_flag : Bool
  color_resolution : Int
  sort_flag : Bool
  global_color_table_size : Int
  background_color_index : Int
  pixel_aspect_ratio : Int
} derive(Show)

///|
/// 颜色表条目
pub struct ColorTableEntry {
  red : Int
  green : Int
  blue : Int
} derive(Show, Eq)

///|
/// 图像描述符
pub struct ImageDescriptor {
  left : Int
  top : Int
  width : Int
  height : Int
  local_color_table_flag : Bool
  interlace_flag : Bool
  sort_flag : Bool
  local_color_table_size : Int
} derive(Show)

///|
/// 扩展类型
pub enum ExtensionType {
  PlainText(PlainTextExtension)
  GraphicControl(GraphicControlExtension)
  Comment(CommentExtension)
  Application(ApplicationExtension)
} derive(Show)

///|
/// 图形控制扩展
pub struct GraphicControlExtension {
  disposal_method : Int
  user_input_flag : Bool
  transparent_color_flag : Bool
  delay_time : Int
  transparent_color_index : Int
} derive(Show)

///|
/// 纯文本扩展
pub struct PlainTextExtension {
  text_grid_left_position : Int
  text_grid_top_position : Int
  text_grid_width : Int
  text_grid_height : Int
  character_cell_width : Int
  character_cell_height : Int
  text_foreground_color_index : Int
  text_background_color_index : Int
  plain_text_data : @list.List[Byte]
} derive(Show)

///|
/// 注释扩展
pub struct CommentExtension {
  comment_data : @list.List[Byte]
} derive(Show)

///|
/// 应用程序扩展
pub struct ApplicationExtension {
  application_identifier : String
  application_auth_code : String
  application_data : @list.List[Byte]
} derive(Show)

///|
/// GIF 数据块
pub enum GifDataBlock {
  Extension(ExtensionType)
  Image(ImageData)
  Trailer
} derive(Show)

///|
/// 图像数据
pub struct ImageData {
  descriptor : ImageDescriptor
  local_color_table : @list.List[ColorTableEntry]?
  image_data : @list.List[Byte]
} derive(Show)

///|
/// 完整的 GIF 结构
pub struct Gif {
  header : GifHeader
  logical_screen : LogicalScreenDescriptor
  global_color_table : @list.List[ColorTableEntry]?
  data_blocks : @list.List[GifDataBlock]
} derive(Show)

///|
/// GIF 解析错误 - 添加 InvalidBlockSize 构造函数
pub enum GifError {
  InvalidHeader
  InvalidLogicalScreen
  InvalidColorTable
  InvalidImageDescriptor
  InvalidExtension
  InvalidFormat
  LzwDecodingError
  NoColorTable
  UnsupportedFeature
  DataCorrupted
  UnexpectedEndOfFile
  InvalidBlockSize(Int)
} derive(Show)

///|
/// 详细的 GIF 解析错误，包含更具体的信息
pub enum DetailedGifError {
  InvalidSignature(String)
  UnsupportedVersion(String)
  InvalidBlockSize(Int)
  InvalidLzwMinimumCodeSize(Int)
  InvalidColorTableSize(Int)
  ImageTooLarge(Int, Int)
  InvalidDisposalMethod(Int)
  CorruptedSubBlock
} derive(Show)

///|
/// GIF 格式常量
pub let gif_signature : String = "GIF"

///|
pub let gif_version_87a : String = "87a"

///|
pub let gif_version_89a : String = "89a"

///|
/// 块分隔符
pub let image_separator : Byte = b'\x2C'

///|
pub let extension_introducer : Byte = b'\x21'

///|
pub let trailer : Byte = b'\x3B'

///|
/// 扩展标签
pub let graphic_control_label : Byte = b'\xF9'

///|
pub let comment_label : Byte = b'\xFE'

///|
pub let plain_text_label : Byte = b'\x01'

///|
pub let application_extension_label : Byte = b'\xFF'

///|
/// 解码器的 LZW 常量
pub let lzw_clear_code : Int = 256

///|
pub let lzw_end_code : Int = 257

///|
pub let lzw_first_code : Int = 258

///|
pub let lzw_max_code_size : Int = 12

///|
/// 处理方法常量
pub let disposal_none : Int = 0

///|
pub let disposal_keep : Int = 1

///|
pub let disposal_restore_background : Int = 2

///|
pub let disposal_restore_previous : Int = 3

///|
/// 颜色表大小计算工具函数
pub fn calculate_color_table_size(size_field : Int) -> Int {
  1 << (size_field + 1)
}

///|
/// 打包逻辑屏幕描述符的打包字段
pub fn pack_logical_screen_packed_field(
  global_color_table_flag : Bool,
  color_resolution : Int,
  sort_flag : Bool,
  global_color_table_size : Int,
) -> Int {
  let mut result = 0
  if global_color_table_flag {
    result = result | 0x80
  }
  result = result | ((color_resolution & 0x07) << 4)
  if sort_flag {
    result = result | 0x08
  }
  result = result | (global_color_table_size & 0x07)
  result
}

///|
/// 解包逻辑屏幕描述符的打包字段
pub fn unpack_logical_screen_packed_field(
  packed : Int,
) -> (Bool, Int, Bool, Int) {
  let global_color_table_flag = (packed & 0x80) != 0
  let color_resolution = (packed >> 4) & 0x07
  let sort_flag = (packed & 0x08) != 0
  let global_color_table_size = packed & 0x07
  (
    global_color_table_flag, color_resolution, sort_flag, global_color_table_size,
  )
}

///|
/// 打包图像描述符的打包字段
pub fn pack_image_packed_field(
  local_color_table_flag : Bool,
  interlace_flag : Bool,
  sort_flag : Bool,
  local_color_table_size : Int,
) -> Int {
  let mut result = 0
  if local_color_table_flag {
    result = result | 0x80
  }
  if interlace_flag {
    result = result | 0x40
  }
  if sort_flag {
    result = result | 0x20
  }
  result = result | (local_color_table_size & 0x07)
  result
}

///|
/// 解包图像描述符的打包字段
pub fn unpack_image_packed_field(packed : Int) -> (Bool, Bool, Bool, Int) {
  let local_color_table_flag = (packed & 0x80) != 0
  let interlace_flag = (packed & 0x40) != 0
  let sort_flag = (packed & 0x20) != 0
  let local_color_table_size = packed & 0x07
  (local_color_table_flag, interlace_flag, sort_flag, local_color_table_size)
}

///|
/// GIF 头部的验证函数
pub fn validate_gif_header(header : GifHeader) -> Result[Unit, GifError] {
  if header.signature != gif_signature {
    Err(InvalidHeader)
  } else if header.version != gif_version_87a &&
    header.version != gif_version_89a {
    Err(InvalidHeader)
  } else {
    Ok(())
  }
}

///|
/// GIF 头部的构造函数
pub fn create_gif_header(version : String) -> GifHeader {
  { signature: gif_signature, version }
}

///|
/// 颜色表条目的构造函数
pub fn create_color_table_entry(r : Int, g : Int, b : Int) -> ColorTableEntry {
  { red: r, green: g, blue: b }
}

///|
/// 逻辑屏幕描述符的验证
pub fn validate_logical_screen(
  screen : LogicalScreenDescriptor,
) -> Result[Unit, GifError] {
  if screen.screen_width <= 0 || screen.screen_height <= 0 {
    Err(InvalidLogicalScreen)
  } else if screen.color_resolution < 0 || screen.color_resolution > 7 {
    Err(InvalidLogicalScreen)
  } else if screen.global_color_table_size < 0 ||
    screen.global_color_table_size > 7 {
    Err(InvalidColorTable)
  } else {
    Ok(())
  }
}

///|
/// 图像描述符的验证
pub fn validate_image_descriptor(
  desc : ImageDescriptor,
) -> Result[Unit, GifError] {
  if desc.width <= 0 || desc.height <= 0 {
    Err(InvalidImageDescriptor)
  } else if desc.left < 0 || desc.top < 0 {
    Err(InvalidImageDescriptor)
  } else if desc.local_color_table_size < 0 || desc.local_color_table_size > 7 {
    Err(InvalidColorTable)
  } else {
    Ok(())
  }
}

///|
/// 图形控制扩展的验证
pub fn validate_graphic_control(
  gce : GraphicControlExtension,
) -> Result[Unit, GifError] {
  if gce.disposal_method < 0 || gce.disposal_method > 7 {
    Err(InvalidExtension)
  } else if gce.delay_time < 0 {
    Err(InvalidExtension)
  } else if gce.transparent_color_index < 0 || gce.transparent_color_index > 255 {
    Err(InvalidExtension)
  } else {
    Ok(())
  }
}

///|
/// 检查处理方法是否有效的辅助函数
pub fn is_valid_disposal_method(disposal_method : Int) -> Bool {
  disposal_method >= disposal_none &&
  disposal_method <= disposal_restore_previous
}

///|
/// 从描述符获取颜色表大小的辅助函数
pub fn get_color_table_size_from_descriptor(
  desc : LogicalScreenDescriptor,
) -> Int {
  if desc.global_color_table_flag {
    calculate_color_table_size(desc.global_color_table_size)
  } else {
    0
  }
}

///|
/// 从图像描述符获取局部颜色表大小的辅助函数
pub fn get_local_color_table_size(desc : ImageDescriptor) -> Int {
  if desc.local_color_table_flag {
    calculate_color_table_size(desc.local_color_table_size)
  } else {
    0
  }
}

///|
/// 检查图像是否有局部颜色表
pub fn has_local_color_table(desc : ImageDescriptor) -> Bool {
  desc.local_color_table_flag
}

///|
/// 检查逻辑屏幕是否有全局颜色表
pub fn has_global_color_table(screen : LogicalScreenDescriptor) -> Bool {
  screen.global_color_table_flag
}

///|
/// 创建默认的逻辑屏幕描述符
pub fn create_default_logical_screen(
  width : Int,
  height : Int,
) -> LogicalScreenDescriptor {
  {
    screen_width: width,
    screen_height: height,
    global_color_table_flag: false,
    color_resolution: 7,
    sort_flag: false,
    global_color_table_size: 0,
    background_color_index: 0,
    pixel_aspect_ratio: 0,
  }
}

///|
/// 创建默认的图像描述符
pub fn create_default_image_descriptor(
  width : Int,
  height : Int,
) -> ImageDescriptor {
  {
    left: 0,
    top: 0,
    width,
    height,
    local_color_table_flag: false,
    interlace_flag: false,
    sort_flag: false,
    local_color_table_size: 0,
  }
}

///|
/// 测试函数，确保所有类型都能正确构造
pub fn test_all_type_constructions() -> Result[String, GifError] {
  // 测试所有扩展类型
  let gce = GraphicControlExtension::{
    disposal_method: 1,
    user_input_flag: false,
    transparent_color_flag: true,
    delay_time: 100,
    transparent_color_index: 0,
  }
  let comment = CommentExtension::{
    comment_data: @list.of([b'T', b'e', b's', b't']),
  }
  let plain_text = PlainTextExtension::{
    text_grid_left_position: 10,
    text_grid_top_position: 20,
    text_grid_width: 100,
    text_grid_height: 50,
    character_cell_width: 8,
    character_cell_height: 12,
    text_foreground_color_index: 1,
    text_background_color_index: 0,
    plain_text_data: @list.of([b'H', b'i']),
  }
  let app = ApplicationExtension::{
    application_identifier: "NETSCAPE",
    application_auth_code: "2.0",
    application_data: @list.of([b'1', b'0']),
  }

  // 测试所有数据块
  let data_blocks = @list.of([
    Extension(GraphicControl(gce)),
    Extension(Comment(comment)),
    Extension(PlainText(plain_text)),
    Extension(Application(app)),
    Trailer,
  ])

  // 测试完整的 GIF 结构
  let header = create_gif_header(gif_version_89a)
  let logical_screen = create_default_logical_screen(100, 100)
  let gif = Gif::{
    header,
    logical_screen,
    global_color_table: None,
    data_blocks,
  }

  // 测试所有错误类型
  let basic_errors = @list.of([
    InvalidHeader,
    InvalidLogicalScreen,
    InvalidColorTable,
    InvalidImageDescriptor,
    InvalidExtension,
    InvalidFormat,
    LzwDecodingError,
    NoColorTable,
    UnsupportedFeature,
    DataCorrupted,
    UnexpectedEndOfFile,
    InvalidBlockSize(99),
  ])
  let detailed_errors = @list.of([
    InvalidSignature("BAD"),
    UnsupportedVersion("90a"),
    InvalidBlockSize(999),
    InvalidLzwMinimumCodeSize(20),
    InvalidColorTableSize(10),
    ImageTooLarge(100000, 100000),
    InvalidDisposalMethod(8),
    CorruptedSubBlock,
  ])
  if basic_errors.length() > 0 &&
    detailed_errors.length() > 0 &&
    gif.header.signature == gif_signature {
    Ok("所有类型都成功构造")
  } else {
    Err(DataCorrupted)
  }
}
