// 将两个字节转换为Uint16 (小端序)
pub fn to_u16_le(b1: Byte, b2: Byte) -> Int {
  (b1.to_int() & 0xFF) | ((b2.to_int() & 0xFF) << 8)
}

// 读取带符号字节
pub fn to_int8(b: Byte) -> Int {
  let v = b.to_int()
  if v > 127 { v - 256 } else { v }
}