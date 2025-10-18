///|
/// LZW 解码器白盒测试
test "lzw_entry_structure" {
  // 由于 LzwEntry 是只读的，我们通过解码器的内部操作来测试它
  let decoder = @gif_decoder_lib.LzwDecoder::new(8)

  // 添加一个条目并验证它被正确添加
  decoder.add_to_dictionary(10, b'A')

  // 通过检查字符串检索来测试条目是否被创建
  let string = decoder.get_string(decoder.next_code - 1)
  inspect(@list.List::length(string), content="2") // 应该有前缀 + 后缀
  let chars = @list.List::to_array(string)
  inspect(chars[0].to_int(), content="10") // 前缀值
  inspect(chars[1].to_int(), content="65") // 'A' 后缀
}

///|
test "dictionary_traversal" {
  let decoder = @gif_decoder_lib.LzwDecoder::new(8)

  // 添加链：0 -> A -> B
  decoder.add_to_dictionary(0, b'A') // 代码 258
  decoder.add_to_dictionary(258, b'B') // 代码 259
  let string = decoder.get_string(259)
  let string_array = @list.List::to_array(string)
  inspect(string_array.length(), content="3")
  inspect(string_array[0].to_int(), content="0") // 原始字符
  inspect(string_array[1].to_int(), content="65") // 'A'
  inspect(string_array[2].to_int(), content="66") // 'B'
}

///|
test "first_char_traversal" {
  let decoder = @gif_decoder_lib.LzwDecoder::new(8)

  // 创建链并测试首字符提取
  decoder.add_to_dictionary(65, b'B') // A->B，代码 258
  decoder.add_to_dictionary(258, b'C') // A->B->C，代码 259
  let first_char = decoder.get_first_char(259)
  inspect(first_char.to_int(), content="65") // 应该是 'A'
}

///|
test "dictionary_boundary_conditions" {
  let decoder = @gif_decoder_lib.LzwDecoder::new(8)

  // 测试在边界访问代码
  let valid_string = decoder.get_string(255) // 最后一个有效的初始代码
  inspect(@list.List::length(valid_string), content="1")
  let invalid_string = decoder.get_string(300) // 超出当前范围
  inspect(@list.List::length(invalid_string), content="0")
  let negative_string = decoder.get_string(-1) // 负数代码
  inspect(@list.List::length(negative_string), content="0")
}

///|
test "code_size_calculation_precision" {
  let decoder = @gif_decoder_lib.LzwDecoder::new(8)

  // 测试代码大小增加的精确边界
  inspect(decoder.max_code, content="511") // 2^9 - 1

  // 添加条目直到 max_code
  while decoder.next_code <= decoder.max_code && decoder.next_code < 4096 {
    decoder.add_to_dictionary(0, b'X')
  }

  // 代码大小应该增加了
  inspect(decoder.code_size > 9, content="true")
}

///|
/// 内存和性能边界情况
test "large_dictionary_handling" {
  let decoder = @gif_decoder_lib.LzwDecoder::new(8)

  // 添加许多条目来测试字典增长
  let mut added_count = 0
  while decoder.next_code < 1000 && decoder.next_code < 4096 {
    decoder.add_to_dictionary(0, (added_count % 256).to_byte())
    added_count = added_count + 1
  }
  inspect(added_count > 700, content="true") // 应该添加许多条目
  inspect(decoder.dictionary_size > 950, content="true")
}

///|
/// 内部结构测试
test "lzw_decoder_internal_state" {
  let decoder = @gif_decoder_lib.LzwDecoder::new(4)

  // 测试小代码大小的初始状态
  inspect(decoder.clear_code, content="16") // 2^4 = 16
  inspect(decoder.end_code, content="17") // clear_code + 1
  inspect(decoder.next_code, content="18") // end_code + 1
  inspect(decoder.code_size, content="5") // min_code_size + 1
  inspect(decoder.max_code, content="31") // 2^5 - 1
}

///|
test "dictionary_chain_integrity" {
  let decoder = @gif_decoder_lib.LzwDecoder::new(8)

  // 构建更长的链来测试完整性
  decoder.add_to_dictionary(65, b'B') // A->B (代码 258)
  decoder.add_to_dictionary(258, b'C') // A->B->C (代码 259)
  decoder.add_to_dictionary(259, b'D') // A->B->C->D (代码 260)

  // 测试完整链
  let full_string = decoder.get_string(260)
  let chars = @list.List::to_array(full_string)
  inspect(chars.length(), content="4")
  inspect(chars[0].to_int(), content="65") // 'A'
  inspect(chars[1].to_int(), content="66") // 'B'  
  inspect(chars[2].to_int(), content="67") // 'C'
  inspect(chars[3].to_int(), content="68") // 'D'
}

///|
test "edge_case_single_character_codes" {
  let decoder = @gif_decoder_lib.LzwDecoder::new(8)

  // 测试一些单字符代码
  for i = 0; i < 10; i = i + 1 {
    let string = decoder.get_string(i)
    inspect(@list.List::length(string), content="1")
    let char_value = @list.List::to_array(string)[0]
    inspect(char_value.to_int(), content=i.to_string())
  }
}

///|
test "dictionary_reset_behavior" {
  let decoder = @gif_decoder_lib.LzwDecoder::new(8)

  // 添加一些条目
  decoder.add_to_dictionary(65, b'B')
  decoder.add_to_dictionary(66, b'C')
  let size_before_reset = decoder.next_code

  // 重置字典
  decoder.reset_dictionary(8)

  // 验证重置工作了
  inspect(decoder.next_code < size_before_reset, content="true")
  inspect(decoder.code_size, content="9")
  inspect(decoder.clear_code, content="256")
  inspect(decoder.end_code, content="257")
}

///|
test "string_extraction_edge_cases" {
  let decoder = @gif_decoder_lib.LzwDecoder::new(8)

  // 测试边界代码的字符串提取
  let clear_string = decoder.get_string(256)
  inspect(@list.List::length(clear_string), content="1") // 清除代码应该返回单字节
  let end_string = decoder.get_string(257)
  inspect(@list.List::length(end_string), content="1") // 结束代码应该返回单字节

  // 测试超出字典范围
  let beyond_string = decoder.get_string(decoder.next_code + 100)
  inspect(@list.List::length(beyond_string), content="0")
}
