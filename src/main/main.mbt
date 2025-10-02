fn main {
  let args = @sys.get_cli_args()
  
  if args.length() < 2 {
    println("🎨 GIF解码器 - 使用说明")
    println("==================================================")
    println("用法: moon run src/main <gif文件路径>")
    println("示例: moon run src/main gif/__Attack.gif")
    println("      moon run src/main /path/to/your/image.gif")
    println("")
    println("🔧 如果不提供文件路径，将运行完整的演示程序...")
    println("")
    
    // 运行完整演示
    run_full_demo()
  } else {
    let gif_path = args[1]
    println("🎨 GIF解码器 - 文件分析")
    println("==================================================")
    
    // 解析指定的GIF文件
    analyze_gif_file(gif_path)
  }
}

///| 分析指定的GIF文件
fn analyze_gif_file(gif_path: String) -> Unit {
  println("📂 目标文件: " + gif_path)
  println("--------------------------------------------------")
  
  // 检查文件是否存在
  if !@fs.path_exists(gif_path) {
    println("❌ 错误: 文件不存在")
    println("   请检查文件路径是否正确")
    return
  }
  
  // 检查是否为文件
  try {
    if !@fs.is_file(gif_path) {
      println("❌ 错误: 指定路径不是文件")
      return
    }
  } catch {
    @fs.IOError(msg) => {
      println("❌ 错误: 无法访问文件 - " + msg)
      return
    }
  }
  
  try {
    // 读取文件
    let gif_data = @fs.read_file_to_bytes(gif_path)
    println("✅ 文件读取成功")
    println("   文件大小: " + gif_data.length().to_string() + " 字节")
    
    // 基本格式检查
    if gif_data.length() < 6 {
      println("❌ 错误: 文件太小，不是有效的GIF文件")
      return
    }
    
    let signature = format_bytes_as_string(gif_data, 0, 6)
    if !signature.has_prefix("GIF") {
      println("❌ 错误: 文件签名无效，不是GIF文件")
      println("   文件签名: " + signature)
      return
    }
    
    println("✅ GIF文件格式验证通过")
    println("")
    
    // 详细解析
    parse_gif_details(gif_data)
    
  } catch {
    @fs.IOError(msg) => println("❌ 文件读取失败: " + msg)
  }
}

///| 详细解析GIF文件
fn parse_gif_details(gif_data: Bytes) -> Unit {
  // 基本信息解析
  println("📋 基本信息")
  println("--------------------------------------------------")
  
  match @penguins/gif_decoder/src/lib.parse_gif_info(gif_data) {
    Ok(info) => {
      println("🏷️  文件版本: GIF " + info.version)
      println("📐 图像尺寸: " + info.width.to_string() + " × " + info.height.to_string() + " 像素")
      
      let megapixels = (info.width * info.height).to_double() / 1000000.0
      if megapixels >= 1.0 {
        println("   (约 " + megapixels.to_string() + " 百万像素)")
      }
      
      println("🎨 颜色信息:")
      if info.has_global_color_table {
        println("   - 全局颜色表: 是")
        println("   - 颜色数量: " + info.global_color_table_size.to_string() + " 色")
        println("   - 颜色分辨率: " + info.color_resolution.to_string() + " 位")
        
        let color_depth = match info.global_color_table_size {
          2 => "单色"
          4 => "4色"
          8 => "8色"
          16 => "16色"
          32 => "32色"
          64 => "64色"
          128 => "128色"
          256 => "256色"
          _ => info.global_color_table_size.to_string() + "色"
        }
        println("   - 色彩模式: " + color_depth)
      } else {
        println("   - 全局颜色表: 否")
      }
      
      println("🔧 其他属性:")
      println("   - 排序标志: " + (if info.sort_flag { "是" } else { "否" }))
      println("   - 背景颜色索引: " + info.bg_color_index.to_string())
      if info.pixel_aspect_ratio != 0 {
        println("   - 像素宽高比: " + info.pixel_aspect_ratio.to_string())
      }
      
      println("")
      
      // 高级分析
      println("🔬 高级分析")
      println("--------------------------------------------------")
      
      analyze_file_structure(gif_data, info)
      
    }
    Err(msg) => {
      println("❌ 解析失败: " + msg)
    }
  }
}

