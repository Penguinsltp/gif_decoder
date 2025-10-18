///|
pub struct BitReader {
  data : @list.List[Byte]
  current_byte : Byte
  bit_offset : Int
  bits_consumed : Int
  initialized : Bool
}

///|
pub fn new(data : @list.List[Byte]) -> BitReader {
  BitReader::{
    data,
    current_byte: 0,
    bit_offset: 0,
    bits_consumed: 0,
    initialized: false,
  }
}

///|
fn min(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
pub fn read_bits(self : BitReader, n : Int) -> (BitReader, Int?) {
  if n <= 0 || n > 16 {
    return (self, None)
  }

  // 计算可用位数
  let current_byte_bits = if self.initialized { 8 - self.bit_offset } else { 0 }
  let available_bits = current_byte_bits + self.data.length() * 8
  if n > available_bits {
    return (self, None)
  }

  // 递归读取位
  fn read_rec(
    self : BitReader,
    bits_needed : Int,
    accumulated : Int,
  ) -> (BitReader, Int?) {
    if bits_needed == 0 {
      return (self, Some(accumulated))
    }

    // 确保当前字节已加载
    let (current_byte, new_data) = if !self.initialized && !self.data.is_empty() {
      (self.data.head().unwrap(), self.data.unsafe_tail())
    } else {
      (self.current_byte, self.data)
    }
    let bits_available = 8 - self.bit_offset
    let bits_to_take = min(bits_available, bits_needed)

    // 正确计算掩码和位移
    let mask = if bits_available > 0 { (1 << bits_available) - 1 } else { 0 }
    let shift = bits_available - bits_to_take
    let part = (current_byte.to_int() & mask) >> shift
    let new_bit_offset = self.bit_offset + bits_to_take

    // 正确更新状态
    let (new_current_byte, final_data, new_initialized) = if new_bit_offset >= 8 &&
      !new_data.is_empty() {
      (new_data.head().unwrap(), new_data.unsafe_tail(), true)
    } else if new_bit_offset >= 8 {
      (0, new_data, false)
    } else {
      (current_byte, new_data, true)
    }
    let new_self = BitReader::{
      data: final_data,
      current_byte: new_current_byte,
      bit_offset: new_bit_offset % 8,
      bits_consumed: self.bits_consumed + bits_to_take,
      initialized: new_initialized,
    }
    read_rec(
      new_self,
      bits_needed - bits_to_take,
      (accumulated << bits_to_take) | part,
    )
  }

  read_rec(self, n, 0)
}
