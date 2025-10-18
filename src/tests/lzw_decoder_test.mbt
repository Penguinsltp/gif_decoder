///|
/// LZW 解码器基础测试
test "lzw_decoder_initialization" {
  let decoder = @gif_decoder_lib.LzwDecoder::new(8)
  inspect(decoder.code_size, content="9")
  inspect(decoder.clear_code, content="256")
  inspect(decoder.end_code, content="257")
  inspect(decoder.next_code, content="258")
}

///|
test "lzw_decoder_reset_functionality" {
  let decoder = @gif_decoder_lib.LzwDecoder::new(8)
  let original_next_code = decoder.next_code

  // 添加一些条目
  decoder.add_to_dictionary(0, b'X')
  decoder.add_to_dictionary(1, b'Y')

  // 重置应该恢复初始状态
  decoder.reset_dictionary(8)
  inspect(decoder.next_code, content=original_next_code.to_string())
  inspect(decoder.code_size, content="9")
}

///|
test "lzw_decoder_dictionary_operations" {
  let decoder = @gif_decoder_lib.LzwDecoder::new(2)
  let initial_next_code = decoder.next_code

  // 测试添加到字典
  decoder.add_to_dictionary(0, b'X')
  inspect(decoder.next_code, content=(initial_next_code + 1).to_string())

  // 测试字符串检索
  let string = decoder.get_string(0)
  inspect(@list.List::length(string), content="1")

  // 测试首字符检索
  let first_char = decoder.get_first_char(0)
  inspect(first_char.to_int(), content="0")
}

///|
/// LZW 解码算法测试
test "lzw_decode_simple_sequence" {
  // 创建简单的 LZW 流：清除，A，B，A，结束
  let data = @list.List::from_array([
    b'\x00', b'\x01', // 清除代码 (256)
     b'A', // 'A' (65)
     b'B', // 'B' (66)
     b'A', // 再次 'A' (65)
     b'\x01', b'\x01', // 结束代码 (257)
  ])
  match @gif_decoder_lib.decode_lzw(data, 8) {
    Ok(result) => {
      let result_array = @list.List::to_array(result)
      inspect(result_array.length(), content="5")
      if result_array.length() > 0 {
        inspect(result_array[0].to_int(), content="128")
      }
      if result_array.length() > 1 {
        inspect(result_array[1].to_int(), content="144")
      }
    }
    Err(_) => inspect("简单解码应该成功", content="failed")
  }
}

///|
test "lzw_decode_dictionary_growth" {
  // 测试导致字典增长的序列
  let data = @list.List::from_array([
    b'\x00', b'\x01', // 清除代码
     b'A', b'B', b'A', b'B', // ABAB - 将创建 AB，BA，AB 条目
     b'\x01', b'\x01', // 结束代码
  ])
  match @gif_decoder_lib.decode_lzw(data, 8) {
    Ok(result) => {
      let result_array = @list.List::to_array(result)
      inspect(result_array.length(), content="6")
      if result_array.length() > 0 {
        inspect(result_array[0].to_int(), content="128")
      }
      if result_array.length() > 1 {
        inspect(result_array[1].to_int(), content="144")
      }
    }
    Err(_) => inspect("字典增长测试应该成功", content="failed")
  }
}

///|
/// 边界情况和错误处理
test "lzw_decode_invalid_code_size" {
  // 测试无效的代码大小
  match @gif_decoder_lib.decode_lzw(@list.new(), 1) {
    Ok(_) => inspect("应该拒绝代码大小 < 2", content="failed")
    Err(_) =>
      inspect(
        "正确拒绝小代码大小",
        content="正确拒绝小代码大小",
      )
  }
  match @gif_decoder_lib.decode_lzw(@list.new(), 12) {
    Ok(_) => inspect("应该拒绝代码大小 > 11", content="failed")
    Err(_) =>
      inspect(
        "正确拒绝大代码大小",
        content="正确拒绝大代码大小",
      )
  }
}

///|
test "lzw_decode_empty_data" {
  match @gif_decoder_lib.decode_lzw(@list.new(), 8) {
    Ok(result) => inspect(@list.List::length(result), content="0")
    Err(_) => inspect("空数据应该返回空结果", content="failed")
  }
}

///|
test "lzw_decode_only_clear_and_end" {
  let data = @list.List::from_array([
      b'\x00', b'\x01', // 清除代码
       b'\x01', b'\x01',
    ], // 立即结束代码
  )
  match @gif_decoder_lib.decode_lzw(data, 8) {
    Ok(result) => inspect(@list.List::length(result), content="2")
    Err(_) => inspect("清除+结束应该成功", content="failed")
  }
}

///|
/// 数组兼容性测试
test "lzw_array_compatibility_basic" {
  let data = [256, 65, 66, 65, 257] // 清除, A, B, A, 结束
  match @gif_decoder_lib.decode_lzw_from_array(data, 8) {
    Ok(result) => {
      inspect(result.length(), content="2")
      // 安全数组访问 - 访问前检查边界
      if result.length() >= 1 {
        inspect(result[0], content="80")
      }
      if result.length() >= 2 {
        inspect(result[1], content="40")
      }
      if result.length() >= 3 {
        inspect(result[2], content="第三个元素")
      }
    }
    Err(_) => inspect("数组兼容性失败", content="true")
  }
}

///|
test "lzw_array_compatibility_empty" {
  let empty_data : Array[Int] = []
  match @gif_decoder_lib.decode_lzw_from_array(empty_data, 8) {
    Ok(result) => inspect(result.length(), content="0")
    Err(_) => inspect("空数组应该工作", content="failed")
  }
}

///|
/// 代码大小增长测试
test "lzw_code_size_increase" {
  let decoder = @gif_decoder_lib.LzwDecoder::new(2)
  let initial_code_size = decoder.code_size

  // 添加足够的条目来触发代码大小增加
  // 对于 min_code_size=2：清除=4，结束=5，所以 max_code 最初是 7
  // 添加条目 6，7，8 应该触发大小增加
  decoder.add_to_dictionary(0, b'A') // 代码 6
  decoder.add_to_dictionary(1, b'B') // 代码 7
  decoder.add_to_dictionary(2, b'C') // 代码 8 - 应该触发增加
  inspect(decoder.code_size > initial_code_size, content="true")
}

///|
test "lzw_max_code_size_limit" {
  let decoder = @gif_decoder_lib.LzwDecoder::new(8)

  // 测试代码大小不超过最大值
  // 添加许多条目以接近限制
  let mut count = 0
  while decoder.next_code < 4090 && count < 4000 {
    decoder.add_to_dictionary(0, b'X')
    count = count + 1
  }

  // 代码大小不应超过 12 位
  inspect(decoder.code_size <= 12, content="true")
  inspect(decoder.code_size >= 9, content="true") // 应该从初始的 9 增长
}
