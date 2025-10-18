///|
/// LZW 字典条目
pub struct LzwEntry {
  prefix : Int
  suffix : Byte
}

///|
/// LZW 解码器状态
pub struct LzwDecoder {
  dictionary : Array[LzwEntry]
  mut code_size : Int
  mut clear_code : Int
  mut end_code : Int
  mut next_code : Int
  mut max_code : Int
  mut dictionary_size : Int
}

///|
/// 创建新的 LZW 解码器
pub fn LzwDecoder::new(min_code_size : Int) -> LzwDecoder {
  let clear_code = 1 << min_code_size
  let end_code = clear_code + 1
  let initial_dict_size = 4096
  let dictionary = Array::make(initial_dict_size, {
    prefix: -1,
    suffix: b'\x00',
  })

  // 使用单字符条目初始化字典
  for i = 0; i < clear_code; i = i + 1 {
    dictionary[i] = { prefix: -1, suffix: i.to_byte() }
  }
  {
    dictionary,
    code_size: min_code_size + 1,
    clear_code,
    end_code,
    next_code: end_code + 1,
    max_code: (1 << (min_code_size + 1)) - 1,
    dictionary_size: clear_code,
  }
}

///|
/// 将字典重置为初始状态
pub fn reset_dictionary(self : LzwDecoder, min_code_size : Int) -> Unit {
  let clear_code = 1 << min_code_size
  let end_code = clear_code + 1

  // 重新初始化单字符条目
  for i = 0; i < clear_code; i = i + 1 {
    self.dictionary[i] = { prefix: -1, suffix: i.to_byte() }
  }
  self.code_size = min_code_size + 1
  self.clear_code = clear_code
  self.end_code = end_code
  self.next_code = end_code + 1
  self.max_code = (1 << (min_code_size + 1)) - 1
  self.dictionary_size = clear_code
}

///|
/// 向字典添加新条目
pub fn add_to_dictionary(
  self : LzwDecoder,
  prefix : Int,
  suffix : Byte,
) -> Unit {
  if self.next_code < self.dictionary.length() {
    self.dictionary[self.next_code] = { prefix, suffix }
    self.next_code = self.next_code + 1
    self.dictionary_size = self.dictionary_size + 1

    // 如果需要则增加代码大小
    if self.next_code > self.max_code && self.code_size < 12 {
      self.code_size = self.code_size + 1
      self.max_code = (1 << self.code_size) - 1
    }
  }
}

///|
/// 获取给定代码的字符串
pub fn get_string(self : LzwDecoder, code : Int) -> @list.List[Byte] {
  if code < 0 || code >= self.next_code {
    @list.new()
  } else {
    let mut result = @list.new()
    let mut current_code = code

    // 向后遍历字典链
    while current_code >= 0 && current_code < self.dictionary.length() {
      let entry = self.dictionary[current_code]
      result = @list.cons(entry.suffix, result)
      if entry.prefix == -1 {
        break
      }
      current_code = entry.prefix
    }
    result
  }
}

///|
/// 获取给定代码字符串的第一个字符
pub fn get_first_char(self : LzwDecoder, code : Int) -> Byte {
  if code < 0 || code >= self.next_code {
    b'\x00'
  } else {
    let mut current_code = code
    let mut result = b'\x00'

    // 遍历到根节点
    while current_code >= 0 && current_code < self.dictionary.length() {
      let entry = self.dictionary[current_code]
      result = entry.suffix
      if entry.prefix == -1 {
        break
      }
      current_code = entry.prefix
    }
    result
  }
}

///|
/// 可变长度代码的代码读取器（仅供内部使用）
pub struct CodeReader {
  data : @list.List[Byte]
  mut bit_buffer : Int
  mut bit_count : Int
  mut byte_index : Int
}

///|
/// 创建新的代码读取器（内部使用）
pub fn CodeReader::new(data : @list.List[Byte]) -> CodeReader {
  { data, bit_buffer: 0, bit_count: 0, byte_index: 0 }
}

///|
/// 读取给定位宽的下一个代码（内部使用）
pub fn read_code(self : CodeReader, code_size : Int) -> Int? {
  // 确保我们有足够的位
  while self.bit_count < code_size {
    match @list.List::nth(self.data, self.byte_index) {
      Some(byte) => {
        self.bit_buffer = self.bit_buffer | (byte.to_int() << self.bit_count)
        self.bit_count = self.bit_count + 8
        self.byte_index = self.byte_index + 1
      }
      None => {
        if self.bit_count == 0 {
          return None
        }
        break
      }
    }
  }
  if self.bit_count < code_size {
    None
  } else {
    let mask = (1 << code_size) - 1
    let code = self.bit_buffer & mask
    self.bit_buffer = self.bit_buffer >> code_size
    self.bit_count = self.bit_count - code_size
    Some(code)
  }
}

///|
/// 解码 LZW 压缩数据
pub fn decode_lzw(
  data : @list.List[Byte],
  min_code_size : Int,
) -> Result[@list.List[Byte], GifError] {
  if min_code_size < 2 || min_code_size > 11 {
    return Err(LzwDecodingError)
  }
  let decoder = LzwDecoder::new(min_code_size)
  let reader = CodeReader::new(data)
  let mut result = @list.new()
  let mut old_code : Int? = None

  // 读取代码直到结束
  while true {
    match reader.read_code(decoder.code_size) {
      None => break
      Some(code) => {
        // 处理特殊代码
        if code == decoder.clear_code {
          decoder.reset_dictionary(min_code_size)
          old_code = None
          continue
        }
        if code == decoder.end_code {
          break
        }
        match old_code {
          None => {
            // 清除或开始后的第一个代码
            let string = decoder.get_string(code)
            result = @list.List::concat(result, string)
            old_code = Some(code)
          }
          Some(prev_code) => {
            let string = if code < decoder.next_code {
              // 代码在字典中存在
              decoder.get_string(code)
            } else {
              // 代码尚不存在 - 特殊情况
              let prev_string = decoder.get_string(prev_code)
              let first_char = decoder.get_first_char(prev_code)
              @list.List::concat(
                prev_string,
                @list.List::from_array([first_char]),
              )
            }
            result = @list.List::concat(result, string)

            // 添加新的字典条目
            let first_char = decoder.get_first_char(code)
            decoder.add_to_dictionary(prev_code, first_char)
            old_code = Some(code)
          }
        }
      }
    }
  }
  Ok(result)
}

///|
/// 在 Array[Int] 和 List[Byte] 之间转换以保持兼容性
pub fn decode_lzw_from_array(
  data : Array[Int],
  min_code_size : Int,
) -> Result[Array[Int], GifError] {
  let byte_list = @list.List::from_array(data.map(fn(x) { x.to_byte() }))
  match decode_lzw(byte_list, min_code_size) {
    Ok(result) => {
      let array_result = @list.List::to_array(result).map(fn(b) { b.to_int() })
      Ok(array_result)
    }
    Err(e) => Err(e)
  }
}
