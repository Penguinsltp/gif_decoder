///|
/// Canvas 创建和基本操作测试
test "canvas_creation_and_basic_ops" {
  let bg_color = @gif_decoder_lib.create_rgba_color(255, 255, 255, 255)
  let canvas = @gif_decoder_lib.Canvas::new(100, 100, bg_color)
  inspect(canvas.width, content="100")
  inspect(canvas.height, content="100")
  inspect(canvas.pixels.length(), content="10000")
}

///|
/// 颜色转换测试
test "color_conversion" {
  let color_entry = @gif_decoder_lib.create_color_entry(255, 128, 64)
  let rgba = @gif_decoder_lib.color_entry_to_rgba(color_entry, 200)
  inspect(rgba.red, content="255")
  inspect(rgba.green, content="128")
  inspect(rgba.blue, content="64")
  inspect(rgba.alpha, content="200")
}

///|
/// 透明度处理测试
test "transparency_handling" {
  let indices = @list.List::from_array([b'\x00', b'\x01', b'\x02'])
  let color_table = @list.List::from_array([
    @gif_decoder_lib.create_color_entry(255, 0, 0),
    @gif_decoder_lib.create_color_entry(0, 255, 0),
    @gif_decoder_lib.create_color_entry(0, 0, 255),
  ])
  let colors = @gif_decoder_lib.apply_color_table(indices, color_table, Some(1))
  let color_array = @list.List::to_array(colors)
  inspect(color_array.length(), content="3")
  inspect(color_array[0].alpha, content="255") // 不透明
  inspect(color_array[1].alpha, content="0") // 透明
  inspect(color_array[2].alpha, content="255") // 不透明
}
