// GIF解码器测试

///|
test "基本GIF解码测试" {
  // 创建一个简单的GIF89a文件头
  let test_data = Bytes::from_array([
    71, 73, 70, 56, 57, 97, // "GIF89a"
     10, 0, // width = 10
     10, 0, // height = 10  
     128, 0, 0, // packed(有全局颜色表), bg_index, aspect_ratio
  ])
  match @gif_decoder_lib.decode_gif_basic(test_data) {
    Ok(result) =>
      inspect(result, content="GIF 89a - 10x10 (Global color table: 2 colors)")
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "parse_gif 正确解析 Gif 结构" {
  let data = @gif_decoder_lib.create_test_gif_data()
  let parse_options = @gif_decoder_lib.create_parse_options(false, false, None)
  match @gif_decoder_lib.parse_gif_with_options(data, parse_options) {
    Ok(gif) => {
      inspect(gif.header.version, content="89a")
      inspect(gif.logical_screen.screen_width, content="16")
      inspect(gif.logical_screen.screen_height, content="16")
      match gif.global_color_table {
        Some(table) => inspect(table.length(), content="2")
        None => inspect("missing table", content="Should have table")
      }
      inspect(gif.data_blocks.length(), content="2")
    }
    Err(err) => inspect(err, content="Should not fail")
  }
}

///|
test "streaming decoder 产出正确事件流" {
  let data = @gif_decoder_lib.create_test_gif_data()
  let decoder = @gif_decoder_lib.StreamingGifDecoder::new(
    @gif_decoder_lib.default_streaming_options(),
  )
  let first_chunk = slice_bytes(data, 0, 5)
  match decoder.process_chunk(first_chunk) {
    Ok(events) => inspect(events.length(), content="0")
    Err(err) => inspect(err, content="Should not fail on first chunk")
  }
  let second_chunk = slice_bytes(data, 5, data.length() - 5)
  match decoder.process_chunk(second_chunk) {
    Ok(events) => {
      let arr = events.to_array()
      inspect(arr.length() >= 1, content="true")
      match arr[0] {
        Header(header, _) => inspect(header.version, content="89a")
        _ => inspect("missing header", content="First event should be header")
      }
    }
    Err(err) => inspect(err, content="Streaming decode should succeed")
  }
}

///|
fn slice_bytes(data : Bytes, start : Int, len : Int) -> Bytes {
  let array : Array[Byte] = []
  for i = 0; i < len && start + i < data.length(); i = i + 1 {
    array.push(data[start + i])
  }
  Bytes::from_array(array)
}

///|
test "GIF87a基础解码测试" {
  let test_data = Bytes::from_array([
    71, 73, 70, 56, 55, 97, // "GIF87a"
     20, 0, // width = 20
     15, 0, // height = 15  
     0, 0, 0, // packed(无全局颜色表), bg_index, aspect_ratio
  ])
  match @gif_decoder_lib.decode_gif_basic(test_data) {
    Ok(result) =>
      inspect(result, content="GIF 87a - 20x15 (No global color table)")
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "带全局颜色表的GIF测试" {
  let test_data = Bytes::from_array([
    71, 73, 70, 56, 57, 97, // "GIF89a"
     32, 0, // width = 32
     24, 0, // height = 24  
     0xF7, // packed: 全局颜色表=1, 颜色分辨率=7, 排序=1, 表大小=7 (256色)
     10, 49, // bg_index=10, aspect_ratio=49
  ])
  match @gif_decoder_lib.decode_gif_basic(test_data) {
    Ok(result) =>
      inspect(
        result,
        content="GIF 89a - 32x24 (Global color table: 256 colors)",
      )
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "无效GIF签名测试" {
  let test_data = Bytes::from_array([
    80, 78, 71, 56, 57, 97, // "PNG89a" - 错误的签名
     10, 0, 10, 0, 128, 0, 0,
  ])
  match @gif_decoder_lib.decode_gif_basic(test_data) {
    Ok(result) => inspect(result, content="Should not succeed")
    Err(msg) => inspect(msg, content="Invalid GIF signature")
  }
}

///|
test "不支持的版本测试" {
  let test_data = Bytes::from_array([
    71, 73, 70, 57, 48, 97, // "GIF90a" - 不支持的版本
     10, 0, 10, 0, 0, 0, 0,
  ])
  match @gif_decoder_lib.decode_gif_basic(test_data) {
    Ok(result) => inspect(result, content="Should not succeed")
    Err(msg) => inspect(msg, content="Unsupported GIF version: 90a")
  }
}

///|
test "文件太小测试" {
  let test_data = Bytes::from_array([71, 73, 70]) // 只有3字节
  match @gif_decoder_lib.decode_gif_basic(test_data) {
    Ok(result) => inspect(result, content="Should not succeed")
    Err(msg) => inspect(msg, content="File too small to be a valid GIF")
  }
}

///|
test "空文件测试" {
  let test_data = Bytes::from_array([])
  match @gif_decoder_lib.decode_gif_basic(test_data) {
    Ok(result) => inspect(result, content="Should not succeed")
    Err(msg) => inspect(msg, content="File too small to be a valid GIF")
  }
}

///|
test "详细信息解析测试" {
  let test_data = Bytes::from_array([
    71, 73, 70, 56, 57, 97, // "GIF89a"
     100, 0, // width = 100
     50, 0, // height = 50  
     0xFF, // packed: 全局颜色表=1, 颜色分辨率=7, 排序=1, 表大小=7 (256色)
     5, // bg_index = 5
     42, // aspect_ratio = 42
  ])
  match @gif_decoder_lib.parse_gif_info(test_data) {
    Ok(info) => {
      inspect(info.version, content="89a")
      inspect(info.width, content="100")
      inspect(info.height, content="50")
      inspect(info.has_global_color_table, content="true")
      inspect(info.global_color_table_size, content="256")
      inspect(info.color_resolution, content="8")
      inspect(info.sort_flag, content="true")
      inspect(info.bg_color_index, content="5")
      inspect(info.pixel_aspect_ratio, content="42")
    }
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "最小有效GIF87a信息解析" {
  let test_data = Bytes::from_array([
    71, 73, 70, 56, 55, 97, // "GIF87a"
     1, 0, // width = 1
     1, 0, // height = 1  
     0x00, // packed: 无全局颜色表
     0, // bg_index = 0
     0, // aspect_ratio = 0
  ])
  match @gif_decoder_lib.parse_gif_info(test_data) {
    Ok(info) => {
      inspect(info.version, content="87a")
      inspect(info.width, content="1")
      inspect(info.height, content="1")
      inspect(info.has_global_color_table, content="false")
      inspect(info.global_color_table_size, content="2")
      inspect(info.color_resolution, content="1")
      inspect(info.sort_flag, content="false")
    }
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "颜色表解析测试" {
  let color_data = Bytes::from_array([
    255, 0, 0, // 红色
     0, 255, 0, // 绿色
     0, 0, 255, // 蓝色
     128, 128, 128, // 灰色
     255, 255, 255, // 白色
     0, 0, 0, // 黑色
  ])
  match @gif_decoder_lib.parse_global_color_table(color_data, 0, 6) {
    Ok(colors) => {
      inspect(colors.length(), content="6")
      inspect(colors[0], content="{red: 255, green: 0, blue: 0}")
      inspect(colors[1], content="{red: 0, green: 255, blue: 0}")
      inspect(colors[2], content="{red: 0, green: 0, blue: 255}")
      inspect(colors[3], content="{red: 128, green: 128, blue: 128}")
      inspect(colors[4], content="{red: 255, green: 255, blue: 255}")
      inspect(colors[5], content="{red: 0, green: 0, blue: 0}")
    }
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "颜色表数据不足测试" {
  let color_data = Bytes::from_array([255, 0]) // 只有2字节，不够3个字节的颜色
  match @gif_decoder_lib.parse_global_color_table(color_data, 0, 1) {
    Ok(colors) => inspect(colors, content="Should not succeed")
    Err(msg) => inspect(msg, content="Insufficient data for color table")
  }
}

///|
test "图像描述符解析测试" {
  let image_desc_data = Bytes::from_array([
    0x2C, // Image separator
     10, 0, // left = 10
     20, 0, // top = 20
     50, 0, // width = 50
     40, 0, // height = 40
     0xC0, // packed: 局部颜色表=1, 交错=1, 排序=0, 表大小=0 (2色)
  ])
  match @gif_decoder_lib.parse_image_descriptor(image_desc_data, 0) {
    Ok((desc, offset)) => {
      inspect(desc.left, content="10")
      inspect(desc.top, content="20")
      inspect(desc.width, content="50")
      inspect(desc.height, content="40")
      inspect(desc.has_local_color_table, content="true")
      inspect(desc.interlaced, content="true")
      inspect(desc.sorted, content="false")
      inspect(desc.local_color_table_size, content="2")
      inspect(offset, content="10")
    }
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "无局部颜色表的图像描述符测试" {
  let image_desc_data = Bytes::from_array([
    0x2C, // Image separator
     0, 0, // left = 0
     0, 0, // top = 0
     100, 1, // width = 356 (小端序)
     200, 0, // height = 200
     0x00, // packed: 无局部颜色表，不交错
  ])
  match @gif_decoder_lib.parse_image_descriptor(image_desc_data, 0) {
    Ok((desc, offset)) => {
      inspect(desc.left, content="0")
      inspect(desc.top, content="0")
      inspect(desc.width, content="356")
      inspect(desc.height, content="200")
      inspect(desc.has_local_color_table, content="false")
      inspect(desc.interlaced, content="false")
      inspect(desc.local_color_table_size, content="0")
      inspect(offset, content="10")
    }
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "无效图像分隔符测试" {
  let image_desc_data = Bytes::from_array([
    0x21, // Extension introducer instead of image separator
     10, 0, 20, 0, 50, 0, 40, 0, 0xC0,
  ])
  match @gif_decoder_lib.parse_image_descriptor(image_desc_data, 0) {
    Ok((desc, offset)) => inspect((desc, offset), content="Should not succeed")
    Err(msg) => inspect(msg, content="Invalid image separator")
  }
}

///|
test "图像描述符数据不足测试" {
  let image_desc_data = Bytes::from_array([0x2C, 10, 0, 20]) // 数据不足10字节
  match @gif_decoder_lib.parse_image_descriptor(image_desc_data, 0) {
    Ok((desc, offset)) => inspect((desc, offset), content="Should not succeed")
    Err(msg) => inspect(msg, content="Insufficient data for image descriptor")
  }
}

///|
test "查找图像描述符测试" {
  let data_with_extensions = Bytes::from_array([
    0x21, 0xFE, 5, 72, 101, 108, 108, 111, 0, // Comment extension "Hello"
     0x21, 0xF9, 4, 0x04, 0x00, 0x00, 0x00, 0, // Graphic Control Extension
     0x2C, // Image separator at offset 17
     0, 0, 0, 0, 10, 0, 10, 0, 0, // Image descriptor
  ])
  match @gif_decoder_lib.find_image_descriptor(data_with_extensions, 0) {
    Ok(offset) => inspect(offset, content="17")
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "未找到图像描述符测试" {
  let data_without_image = Bytes::from_array([
    0x21, 0xFE, 3, 71, 73, 70, 0, // Comment extension only
     0x3B, // Trailer
  ])
  match @gif_decoder_lib.find_image_descriptor(data_without_image, 0) {
    Ok(offset) => inspect(offset, content="Should not succeed")
    Err(msg) => inspect(msg, content="No image found (reached trailer)")
  }
}

///|
test "扩展块处理的间接测试" {
  // 通过find_image_descriptor间接测试skip_data_sub_blocks功能
  let data_with_complex_extensions = Bytes::from_array([
    // 复杂的注释扩展，包含多个子块
    0x21, 0xFE, // Comment extension
     5, 72, 101, 108, 108, 111, // "Hello" 子块
     5, 87, 111, 114, 108, 100, // "World" 子块
     0, // 子块终止符

    // 应用扩展
     0x21, 0xFF, // Application extension
     3, 65, 66, 67, // "ABC" 子块
     0, // 子块终止符

    // 图像描述符
     0x2C, 0, 0, 0, 0, 10, 0, 10, 0, 0,
  ])
  match
    @gif_decoder_lib.find_image_descriptor(data_with_complex_extensions, 0) {
    Ok(offset) => inspect(offset, content="22") // 应该在所有扩展之后找到图像
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "创建ImageData结构测试" {
  // 通过解析现有的图像描述符来测试，而不是直接创建 ImageDesc
  let image_desc_data = Bytes::from_array([
    0x2C, // Image separator
     5, 0, // left = 5
     10, 0, // top = 10
     32, 0, // width = 32
     24, 0, // height = 24
     0xE0, // packed: 局部颜色表=1, 交错=0, 排序=1, 表大小=0 (2色)
  ])
  match @gif_decoder_lib.parse_image_descriptor(image_desc_data, 0) {
    Ok((desc, _)) => {
      let image_data = @gif_decoder_lib.create_image_data(
        desc,
        @list.from_array([b'T', b'E', b'S', b'T']),
      )
      inspect(image_data.descriptor.left, content="5")
      inspect(image_data.descriptor.top, content="10")
      inspect(image_data.descriptor.width, content="32")
      inspect(image_data.descriptor.height, content="24")
      inspect(image_data.descriptor.local_color_table_flag, content="true")
      inspect(image_data.descriptor.interlace_flag, content="true")
      inspect(image_data.descriptor.sort_flag, content="true")
      inspect(image_data.image_data.length(), content="4")
    }
    Err(msg) => inspect(msg, content="Should not error in parsing")
  }
}

///|
test "创建GIF数据块列表测试" {
  let data_blocks = @gif_decoder_lib.create_gif_data_blocks()
  inspect(data_blocks.length(), content="3")

  // 验证第一个块是扩展块
  match data_blocks.head() {
    Some(Extension(Application(app))) => {
      inspect(app.application_identifier, content="NETSCAPE")
      inspect(app.application_auth_code, content="2.0")
    }
    _ =>
      inspect(
        "Unexpected block type",
        content="Should be Application extension",
      )
  }
}

///|
test "完整GIF解码测试" {
  let test_data = @gif_decoder_lib.create_test_gif_data()
  match @gif_decoder_lib.decode_gif_complete(test_data) {
    Ok(result) => {
      inspect(result.contains("GIF 89a"), content="true")
      inspect(result.contains("16x16"), content="true")
      inspect(result.contains("Global colors: 2"), content="true")
      inspect(result.contains("Image: 16x16"), content="true")
    }
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "GIF结构分析测试" {
  let test_data = @gif_decoder_lib.create_test_gif_data()
  match @gif_decoder_lib.analyze_gif_structure(test_data) {
    Ok(result) => {
      inspect(result.contains("GIF 89a Structure Analysis"), content="true")
      inspect(result.contains("Canvas: 16x16"), content="true")
      inspect(result.contains("Global Color Table: 2 colors"), content="true")
      inspect(result.contains("Images: 1"), content="true")
      inspect(result.contains("Found trailer"), content="true")
    }
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "扩展块信息解析测试" {
  // 测试不同类型的扩展块
  let comment_ext = Bytes::from_array([0x21, 0xFE, 5, 72, 101, 108, 108, 111, 0], // Comment "Hello"
  )
  match @gif_decoder_lib.parse_extension_info(comment_ext, 0) {
    Ok((name, offset)) => {
      inspect(name, content="Comment")
      inspect(offset, content="9")
    }
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "应用扩展解析测试" {
  let app_ext = Bytes::from_array([0x21, 0xFF, 3, 65, 66, 67, 0], // Application extension "ABC"
  )
  match @gif_decoder_lib.parse_extension_info(app_ext, 0) {
    Ok((name, offset)) => {
      inspect(name, content="Application")
      inspect(offset, content="7")
    }
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "图形控制扩展解析测试" {
  let gce_ext = Bytes::from_array([0x21, 0xF9, 4, 0x04, 0x64, 0x00, 0x01, 0], // Graphic Control Extension
  )
  match @gif_decoder_lib.parse_extension_info(gce_ext, 0) {
    Ok((name, offset)) => {
      inspect(name, content="Graphic Control")
      inspect(offset, content="8")
    }
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "未知扩展解析测试" {
  let unknown_ext = Bytes::from_array([0x21, 0x99, 2, 1, 2, 0], // Unknown extension
  )
  match @gif_decoder_lib.parse_extension_info(unknown_ext, 0) {
    Ok((name, offset)) => {
      inspect(name, content="Unknown Extension")
      inspect(offset, content="6")
    }
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "扩展数据不足测试" {
  let truncated_ext = Bytes::from_array([0x21]) // 只有扩展引导符
  match @gif_decoder_lib.parse_extension_info(truncated_ext, 0) {
    Ok((name, offset)) => inspect((name, offset), content="Should not succeed")
    Err(msg) => inspect(msg, content="Extension data insufficient")
  }
}

///|
test "边界条件测试 - 最大尺寸图像" {
  let max_size_data = Bytes::from_array([
    71, 73, 70, 56, 57, 97, // "GIF89a"
     255, 255, // width = 65535
     255, 255, // height = 65535  
     0, 0, 0, // 无全局颜色表
  ])
  match @gif_decoder_lib.parse_gif_info(max_size_data) {
    Ok(info) => {
      inspect(info.width, content="65535")
      inspect(info.height, content="65535")
    }
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "边界条件测试 - 零尺寸图像" {
  let zero_size_data = Bytes::from_array([
    71, 73, 70, 56, 55, 97, // "GIF87a"
     0, 0, // width = 0
     0, 0, // height = 0  
     0, 0, 0,
  ])
  match @gif_decoder_lib.parse_gif_info(zero_size_data) {
    Ok(info) => {
      inspect(info.width, content="0")
      inspect(info.height, content="0")
    }
    Err(msg) => inspect(msg, content="Should not error")
  }
}

///|
test "测试通过解析获得的图像描述符功能" {
  // 测试通过实际解析获得ImageDesc，然后测试相关功能
  let complete_image_data = Bytes::from_array([
    0x2C, // Image separator
     100, 0, // left = 100
     50, 0, // top = 50
     200, 0, // width = 200
     150, 0, // height = 150
     0xC3, // packed: 局部颜色表=1, 交错=1, 排序=0, 表大小=3 (16色)
  ])
  match @gif_decoder_lib.parse_image_descriptor(complete_image_data, 0) {
    Ok((desc, _)) => {
      // 测试解析结果
      inspect(desc.left, content="100")
      inspect(desc.top, content="50")
      inspect(desc.width, content="200")
      inspect(desc.height, content="150")
      inspect(desc.has_local_color_table, content="true")
      inspect(desc.interlaced, content="true")
      inspect(desc.local_color_table_size, content="16")

      // 测试创建ImageData
      let test_pixel_data = @list.from_array([b'P', b'I', b'X', b'E', b'L', b'S'])
      let image_data = @gif_decoder_lib.create_image_data(desc, test_pixel_data)
      inspect(image_data.descriptor.width, content="200")
      inspect(image_data.descriptor.height, content="150")
      inspect(image_data.image_data.length(), content="6")
    }
    Err(msg) => inspect(msg, content="Should not error")
  }
}
