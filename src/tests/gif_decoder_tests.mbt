// GIF解码器测试

test "基本GIF解码测试" {
  // 创建一个简单的GIF89a文件头
  let test_data = Bytes::from_array([
    71, 73, 70, 56, 57, 97,  // "GIF89a"
    10, 0,                    // width = 10
    10, 0,                    // height = 10  
    128, 0, 0                 // packed(有全局颜色表), bg_index, aspect_ratio
  ])
  
  match @gif_decoder_lib.decode_gif_basic(test_data) {
    Ok(result) => {
      assert_true(result.contains("GIF 89a"))
      assert_true(result.contains("10x10"))
      assert_true(result.contains("Global color table"))
    }
    Err(_msg) => assert_false(true) // message="解码失败: " + msg
  }
}

test "GIF87a测试" {
  let test_data = Bytes::from_array([
    71, 73, 70, 56, 55, 97,  // "GIF87a"
    20, 0,                    // width = 20
    15, 0,                    // height = 15  
    0, 0, 0                   // packed(无全局颜色表), bg_index, aspect_ratio
  ])
  
  match @gif_decoder_lib.decode_gif_basic(test_data) {
    Ok(result) => {
      assert_true(result.contains("GIF 87a"))
      assert_true(result.contains("20x15"))
      assert_true(result.contains("No global color table"))
    }
    Err(_msg) => assert_false(true) // message="解码失败: " + msg
  }
}

test "无效GIF签名测试" {
  let test_data = Bytes::from_array([
    80, 78, 71, 56, 57, 97,  // "PNG89a" - 错误的签名
    10, 0, 10, 0, 128, 0, 0
  ])
  
  match @gif_decoder_lib.decode_gif_basic(test_data) {
    Ok(_) => assert_false(true) // message="应该检测到无效签名"
    Err(msg) => assert_true(msg.contains("Invalid GIF signature"))
  }
}

test "文件太小测试" {
  let test_data = Bytes::from_array([71, 73, 70])  // 只有3字节
  
  match @gif_decoder_lib.decode_gif_basic(test_data) {
    Ok(_) => assert_false(true) // message="应该检测到文件太小"
    Err(msg) => assert_true(msg.contains("too small"))
  }
}

test "详细信息解析测试" {
  let test_data = Bytes::from_array([
    71, 73, 70, 56, 57, 97,  // "GIF89a"
    100, 0,                   // width = 100
    50, 0,                    // height = 50  
    0xFF,                     // packed: 全局颜色表=1, 颜色分辨率=7, 排序=1, 表大小=7 (256色)
    5,                        // bg_index = 5
    42                        // aspect_ratio = 42
  ])
  
  match @gif_decoder_lib.parse_gif_info(test_data) {
    Ok(info) => {
      assert_eq(info.version, "89a")
      assert_eq(info.width, 100)
      assert_eq(info.height, 50)
      assert_true(info.has_global_color_table)
      assert_eq(info.global_color_table_size, 256)
      assert_eq(info.color_resolution, 8)
      assert_true(info.sort_flag)
      assert_eq(info.bg_color_index, 5)
      assert_eq(info.pixel_aspect_ratio, 42)
    }
    Err(_msg) => assert_false(true) // message="详细解析失败: " + msg
  }
}

test "测试函数验证" {
  let result = @gif_decoder_lib.test_gif_decoder()
  assert_true(result.contains("Test passed"))
}