///| 分析文件结构
fn analyze_file_structure(gif_data: Bytes, info: @penguins/gif_decoder/src/lib.GifInfo) -> Unit {
  // 计算各部分大小
  let header_size = 6  // GIF header
  let lsd_size = 7     // Logical Screen Descriptor
  let global_color_table_size = if info.has_global_color_table {
    info.global_color_table_size * 3
  } else {
    0
  }
  
  let data_section_start = header_size + lsd_size + global_color_table_size
  let data_section_size = gif_data.length() - data_section_start
  
  println("📊 文件结构分析:")
  println("   - 文件头: " + header_size.to_string() + " 字节")
  println("   - 逻辑屏幕描述符: " + lsd_size.to_string() + " 字节")
  if global_color_table_size > 0 {
    println("   - 全局颜色表: " + global_color_table_size.to_string() + " 字节")
  }
  println("   - 数据段: " + data_section_size.to_string() + " 字节")
  
  // 尝试完整解码
  match @penguins/gif_decoder/src/lib.decode_gif_complete(gif_data) {
    Ok(result) => {
      println("✅ 完整解码成功")
      println("   " + result)
    }
    Err(msg) => {
      println("⚠️  完整解码部分失败: " + msg)
      println("   (基本信息解析正常)")
    }
  }
  
  // 文件完整性检查
  println("")
  println("🔍 文件完整性:")
  check_file_integrity(gif_data)
}

///| 检查文件完整性
fn check_file_integrity(gif_data: Bytes) -> Unit {
  let file_size = gif_data.length()
  
  // 检查文件是否以trailer结尾
  if file_size > 0 && gif_data[file_size - 1].to_int() == 0x3B {
    println("   ✅ 文件结尾正确 (0x3B trailer)")
  } else {
    println("   ⚠️  文件可能不完整 (缺少trailer)")
  }
  
  // 检查最小文件大小
  if file_size >= 14 {  // 最小GIF文件大小
    println("   ✅ 文件大小符合GIF格式要求")
  } else {
    println("   ❌ 文件大小过小")
  }
  
  // 给出文件类型建议
  println("")
  println("💡 建议:")
  match file_size {
    s if s < 1024 => println("   - 这是一个非常小的GIF文件，可能是简单图标")
    s if s < 10240 => println("   - 这是一个小型GIF文件，适合作为图标或简单动画")
    s if s < 102400 => println("   - 这是一个中等大小的GIF文件")
    s if s < 1048576 => println("   - 这是一个较大的GIF文件，可能包含复杂动画")
    _ => println("   - 这是一个很大的GIF文件，加载可能需要时间")
  }
}

///| 运行完整演示程序
fn run_full_demo() -> Unit {
  // 检查是否有默认的演示文件
  let demo_file = "gif/__Attack.gif"
  if @fs.path_exists(demo_file) {
    println("🎯 发现演示文件，将进行分析...")
    analyze_gif_file(demo_file)
    println("")
  }
  
  println("🎪 运行完整功能演示")
  println("==================================================")
  
  // 原有的演示代码
  demo_gif_parsing()
  test_basic_functions()
  demo_error_handling()
  advanced_verification()
  
  println("")
  println("✅ 演示完成！")
  println("")
  println("💡 提示: 下次可以直接指定文件路径来分析特定的GIF文件")
  println("   例如: moon run src/main your_image.gif")
}





