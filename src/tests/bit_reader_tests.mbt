// 辅助函数：创建字节列表
fn make_bytes(values: Array[Int]) -> @list.List[Byte] {
  let arr: Array[Byte] = values.map(fn(x: Int) -> Byte {
    x.to_byte()
  })
  @list.List::from_array(arr)
}

test "空数据读取" {
  let reader = @gif_decoder_lib.new(@list.List::empty())
  let (reader1, result) = reader.read_bits(1)
  assert_eq(result, None)
  
  // 状态应保持不变
  assert_eq(reader1.data, @list.List::empty())
  assert_eq(reader1.bit_offset, 0)
  assert_eq(reader1.bits_consumed, 0)
}

test "单字节读取 - 完整读取" {
  let data = make_bytes([0xAA]) // 0b10101010
  let reader = @gif_decoder_lib.new(data)
  
  // 读取8位
  let (reader1, bits1) = reader.read_bits(8)
  assert_eq(bits1, Some(0b10101010))
  
  // 状态验证
  assert_eq(reader1.data, @list.List::empty())
  assert_eq(reader1.bit_offset, 0) // 修改：应为0而不是8
  assert_eq(reader1.bits_consumed, 8)
  
  // 尝试继续读取
  let (_, bits2) = reader1.read_bits(1)
  assert_eq(bits2, None)
}

test "单字节读取 - 分次读取" {
  let data = make_bytes([0xAA]) // 0b10101010
  let reader = @gif_decoder_lib.new(data)
  
  // 读取4位
  let (reader1, bits1) = reader.read_bits(4)
  assert_eq(bits1, Some(0b1010))
  
  // 状态验证
  assert_eq(reader1.data, @list.List::empty())
  assert_eq(reader1.bit_offset, 4)
  assert_eq(reader1.bits_consumed, 4)
  
  // 再读取4位
  let (reader2, bits2) = reader1.read_bits(4)
  assert_eq(bits2, Some(0b1010))
  
  // 状态验证
  assert_eq(reader2.data, @list.List::empty())
  assert_eq(reader2.bit_offset, 0) // 修改：应为0而不是8
  assert_eq(reader2.bits_consumed, 8)
}

test "跨字节读取" {
  // 测试数据: 0b10101010 0b11001100 (0xAA, 0xCC)
  let data = make_bytes([0xAA, 0xCC])
  let reader = @gif_decoder_lib.new(data)
  
  // 读取6位
  let (reader1, bits1) = reader.read_bits(6)
  assert_eq(bits1, Some(0b101010))
  
  // 状态验证
  assert_eq(reader1.data.length(), 1) // 剩余一个字节
  assert_eq(reader1.bit_offset, 6)
  assert_eq(reader1.bits_consumed, 6)
  
  // 再读取6位
  let (reader2, bits2) = reader1.read_bits(6)
  assert_eq(bits2, Some(0b101100)) // 0b10 (剩余) + 0b1100 (新字节前4位)
  
  // 状态验证
  assert_eq(reader2.data.length(), 0) // 修改：应为0而不是1
  assert_eq(reader2.bit_offset, 4)
  assert_eq(reader2.bits_consumed, 12)
  
  // 再读取4位
  let (reader3, bits3) = reader2.read_bits(4)
  assert_eq(bits3, Some(0b1100)) // 0b1100 (剩余位)
  
  // 状态验证
  assert_eq(reader3.data.length(), 0)
  assert_eq(reader3.bit_offset, 0) // 修改：应为0而不是8
  assert_eq(reader3.bits_consumed, 16)
}

test "边界情况 - 字节耗尽" {
  // 测试数据: 0b11110000 (0xF0)
  let data = make_bytes([0xF0])
  let reader = @gif_decoder_lib.new(data)
  
  // 读取8位
  let (reader1, bits1) = reader.read_bits(8)
  assert_eq(bits1, Some(0b11110000))
  
  // 尝试继续读取
  let (_, bits2) = reader1.read_bits(1)
  assert_eq(bits2, None)
}

