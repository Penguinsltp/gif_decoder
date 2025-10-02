// GIF 文件格式的数据结构定义

///| GIF Header
pub struct GifHeader {
  signature: String  // "GIF"
  version: String    // "87a" 或 "89a"
}

///| Logical Screen Descriptor
pub struct LogicalScreenDescriptor {
  screen_width: Int
  screen_height: Int
  global_color_table_flag: Bool
  color_resolution: Int
  sort_flag: Bool
  global_color_table_size: Int
  background_color_index: Int
  pixel_aspect_ratio: Int
}

///| Color Table Entry
pub struct ColorTableEntry {
  red: Int
  green: Int
  blue: Int
}

///| Image Descriptor
pub struct ImageDescriptor {
  left: Int
  top: Int
  width: Int
  height: Int
  local_color_table_flag: Bool
  interlace_flag: Bool
  sort_flag: Bool
  local_color_table_size: Int
}

///| Extension Types
pub enum ExtensionType {
  PlainText(PlainTextExtension)
  GraphicControl(GraphicControlExtension)
  Comment(CommentExtension)
  Application(ApplicationExtension)
}

///| Graphic Control Extension
pub struct GraphicControlExtension {
  disposal_method: Int
  user_input_flag: Bool
  transparent_color_flag: Bool
  delay_time: Int
  transparent_color_index: Int
}

///| Plain Text Extension
pub struct PlainTextExtension {
  text_grid_left_position: Int
  text_grid_top_position: Int
  text_grid_width: Int
  text_grid_height: Int
  character_cell_width: Int
  character_cell_height: Int
  text_foreground_color_index: Int
  text_background_color_index: Int
  plain_text_data: @list.List[Byte]
}

///| Comment Extension
pub struct CommentExtension {
  comment_data: @list.List[Byte]
}

///| Application Extension
pub struct ApplicationExtension {
  application_identifier: String
  application_auth_code: String
  application_data: @list.List[Byte]
}

///| GIF Data Block
pub enum GifDataBlock {
  Extension(ExtensionType)
  Image(ImageData)
  Trailer
}

///| Image Data
pub struct ImageData {
  descriptor: ImageDescriptor
  local_color_table: Option[@list.List[ColorTableEntry]]
  image_data: @list.List[Byte]
}

///| Complete GIF Structure
pub struct Gif {
  header: GifHeader
  logical_screen: LogicalScreenDescriptor
  global_color_table: Option[@list.List[ColorTableEntry]]
  data_blocks: @list.List[GifDataBlock]
}

///| GIF Parsing Error
pub enum GifError {
  InvalidHeader
  InvalidFormat
  UnexpectedEndOfData
  UnsupportedFeature(String)
  LzwDecodingError
}