///| 高级验证测试
fn advanced_verification() -> Unit {
  println("\n🚀 4. 高级验证测试")
  println("------------------------------")
  
  // 测试最小有效GIF
  println("🔬 最小GIF文件测试:")
  let minimal_gif = create_minimal_gif()
  match @penguins/gif_decoder/src/lib.decode_gif_complete(minimal_gif) {
    Ok(result) => println("   ✅ 成功: " + result)
    Err(msg) => println("   ❌ 失败: " + msg)
  }
  
  // 测试较大的GIF
  println("\n🔬 较大GIF文件测试:")
  let large_gif = create_large_test_gif()
  match @penguins/gif_decoder/src/lib.parse_gif_info(large_gif) {
    Ok(info) => {
      println("   ✅ 解析成功:")
      println("      - 尺寸: " + info.width.to_string() + "x" + info.height.to_string())
      println("      - 颜色数: " + info.global_color_table_size.to_string())
    }
    Err(msg) => println("   ❌ 解析失败: " + msg)
  }
  
  // 字节序测试
  println("\n🔬 字节序转换测试:")
  test_byte_order()
}

///| 演示GIF解析功能
fn demo_gif_parsing() -> Unit {
  println("\n📋 1. GIF文件解析演示")
  println("------------------------------")
  
  // 创建一个完整的模拟GIF文件数据
  let gif_data = create_sample_gif()
  
  // 基础解码
  println("🔍 基础解码:")
  match @penguins/gif_decoder/src/lib.decode_gif_basic(gif_data) {
    Ok(result) => println("   " + result)
    Err(msg) => println("   错误: " + msg)
  }
  
  // 详细信息解析
  println("\n📊 详细信息解析:")
  match @penguins/gif_decoder/src/lib.parse_gif_info(gif_data) {
    Ok(info) => {
      println("   版本: " + info.version)
      println("   尺寸: " + info.width.to_string() + "x" + info.height.to_string())
      println("   全局颜色表: " + (if info.has_global_color_table { "是" } else { "否" }))
      if info.has_global_color_table {
        println("   颜色数量: " + info.global_color_table_size.to_string())
        println("   颜色分辨率: " + info.color_resolution.to_string() + " 位")
      }
      println("   排序标志: " + (if info.sort_flag { "是" } else { "否" }))
      println("   背景颜色索引: " + info.bg_color_index.to_string())
      println("   像素宽高比: " + info.pixel_aspect_ratio.to_string())
    }
    Err(msg) => println("   错误: " + msg)
  }
  
  // 完整解码（包括图像信息）
  println("\n🖼️ 完整解码:")
  let complete_gif = create_complete_gif()
  match @penguins/gif_decoder/src/lib.decode_gif_complete(complete_gif) {
    Ok(result) => println("   " + result)
    Err(msg) => println("   错误: " + msg)
  }
}

///| 测试基础功能
fn test_basic_functions() -> Unit {
  println("\n🧪 2. 基础功能测试")
  println("------------------------------")
  
  // 测试位读取器
  println("🔧 位读取器测试:")
  let test_bytes = [0xAA, 0xBB, 0xCC]  // 10101010 11011011 11001100
  let data_list = @list.List::from_array(test_bytes.map(fn(x) { x.to_byte() }))
  let bit_reader = @penguins/gif_decoder/src/lib.new(data_list)
  
  let (reader1, bits1) = bit_reader.read_bits(4)
  match bits1 {
    Some(value) => println("   读取4位: " + value.to_string() + " (二进制: " + format_binary(value, 4) + ")")
    None => println("   读取失败")
  }
  
  let (_, bits2) = reader1.read_bits(8)
  match bits2 {
    Some(value) => println("   读取8位: " + value.to_string() + " (二进制: " + format_binary(value, 8) + ")")
    None => println("   读取失败")
  }
  
  // 测试字节工具
  println("\n🔧 字节工具测试:")
  let b1 = (0x34).to_byte()
  let b2 = (0x12).to_byte()
  let u16_value = @penguins/gif_decoder/src/lib.to_u16_le(b1, b2)
  println("   小端序转换: 0x" + b1.to_int().to_string() + " 0x" + b2.to_int().to_string() + " -> " + u16_value.to_string())
  
  // 内置测试函数
  println("\n🧪 内置测试:")
  let test_result = @penguins/gif_decoder/src/lib.test_gif_decoder()
  println("   " + test_result)
}