test "多字节精确读取" {
  // 测试数据: 0b00000001 0b10000000 (0x01, 0x80)
  let data = make_bytes([0x01, 0x80])
  let reader = @gif_decoder_lib.new(data)

  // 读取9位 (跨越字节边界)
  let (_, bits) = reader.read_bits(9)
  assert_eq(bits, Some(0b000000011)) // 0b00000001 + 0b1
}

test "读取超过可用数据" {
  // 测试数据: 0b10101010 (0xAA)
  let data = make_bytes([0xAA])
  let reader = @gif_decoder_lib.new(data)
  
  // 尝试读取9位
  let (reader1, bits1) = reader.read_bits(9)
  assert_eq(bits1, None) // 应该失败
  
  // 状态应保持不变
  assert_eq(reader1.data.length(), 1)
  assert_eq(reader1.bit_offset, 0)
  assert_eq(reader1.bits_consumed, 0)
  
  // 用原始reader读取8位 - 应该成功
  let (_, bits2) = reader.read_bits(8)
  assert_eq(bits2, Some(0b10101010))
}

test "部分读取后继续" {
  // 测试数据: 0b10101010 0b11001100 (0xAA, 0xCC)
  let data = make_bytes([0xAA, 0xCC])
  let reader = @gif_decoder_lib.new(data)
  
  // 读取4位
  let (reader1, bits1) = reader.read_bits(4)
  assert_eq(bits1, Some(0b1010))
  
  // 读取12位 (跨越字节边界)
  let (reader2, bits2) = reader1.read_bits(12)
  assert_eq(bits2, Some(0b101011001100)) // 0b1010 (剩余) + 0b11001100 (完整字节)
  
  // 状态验证
  assert_eq(reader2.data.length(), 0)
  assert_eq(reader2.bit_offset, 0) // 修改：应为0而不是8
  assert_eq(reader2.bits_consumed, 16)
}

test "零位读取" {
  let data = make_bytes([0xAA])
  let reader = @gif_decoder_lib.new(data)
  
  // 读取0位
  let (reader1, bits) = reader.read_bits(0)
  assert_eq(bits, None)
  
  // 状态应保持不变
  assert_eq(reader1.data.length(), 1)
  assert_eq(reader1.bit_offset, 0)
  assert_eq(reader1.bits_consumed, 0)
}

test "大位请求" {
  let data = make_bytes([0xAA, 0xBB, 0xCC])
  let reader = @gif_decoder_lib.new(data)
  
  // 请求17位（超过限制）
  let (reader1, bits) = reader.read_bits(17)
  assert_eq(bits, None)
  
  // 状态应保持不变
  assert_eq(reader1.data.length(), 3)
  assert_eq(reader1.bit_offset, 0)
  assert_eq(reader1.bits_consumed, 0)
}

test "精确位消耗" {
  let data = make_bytes([0xAA, 0xBB, 0xCC])
  let reader = @gif_decoder_lib.new(data)
  
  // 读取12位 (0xAA 全字节 + 0xBB 高4位)
  let (reader1, bits1) = reader.read_bits(12)
  assert_eq(bits1, Some(0b101010101011)) // 0xAA (10101010) + 0xBB 高4位 (1011) = 2731
  assert_eq(reader1.bits_consumed, 12)
  
  // 再读取12位 (0xBB 低4位 + 0xCC 全字节)
  let (reader2, bits2) = reader1.read_bits(12)
  assert_eq(bits2, Some(0b101111001100)) // 0xBB 低4位 (1011) + 0xCC (11001100) = 3020
  assert_eq(reader2.bits_consumed, 24)
  
  // 尝试再读取1位 (应返回 None)
  let (_, bits3) = reader2.read_bits(1)
  assert_eq(bits3, None)
}