///|
fn main {
  let args = @sys.get_cli_args()
  if args.length() < 2 {
    println("🎨 GIF解码器 - 使用说明")
    println("==================================================")
    println("用法: moon run src/main <gif文件路径>")
    println("示例: moon run src/main gif/__Attack.gif")
    println("      moon run src/main /path/to/your/image.gif")
    println("")
    println(
      "🔧 如果不提供文件路径，将运行完整的演示程序...",
    )
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

///|
/// 分析指定的GIF文件
fn analyze_gif_file(gif_path : String) -> Unit {
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
    let signature = @gif_decoder_lib.bytes_to_string(gif_data, 0, 6)
    if !signature.has_prefix("GIF") {
      println("❌ 错误: 文件签名无效，不是GIF文件")
      println("   文件签名: " + signature)
      return
    }
    println("✅ GIF文件格式验证通过")
    println("")

    // 详细解析
    parse_gif_details(gif_data)

    // 添加颜色表分析
    analyze_color_table(gif_data)

    // 添加图像分析
    analyze_image_data(gif_data)
  } catch {
    @fs.IOError(msg) => println("❌ 文件读取失败: " + msg)
  }
}

///|
/// 详细解析GIF文件
fn parse_gif_details(gif_data : Bytes) -> Unit {
  // 基本信息解析
  println("📋 基本信息")
  println("--------------------------------------------------")
  match @gif_decoder_lib.parse_gif_info(gif_data) {
    Ok(info) => {
      println("🏷️  文件版本: GIF " + info.version)
      println(
        "📐 图像尺寸: " +
        info.width.to_string() +
        " × " +
        info.height.to_string() +
        " 像素",
      )
      let megapixels = (info.width * info.height).to_double() / 1000000.0
      if megapixels >= 1.0 {
        println("   (约 " + megapixels.to_string() + " 百万像素)")
      }
      println("🎨 颜色信息:")
      if info.has_global_color_table {
        println("   - 全局颜色表: 是")
        println(
          "   - 颜色数量: " +
          info.global_color_table_size.to_string() +
          " 色",
        )
        println(
          "   - 颜色分辨率: " + info.color_resolution.to_string() + " 位",
        )
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
      println(
        "   - 排序标志: " + (if info.sort_flag { "是" } else { "否" }),
      )
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
    Err(msg) => println("❌ 解析失败: " + msg)
  }
}

///|
/// 分析文件结构
fn analyze_file_structure(
  gif_data : Bytes,
  info : @gif_decoder_lib.GifInfo,
) -> Unit {
  // 计算各部分大小
  let header_size = 6 // GIF header
  let lsd_size = 7 // Logical Screen Descriptor
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
    println(
      "   - 全局颜色表: " + global_color_table_size.to_string() + " 字节",
    )
  }
  println("   - 数据段: " + data_section_size.to_string() + " 字节")

  // 尝试完整解码
  match @gif_decoder_lib.decode_gif_complete(gif_data) {
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

///|
/// 分析颜色表
fn analyze_color_table(gif_data : Bytes) -> Unit {
  match @gif_decoder_lib.parse_gif_info(gif_data) {
    Ok(info) =>
      if info.has_global_color_table {
        println("🎨 颜色表详细分析")
        println("--------------------------------------------------")
        let color_table_offset = 13 // 头部 + 逻辑屏幕描述符
        match
          @gif_decoder_lib.parse_global_color_table(
            gif_data,
            color_table_offset,
            info.global_color_table_size,
          ) {
          Ok(colors) => {
            println("✅ 颜色表解析成功")
            println("   共 " + colors.length().to_string() + " 种颜色:")

            // 显示前几种颜色
            let display_count = if colors.length() > 8 {
              8
            } else {
              colors.length()
            }
            for i = 0; i < display_count; i = i + 1 {
              let color = colors[i]
              println(
                "   [" +
                i.to_string() +
                "] RGB(" +
                color.red.to_string() +
                ", " +
                color.green.to_string() +
                ", " +
                color.blue.to_string() +
                ") " +
                get_color_description(color),
              )
            }
            if colors.length() > display_count {
              println(
                "   ... (还有 " +
                (colors.length() - display_count).to_string() +
                " 种颜色)",
              )
            }

            // 颜色统计
            analyze_color_statistics(colors)
          }
          Err(msg) => println("❌ 颜色表解析失败: " + msg)
        }
        println("")
      }
    Err(_) => ()
  }
}

///|
/// 分析图像数据
fn analyze_image_data(gif_data : Bytes) -> Unit {
  println("🖼️ 图像数据分析")
  println("--------------------------------------------------")
  match @gif_decoder_lib.parse_gif_info(gif_data) {
    Ok(info) => {
      let data_start = 13 +
        (if info.has_global_color_table {
          info.global_color_table_size * 3
        } else {
          0
        })
      match @gif_decoder_lib.find_image_descriptor(gif_data, data_start) {
        Ok(img_offset) =>
          match @gif_decoder_lib.parse_image_descriptor(gif_data, img_offset) {
            Ok((desc, next_offset)) => {
              println("✅ 图像描述符解析成功:")
              println(
                "   - 位置: (" +
                desc.left.to_string() +
                ", " +
                desc.top.to_string() +
                ")",
              )
              println(
                "   - 尺寸: " +
                desc.width.to_string() +
                "×" +
                desc.height.to_string(),
              )
              println(
                "   - 局部颜色表: " +
                (if desc.has_local_color_table { "是" } else { "否" }),
              )
              println(
                "   - 交错模式: " +
                (if desc.interlaced { "是" } else { "否" }),
              )
              println(
                "   - 排序标志: " +
                (if desc.sorted { "是" } else { "否" }),
              )
              if desc.has_local_color_table {
                println(
                  "   - 局部颜色数: " +
                  desc.local_color_table_size.to_string(),
                )
              }

              // 计算压缩比
              let pixel_count = desc.width * desc.height
              let uncompressed_size = pixel_count // 假设每像素1字节
              let remaining_data = gif_data.length() - next_offset
              if remaining_data > 0 {
                let compression_ratio = uncompressed_size.to_double() /
                  remaining_data.to_double()
                println(
                  "   - 估计压缩比: " +
                  compression_ratio.to_string() +
                  ":1",
                )
              }
            }
            Err(msg) => println("❌ 图像描述符解析失败: " + msg)
          }
        Err(msg) => println("❌ 未找到图像描述符: " + msg)
      }
    }
    Err(_) => ()
  }
  println("")
}

///|
/// 获取颜色描述
fn get_color_description(color : @gif_decoder_lib.ColorEntry) -> String {
  match (color.red, color.green, color.blue) {
    (0, 0, 0) => "黑色"
    (255, 255, 255) => "白色"
    (255, 0, 0) => "红色"
    (0, 255, 0) => "绿色"
    (0, 0, 255) => "蓝色"
    (255, 255, 0) => "黄色"
    (255, 0, 255) => "洋红"
    (0, 255, 255) => "青色"
    (r, g, b) if r == g && g == b => "灰色"
    _ => ""
  }
}

///|
/// 分析颜色统计
fn analyze_color_statistics(
  colors : Array[@gif_decoder_lib.ColorEntry],
) -> Unit {
  let mut grayscale_count = 0
  let mut primary_count = 0
  for i = 0; i < colors.length(); i = i + 1 {
    let color = colors[i]

    // 检查是否为灰度
    if color.red == color.green && color.green == color.blue {
      grayscale_count = grayscale_count + 1
    }

    // 检查是否为原色
    let is_primary = (color.red == 0 || color.red == 255) &&
      (color.green == 0 || color.green == 255) &&
      (color.blue == 0 || color.blue == 255)
    if is_primary {
      primary_count = primary_count + 1
    }
  }
  println("   📊 颜色统计:")
  println("      - 灰度颜色: " + grayscale_count.to_string() + " 个")
  println("      - 原色系: " + primary_count.to_string() + " 个")
  if grayscale_count == colors.length() {
    println("      💡 这是一个灰度图像")
  } else if primary_count > colors.length() / 2 {
    println("      💡 主要使用原色系，可能是简单图标")
  }
}

///|
/// 检查文件完整性
fn check_file_integrity(gif_data : Bytes) -> Unit {
  let file_size = gif_data.length()

  // 检查文件是否以trailer结尾
  if file_size > 0 && gif_data[file_size - 1].to_int() == 0x3B {
    println("   ✅ 文件结尾正确 (0x3B trailer)")
  } else {
    println("   ⚠️  文件可能不完整 (缺少trailer)")
  }

  // 检查最小文件大小
  if file_size >= 14 { // 最小GIF文件大小
    println("   ✅ 文件大小符合GIF格式要求")
  } else {
    println("   ❌ 文件大小过小")
  }

  // 给出文件类型建议
  println("")
  println("💡 建议:")
  match file_size {
    s if s < 1024 =>
      println("   - 这是一个非常小的GIF文件，可能是简单图标")
    s if s < 10240 =>
      println(
        "   - 这是一个小型GIF文件，适合作为图标或简单动画",
      )
    s if s < 102400 => println("   - 这是一个中等大小的GIF文件")
    s if s < 1048576 =>
      println("   - 这是一个较大的GIF文件，可能包含复杂动画")
    _ =>
      println("   - 这是一个很大的GIF文件，加载可能需要时间")
  }
}

///|
/// 运行完整演示程序
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

  // 演示代码
  demo_gif_parsing()
  test_basic_functions()
  demo_error_handling()
  advanced_verification()
  demo_extension_analysis()
  demo_performance_benchmarks()
  println("")
  println("✅ 演示完成！")
  println("")
  println(
    "💡 提示: 下次可以直接指定文件路径来分析特定的GIF文件",
  )
  println("   例如: moon run src/main your_image.gif")
}

///|
/// 演示扩展分析
fn demo_extension_analysis() -> Unit {
  println("\n🧩 5. 扩展块分析演示")
  println("------------------------------")

  // 测试结构分析功能
  println("🔍 GIF结构分析:")
  let complex_gif = create_gif_with_extensions()
  match @gif_decoder_lib.analyze_gif_structure(complex_gif) {
    Ok(analysis) => {
      let lines = analysis.split("\n")
      for line in lines {
        println("   " + line.to_string())
      }
    }
    Err(msg) => println("   ❌ 分析失败: " + msg)
  }

  // 测试扩展信息解析
  println("\n🔍 扩展信息解析:")
  test_extension_parsing()
}

///|
/// 演示性能基准测试
fn demo_performance_benchmarks() -> Unit {
  println("\n⚡ 6. 性能基准测试")
  println("------------------------------")

  // 创建不同大小的测试数据
  let test_cases = [
    ("小文件", create_minimal_gif()),
    ("中等文件", create_complete_gif()),
    ("大文件", create_large_test_gif()),
  ]
  for i = 0; i < test_cases.length(); i = i + 1 {
    let (name, data) = test_cases[i]
    println("🏃 " + name + " (" + data.length().to_string() + " 字节):")

    // 测试基础解码性能
    let iterations = 100
    let mut success_count = 0
    for j = 0; j < iterations; j = j + 1 {
      match @gif_decoder_lib.decode_gif_basic(data) {
        Ok(_) => success_count = success_count + 1
        Err(_) => ()
      }
    }
    println(
      "   - 基础解码成功率: " +
      success_count.to_string() +
      "/" +
      iterations.to_string(),
    )

    // 测试完整解码
    match @gif_decoder_lib.decode_gif_complete(data) {
      Ok(_) => println("   - 完整解码: ✅ 成功")
      Err(msg) => println("   - 完整解码: ❌ " + msg)
    }
  }
}

///|
/// 测试扩展解析
fn test_extension_parsing() -> Unit {
  let extensions = [
    (
      "注释扩展",
      Bytes::from_array([0x21, 0xFE, 5, 72, 101, 108, 108, 111, 0]),
    ),
    (
      "应用扩展",
      Bytes::from_array([0x21, 0xFF, 8, 78, 69, 84, 83, 67, 65, 80, 69, 0]),
    ),
    (
      "图形控制扩展",
      Bytes::from_array([0x21, 0xF9, 4, 0x04, 0x64, 0x00, 0x01, 0]),
    ),
  ]
  for i = 0; i < extensions.length(); i = i + 1 {
    let (name, data) = extensions[i]
    match @gif_decoder_lib.parse_extension_info(data, 0) {
      Ok((ext_type, offset)) =>
        println(
          "   ✅ " +
          name +
          ": " +
          ext_type +
          " (偏移: " +
          offset.to_string() +
          ")",
        )
      Err(msg) => println("   ❌ " + name + ": " + msg)
    }
  }
}

///|
/// 创建包含扩展的GIF
fn create_gif_with_extensions() -> Bytes {
  Bytes::from_array([
    // GIF Header
    71, 73, 70, 56, 57, 97, // "GIF89a"

    // Logical Screen Descriptor
     16, 0, 16, 0, // 16x16
     0x80, 0, 0, // Global color table

    // Global Color Table
     0, 0, 0, // Black
     255, 255, 255, // White

    // Application Extension
     0x21, 0xFF, // Extension + Application label
     11, // Block size
     78, 69, 84, 83, 67, 65, 80, 69, // "NETSCAPE"
     50, 46, 48, // "2.0"
     3, // Data sub-block size
     1, 0, 0, // Loop count
     0, // Block terminator

    // Comment Extension
     0x21, 0xFE, // Extension + Comment label
     5, // Block size
     72, 101, 108, 108, 111, // "Hello"
     0, // Block terminator

    // Image Descriptor
     0x2C, // Image separator
     0, 0, 0, 0, // Position
     8, 0, 8, 0, // 8x8 size
     0, // No local color table

    // Image Data
     2, // LZW minimum code size
     4, // Data block size
     4, 16, 24, 5, // Simple LZW data
     0, // Block terminator

    // Trailer
     0x3B,
  ])
}

///|
/// 高级验证测试
fn advanced_verification() -> Unit {
  println("\n🚀 4. 高级验证测试")
  println("------------------------------")

  // 测试最小有效GIF
  println("🔬 最小GIF文件测试:")
  let minimal_gif = create_minimal_gif()
  match @gif_decoder_lib.decode_gif_complete(minimal_gif) {
    Ok(result) => println("   ✅ 成功: " + result)
    Err(msg) => println("   ❌ 失败: " + msg)
  }

  // 测试较大的GIF
  println("\n🔬 较大GIF文件测试:")
  let large_gif = create_large_test_gif()
  match @gif_decoder_lib.parse_gif_info(large_gif) {
    Ok(info) => {
      println("   ✅ 解析成功:")
      println(
        "      - 尺寸: " +
        info.width.to_string() +
        "x" +
        info.height.to_string(),
      )
      println("      - 颜色数: " + info.global_color_table_size.to_string())
    }
    Err(msg) => println("   ❌ 解析失败: " + msg)
  }

  // 字节序测试
  println("\n🔬 字节序转换测试:")
  test_byte_order()

  // 边界条件测试
  println("\n🔬 边界条件测试:")
  test_boundary_conditions()
}

///|
/// 测试边界条件
fn test_boundary_conditions() -> Unit {
  // 测试零尺寸图像
  let zero_size = Bytes::from_array([
    71, 73, 70, 56, 55, 97, // "GIF87a"
     0, 0, 0, 0, // 0x0 size
     0, 0, 0,
  ])
  match @gif_decoder_lib.parse_gif_info(zero_size) {
    Ok(info) =>
      println(
        "   ✅ 零尺寸解析: " +
        info.width.to_string() +
        "x" +
        info.height.to_string(),
      )
    Err(msg) => println("   ❌ 零尺寸解析失败: " + msg)
  }

  // 测试最大尺寸
  let max_size = Bytes::from_array([
    71, 73, 70, 56, 57, 97, // "GIF89a"
     255, 255, 255, 255, // 65535x65535
     0, 0, 0,
  ])
  match @gif_decoder_lib.parse_gif_info(max_size) {
    Ok(info) =>
      println(
        "   ✅ 最大尺寸解析: " +
        info.width.to_string() +
        "x" +
        info.height.to_string(),
      )
    Err(msg) => println("   ❌ 最大尺寸解析失败: " + msg)
  }
}

///|
/// 演示GIF解析功能
fn demo_gif_parsing() -> Unit {
  println("\n📋 1. GIF文件解析演示")
  println("------------------------------")

  // 创建一个完整的模拟GIF文件数据
  let gif_data = create_sample_gif()

  // 基础解码
  println("🔍 基础解码:")
  match @gif_decoder_lib.decode_gif_basic(gif_data) {
    Ok(result) => println("   " + result)
    Err(msg) => println("   错误: " + msg)
  }

  // 详细信息解析
  println("\n📊 详细信息解析:")
  match @gif_decoder_lib.parse_gif_info(gif_data) {
    Ok(info) => {
      println("   版本: " + info.version)
      println(
        "   尺寸: " + info.width.to_string() + "x" + info.height.to_string(),
      )
      println(
        "   全局颜色表: " +
        (if info.has_global_color_table { "是" } else { "否" }),
      )
      if info.has_global_color_table {
        println("   颜色数量: " + info.global_color_table_size.to_string())
        println(
          "   颜色分辨率: " + info.color_resolution.to_string() + " 位",
        )
      }
      println(
        "   排序标志: " + (if info.sort_flag { "是" } else { "否" }),
      )
      println("   背景颜色索引: " + info.bg_color_index.to_string())
      println("   像素宽高比: " + info.pixel_aspect_ratio.to_string())
    }
    Err(msg) => println("   错误: " + msg)
  }

  // 完整解码（包括图像信息）
  println("\n🖼️ 完整解码:")
  let complete_gif = create_complete_gif()
  match @gif_decoder_lib.decode_gif_complete(complete_gif) {
    Ok(result) => println("   " + result)
    Err(msg) => println("   错误: " + msg)
  }
}

///|
/// 测试基础功能
fn test_basic_functions() -> Unit {
  println("\n🧪 2. 基础功能测试")
  println("------------------------------")

  // 测试字节工具
  println("🔧 字节工具测试:")
  let b1 = (0x34).to_byte()
  let b2 = (0x12).to_byte()
  let u16_value = @gif_decoder_lib.to_u16_le(b1, b2)
  println(
    "   小端序转换: 0x" +
    b1.to_int().to_string() +
    " 0x" +
    b2.to_int().to_string() +
    " -> " +
    u16_value.to_string(),
  )

  // 基础解码器测试
  println("\n🧪 解码器基础测试:")
  let test_data = @gif_decoder_lib.create_test_gif_data()
  match @gif_decoder_lib.decode_gif_basic(test_data) {
    Ok(result) => println("   ✅ 测试GIF解码成功: " + result)
    Err(msg) => println("   ❌ 测试GIF解码失败: " + msg)
  }
}

///|
/// 演示错误处理
fn demo_error_handling() -> Unit {
  println("\n❌ 3. 错误处理演示")
  println("------------------------------")

  // 测试无效文件
  println("🚫 无效文件测试:")
  let invalid_data = Bytes::from_array([1, 2, 3, 4, 5])
  match @gif_decoder_lib.decode_gif_basic(invalid_data) {
    Ok(result) => println("   意外成功: " + result)
    Err(msg) => println("   ✓ 正确检测到错误: " + msg)
  }

  // 测试文件太小
  println("\n🚫 文件太小测试:")
  let tiny_data = Bytes::from_array([71, 73, 70]) // 只有 "GIF"
  match @gif_decoder_lib.parse_gif_info(tiny_data) {
    Ok(_) => println("   意外成功")
    Err(msg) => println("   ✓ 正确检测到错误: " + msg)
  }

  // 测试错误版本
  println("\n🚫 错误版本测试:")
  let wrong_version = Bytes::from_array([
    71, 73, 70, 57, 57, 97, // "GIF99a" - 无效版本
     10, 0, 10, 0, 0, 0, 0,
  ])
  match @gif_decoder_lib.decode_gif_basic(wrong_version) {
    Ok(_) => println("   意外成功")
    Err(msg) => println("   ✓ 正确检测到错误: " + msg)
  }

  // 测试损坏的颜色表
  println("\n🚫 损坏颜色表测试:")
  let corrupted_color_table = Bytes::from_array([
    71, 73, 70, 56, 57, 97, // "GIF89a"
     10, 0, 10, 0, // 10x10
     0x80, // 有全局颜色表但数据不足
     0, 0,
    // 缺少颜色表数据
  ])
  match
    @gif_decoder_lib.parse_global_color_table(corrupted_color_table, 13, 2) {
    Ok(_) => println("   意外成功")
    Err(msg) => println("   ✓ 正确检测到颜色表错误: " + msg)
  }
}

///|
/// 创建示例GIF数据
fn create_sample_gif() -> Bytes {
  Bytes::from_array([
      // GIF文件头
      71, 73, 70, 56, 57, 97, // "GIF89a"

      // 逻辑屏幕描述符
       64, 0, // 宽度 = 64
       48, 0, // 高度 = 48
       0xF0, // packed: 全局颜色表=1, 分辨率=7, 排序=0, 大小=0 (2色)
       0, // 背景颜色索引 = 0
       0,
    ], // 像素宽高比 = 0
  )
}

///|
/// 创建包含图像的完整GIF数据
fn create_complete_gif() -> Bytes {
  Bytes::from_array([
    // GIF文件头
    71, 73, 70, 56, 57, 97, // "GIF89a"

    // 逻辑屏幕描述符  
     32, 0, // 宽度 = 32
     32, 0, // 高度 = 32
     0x80, // packed: 全局颜色表=1, 分辨率=0, 排序=0, 大小=0 (2色)
     0, // 背景颜色索引
     0, // 像素宽高比

    // 全局颜色表 (2色)
     0, 0, 0, // 黑色
     255, 255, 255, // 白色

    // 图像描述符
     0x2C, // 图像分隔符
     0, 0, // left = 0
     0, 0, // top = 0  
     16, 0, // width = 16
     16, 0, // height = 16
     0x00, // packed: 无局部颜色表, 非交错

    // LZW最小代码大小
     2,

    // 图像数据 (简化的数据块)
     4, // 数据块大小 = 4
     0x04, 0x10, 0x18, 0x28, // 简单的LZW压缩数据
     0, // 数据块终止符

    // GIF文件终止符
     0x3B,
  ])
}

///|
/// 创建最小的有效GIF文件
fn create_minimal_gif() -> Bytes {
  Bytes::from_array([
    // GIF Header
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // "GIF89a"

    // Logical Screen Descriptor
     0x01, 0x00, // Width = 1
     0x01, 0x00, // Height = 1  
     0x80, // Global Color Table Flag = 1
     0x00, // Background Color Index = 0
     0x00, // Pixel Aspect Ratio = 0

    // Global Color Table (2 colors)
     0x00, 0x00, 0x00, // Color 0: Black
     0xFF, 0xFF, 0xFF, // Color 1: White

    // Image Descriptor
     0x2C, // Image Separator
     0x00, 0x00, // Left = 0
     0x00, 0x00, // Top = 0
     0x01, 0x00, // Width = 1
     0x01, 0x00, // Height = 1
     0x00, // Packed = 0

    // Image Data
     0x02, // LZW Minimum Code Size = 2
     0x02, // Data Sub-block size = 2
     0x04, 0x01, // LZW Data
     0x00, // Data Sub-block Terminator

    // GIF Trailer
     0x3B,
  ])
}

///|
/// 创建较大的测试GIF
fn create_large_test_gif() -> Bytes {
  Bytes::from_array([
    // GIF Header
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // "GIF89a"

    // Logical Screen Descriptor  
     0x10, 0x00, // Width = 16
     0x10, 0x00, // Height = 16
     0x91, // Global Color Table, 4 colors
     0x00, // Background = 0
     0x00, // Pixel Aspect Ratio = 0

    // Global Color Table (4 colors)
     0x00, 0x00, 0x00, // Black
     0xFF, 0x00, 0x00, // Red  
     0x00, 0xFF, 0x00, // Green
     0x00, 0x00, 0xFF, // Blue

    // Image Descriptor
     0x2C, // Image Separator
     0x00, 0x00, // Left = 0
     0x00, 0x00, // Top = 0
     0x08, 0x00, // Width = 8
     0x08, 0x00, // Height = 8
     0x00, // No local color table

    // Image Data
     0x02, // LZW min code size = 2
     0x08, // Data block size = 8
     0x04, 0x10, 0x18, 0x28, 0x30, 0x38, 0x40, 0x05, // LZW data
     0x00, // Data block terminator
     0x3B, // GIF Trailer
  ])
}

///|
/// 测试字节序转换
fn test_byte_order() -> Unit {
  println("   测试小端序转换:")

  // 测试几个值
  let test_cases = [
    (0x00, 0x01, 256), // 0x0100 = 256
    (0xFF, 0x00, 255), // 0x00FF = 255  
    (0x34, 0x12, 4660), // 0x1234 = 4660
    (0xCD, 0xAB, 43981), // 0xABCD = 43981
  ]
  for i = 0; i < test_cases.length(); i = i + 1 {
    let (b1, b2, expected) = test_cases[i]
    let result = @gif_decoder_lib.to_u16_le(b1.to_byte(), b2.to_byte())
    let status = if result == expected { "✅" } else { "❌" }
    println(
      "      " +
      status +
      " 0x" +
      b1.to_string() +
      " 0x" +
      b2.to_string() +
      " -> " +
      result.to_string() +
      " (期望: " +
      expected.to_string() +
      ")",
    )
  }
}