///| 演示错误处理
fn demo_error_handling() -> Unit {
  println("\n❌ 3. 错误处理演示")
  println("------------------------------")
  
  // 测试无效文件
  println("🚫 无效文件测试:")
  let invalid_data = Bytes::from_array([1, 2, 3, 4, 5])
  match @penguins/gif_decoder/src/lib.decode_gif_basic(invalid_data) {
    Ok(result) => println("   意外成功: " + result)
    Err(msg) => println("   ✓ 正确检测到错误: " + msg)
  }
  
  // 测试文件太小
  println("\n🚫 文件太小测试:")
  let tiny_data = Bytes::from_array([71, 73, 70])  // 只有 "GIF"
  match @penguins/gif_decoder/src/lib.parse_gif_info(tiny_data) {
    Ok(_) => println("   意外成功")
    Err(msg) => println("   ✓ 正确检测到错误: " + msg)
  }
  
  // 测试错误版本
  println("\n🚫 错误版本测试:")
  let wrong_version = Bytes::from_array([
    71, 73, 70, 57, 57, 97,  // "GIF99a" - 无效版本
    10, 0, 10, 0, 0, 0, 0
  ])
  match @penguins/gif_decoder/src/lib.decode_gif_basic(wrong_version) {
    Ok(_) => println("   意外成功")
    Err(msg) => println("   ✓ 正确检测到错误: " + msg)
  }
}

///| 创建示例GIF数据
fn create_sample_gif() -> Bytes {
  Bytes::from_array([
    // GIF文件头
    71, 73, 70, 56, 57, 97,   // "GIF89a"
    
    // 逻辑屏幕描述符
    64, 0,                    // 宽度 = 64
    48, 0,                    // 高度 = 48
    0xF0,                     // packed: 全局颜色表=1, 分辨率=7, 排序=0, 大小=0 (2色)
    0,                        // 背景颜色索引 = 0
    0                         // 像素宽高比 = 0
  ])
}

///| 创建包含图像的完整GIF数据
fn create_complete_gif() -> Bytes {
  Bytes::from_array([
    // GIF文件头
    71, 73, 70, 56, 57, 97,   // "GIF89a"
    
    // 逻辑屏幕描述符  
    32, 0,                    // 宽度 = 32
    32, 0,                    // 高度 = 32
    0x80,                     // packed: 全局颜色表=1, 分辨率=0, 排序=0, 大小=0 (2色)
    0,                        // 背景颜色索引
    0,                        // 像素宽高比
    
    // 全局颜色表 (2色)
    0, 0, 0,                  // 黑色
    255, 255, 255,            // 白色
    
    // 图像描述符
    0x2C,                     // 图像分隔符
    0, 0,                     // left = 0
    0, 0,                     // top = 0  
    16, 0,                    // width = 16
    16, 0,                    // height = 16
    0x00,                     // packed: 无局部颜色表, 非交错
    
    // LZW最小代码大小
    2,
    
    // 图像数据 (简化的数据块)
    4,                        // 数据块大小 = 4
    0x04, 0x10, 0x18, 0x28,   // 简单的LZW压缩数据
    0,                        // 数据块终止符
    
    // GIF文件终止符
    0x3B
  ])
}

///| 格式化二进制表示
fn format_binary(value: Int, width: Int) -> String {
  let mut result = ""
  let mut temp = value
  
  for i = 0; i < width; i = i + 1 {
    let bit = if (temp.land(1)) != 0 { "1" } else { "0" }
    result = bit + result
    temp = temp >> 1
  }
  
  result
}

///| 将字节转换为可读字符串
fn format_bytes_as_string(data: Bytes, start: Int, len: Int) -> String {
  let mut result = ""
  for i = 0; i < len; i = i + 1 {
    if start + i < data.length() {
      let byte_val = data[start + i].to_int()
      if byte_val >= 32 && byte_val <= 126 {  // 可打印ASCII字符
        result = result + String::from_array([Int::unsafe_to_char(byte_val)])
      } else {
        result = result + "\\x" + byte_val.to_string()
      }
    }
  }
  result
}

///| 创建最小的有效GIF文件
fn create_minimal_gif() -> Bytes {
  Bytes::from_array([
    // GIF Header
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61,  // "GIF89a"
    
    // Logical Screen Descriptor
    0x01, 0x00,  // Width = 1
    0x01, 0x00,  // Height = 1  
    0x80,        // Global Color Table Flag = 1
    0x00,        // Background Color Index = 0
    0x00,        // Pixel Aspect Ratio = 0
    
    // Global Color Table (2 colors)
    0x00, 0x00, 0x00,  // Color 0: Black
    0xFF, 0xFF, 0xFF,  // Color 1: White
    
    // Image Descriptor
    0x2C,        // Image Separator
    0x00, 0x00,  // Left = 0
    0x00, 0x00,  // Top = 0
    0x01, 0x00,  // Width = 1
    0x01, 0x00,  // Height = 1
    0x00,        // Packed = 0
    
    // Image Data
    0x02,        // LZW Minimum Code Size = 2
    0x02,        // Data Sub-block size = 2
    0x04, 0x01,  // LZW Data
    0x00,        // Data Sub-block Terminator
    
    // GIF Trailer
    0x3B
  ])
}

///| 创建较大的测试GIF
fn create_large_test_gif() -> Bytes {
  Bytes::from_array([
    // GIF Header
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61,  // "GIF89a"
    
    // Logical Screen Descriptor  
    0x10, 0x00,  // Width = 16
    0x10, 0x00,  // Height = 16
    0x91,        // Global Color Table, 4 colors
    0x00,        // Background = 0
    0x00,        // Pixel Aspect Ratio = 0
    
    // Global Color Table (4 colors)
    0x00, 0x00, 0x00,  // Black
    0xFF, 0x00, 0x00,  // Red  
    0x00, 0xFF, 0x00,  // Green
    0x00, 0x00, 0xFF,  // Blue
    
    // Image Descriptor
    0x2C,        // Image Separator
    0x00, 0x00,  // Left = 0
    0x00, 0x00,  // Top = 0
    0x08, 0x00,  // Width = 8
    0x08, 0x00,  // Height = 8
    0x00,        // No local color table
    
    // Image Data
    0x02,        // LZW min code size = 2
    0x08,        // Data block size = 8
    0x04, 0x10, 0x18, 0x28, 0x30, 0x38, 0x40, 0x05,  // LZW data
    0x00,        // Data block terminator
    0x3B         // GIF Trailer
  ])
}

///| 测试字节序转换
fn test_byte_order() -> Unit {
  println("   测试小端序转换:")
  
  // 测试几个值
  let test_cases = [
    (0x00, 0x01, 256),    // 0x0100 = 256
    (0xFF, 0x00, 255),    // 0x00FF = 255  
    (0x34, 0x12, 4660),   // 0x1234 = 4660
    (0xCD, 0xAB, 43981)   // 0xABCD = 43981
  ]
  
  for i = 0; i < test_cases.length(); i = i + 1 {
    let (b1, b2, expected) = test_cases[i]
    let result = @penguins/gif_decoder/src/lib.to_u16_le(b1.to_byte(), b2.to_byte())
    let status = if result == expected { "✅" } else { "❌" }
    println("      " + status + " 0x" + b1.to_string() + " 0x" + b2.to_string() + " -> " + result.to_string() + " (期望: " + expected.to_string() + ")")
  }
}