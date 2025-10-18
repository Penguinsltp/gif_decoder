///|
/// RGBA 颜色表示
pub struct RgbaColor {
  red : Int
  green : Int
  blue : Int
  alpha : Int
} derive(Show, Eq)

///|
/// 带有时间信息和处理方法的图像帧
pub struct ImageFrame {
  width : Int
  height : Int
  pixels : Array[RgbaColor]
  delay : Int // 延迟时间，单位为厘秒（1/100秒）
  disposal_method : Int // 0=无, 1=保留, 2=背景色, 3=上一帧
  transparent_index : Int?
} derive(Show)

///|
/// 动画帧的处理方法
pub enum DisposalMethod {
  None
  DoNotDispose
  RestoreToBackground
  RestoreToPrevious
} derive(Show, Eq)

///|
/// 用于合成帧的画布
pub struct Canvas {
  width : Int
  height : Int
  pixels : Array[RgbaColor]
  background_color : RgbaColor
  mut previous_frame : Array[RgbaColor]? // 用于处理方法 3
} derive(Show)

///|
/// 创建新画布
pub fn Canvas::new(width : Int, height : Int, background : RgbaColor) -> Canvas {
  if width <= 0 || height <= 0 {
    abort("画布尺寸必须为正数")
  }
  let total_pixels = width * height
  {
    width,
    height,
    pixels: Array::make(total_pixels, background),
    background_color: background,
    previous_frame: None,
  }
}

///|
/// 将画布清除为背景色
pub fn clear_to_background(self : Canvas) -> Unit {
  for i = 0; i < self.pixels.length(); i = i + 1 {
    self.pixels[i] = self.background_color
  }
}

///|
/// 为处理方法 3 保存当前画布状态
pub fn save_previous_frame(self : Canvas) -> Unit {
  let saved = Array::make(self.pixels.length(), self.background_color)
  for i = 0; i < self.pixels.length(); i = i + 1 {
    saved[i] = self.pixels[i]
  }
  self.previous_frame = Some(saved)
}

///|
/// 根据处置方法处理画布
pub fn apply_disposal_method(
  canvas : Canvas,
  previous_canvas : Canvas?,
  disposal_method : Int,
) -> Canvas {
  match disposal_method {
    0 => canvas // 无 - 不指定处置方法
    1 => canvas // 不处置 - 保留当前图像
    2 => {
      // 恢复到背景色 - 恢复到背景色
      let bg_color = create_rgba_color(255, 255, 255, 255)
      Canvas::new(canvas.width, canvas.height, bg_color)
    }
    3 =>
      // 恢复到上一帧 - 恢复到上一帧
      match previous_canvas {
        Some(prev) => prev
        None => canvas
      }
    _ => canvas // 未知方法，保持当前状态
  }
}

///|
/// 处理图形控制扩展
pub fn apply_graphic_control(
  canvas : Canvas,
  gce : GraphicControlExtension,
  frame_data : @list.List[Byte],
  color_table : @list.List[ColorTableEntry],
  descriptor : ImageDescriptor,
) -> Result[Canvas, GifError] {
  let transparent_index = if gce.transparent_color_flag {
    Some(gce.transparent_color_index)
  } else {
    None
  }
  let colors = apply_color_table(frame_data, color_table, transparent_index)
  render_pixels_to_canvas(canvas, colors, descriptor)
}

///|
/// 从整数创建处理方法
pub fn create_disposal_method(method_int : Int) -> DisposalMethod {
  match method_int {
    0 => None
    1 => DoNotDispose
    2 => RestoreToBackground
    3 => RestoreToPrevious
    _ => DoNotDispose // 默认回退
  }
}

///|
/// 将处理方法应用到画布
pub fn apply_disposal_method_to_canvas(
  canvas : Canvas,
  previous_canvas : Canvas?,
  disposal_method : DisposalMethod,
  frame_left : Int,
  frame_top : Int,
  frame_width : Int,
  frame_height : Int,
) -> Canvas {
  match disposal_method {
    None => canvas
    DoNotDispose => canvas
    RestoreToBackground => {
      let bg_color = canvas.background_color
      for y = frame_top
          y < frame_top + frame_height && y < canvas.height
          y = y + 1 {
        for x = frame_left
            x < frame_left + frame_width && x < canvas.width
            x = x + 1 {
          let index = y * canvas.width + x
          if index >= 0 && index < canvas.pixels.length() {
            canvas.pixels[index] = bg_color
          }
        }
      }
      canvas
    }
    RestoreToPrevious =>
      match previous_canvas {
        Some(prev) => {
          for y = frame_top
              y < frame_top + frame_height && y < canvas.height
              y = y + 1 {
            for x = frame_left
                x < frame_left + frame_width && x < canvas.width
                x = x + 1 {
              let index = y * canvas.width + x
              if index >= 0 &&
                index < canvas.pixels.length() &&
                index < prev.pixels.length() {
                canvas.pixels[index] = prev.pixels[index]
              }
            }
          }
          canvas
        }
        None => canvas
      }
  }
}

///|
/// 将处理方法应用到画布
pub fn apply_disposal_method(
  self : Canvas,
  disposal_method : Int,
  frame_left : Int,
  frame_top : Int,
  frame_width : Int,
  frame_height : Int,
) -> Unit {
  match disposal_method {
    0 | 1 => () // 无或不处置 - 保留当前帧
    2 =>
      // 恢复到背景色 - 将帧区域清除为背景色
      for y = 0; y < frame_height; y = y + 1 {
        for x = 0; x < frame_width; x = x + 1 {
          let canvas_x = frame_left + x
          let canvas_y = frame_top + y
          if canvas_x >= 0 &&
            canvas_x < self.width &&
            canvas_y >= 0 &&
            canvas_y < self.height {
            let index = canvas_y * self.width + canvas_x
            if index >= 0 && index < self.pixels.length() {
              self.pixels[index] = self.background_color
            }
          }
        }
      }
    3 =>
      // 恢复到上一帧 - 从保存的帧恢复
      match self.previous_frame {
        Some(saved) =>
          for y = 0; y < frame_height; y = y + 1 {
            for x = 0; x < frame_width; x = x + 1 {
              let canvas_x = frame_left + x
              let canvas_y = frame_top + y
              if canvas_x >= 0 &&
                canvas_x < self.width &&
                canvas_y >= 0 &&
                canvas_y < self.height {
                let index = canvas_y * self.width + canvas_x
                if index >= 0 &&
                  index < self.pixels.length() &&
                  index < saved.length() {
                  self.pixels[index] = saved[index]
                }
              }
            }
          }
        None => () // 没有要恢复的上一帧
      }
    _ => () // 未知处理方法，不做任何操作
  }
}

///|
/// 将颜色表条目转换为 RGBA
pub fn color_entry_to_rgba(entry : ColorTableEntry, alpha : Int) -> RgbaColor {
  let clamped_alpha = if alpha < 0 {
    0
  } else if alpha > 255 {
    255
  } else {
    alpha
  }
  { red: entry.red, green: entry.green, blue: entry.blue, alpha: clamped_alpha }
}

///|
/// 将颜色表应用到像素索引
pub fn apply_color_table(
  indices : @list.List[Byte],
  color_table : @list.List[ColorTableEntry],
  transparent_index : Int?,
) -> @list.List[RgbaColor] {
  let color_array = color_table.to_array()
  let mut result = @list.new()
  for byte_val in indices {
    let index = byte_val.to_int()
    let alpha = match transparent_index {
      Some(trans_idx) => if index == trans_idx { 0 } else { 255 }
      None => 255
    }
    if index >= 0 && index < color_array.length() {
      let color_entry = color_array[index]
      let rgba = color_entry_to_rgba(color_entry, alpha)
      result = @list.cons(rgba, result)
    } else {
      // 无效颜色索引，使用透明黑色
      result = @list.cons({ red: 0, green: 0, blue: 0, alpha: 0 }, result)
    }
  }
  result.rev()
}

///|
/// 获取有效颜色表（局部优先于全局）
pub fn get_effective_color_table(
  image_data : ImageData,
  global_color_table : @list.List[ColorTableEntry]?,
) -> @list.List[ColorTableEntry]? {
  match image_data.local_color_table {
    Some(table) => Some(table)
    None => global_color_table
  }
}

///|
/// 将单帧渲染到画布，正确处理处置方法
pub fn render_frame_to_canvas(
  canvas : Canvas,
  image_data : ImageData,
  color_table : @list.List[ColorTableEntry],
  transparent_index : Int?,
) -> Result[Unit, GifError] {
  let descriptor = image_data.descriptor

  // 验证图像尺寸
  if descriptor.width <= 0 || descriptor.height <= 0 {
    return Err(InvalidFormat)
  }
  let colored_pixels = apply_color_table(
    image_data.image_data,
    color_table,
    transparent_index,
  )
  let pixel_array = colored_pixels.to_array()

  // 验证像素数量
  let expected_pixels = descriptor.width * descriptor.height
  if pixel_array.length() != expected_pixels {
    return Err(InvalidFormat)
  }

  // 通过先去隔行处理隔行扫描图像
  let final_pixels = if descriptor.interlace_flag {
    deinterlace_pixels(pixel_array, descriptor.width, descriptor.height)
  } else {
    pixel_array
  }

  // 将像素复制到指定位置的画布
  let mut pixel_index = 0
  for y = 0; y < descriptor.height; y = y + 1 {
    for x = 0; x < descriptor.width; x = x + 1 {
      let canvas_x = descriptor.left + x
      let canvas_y = descriptor.top + y

      // 检查边界
      if canvas_x >= 0 &&
        canvas_x < canvas.width &&
        canvas_y >= 0 &&
        canvas_y < canvas.height &&
        pixel_index < final_pixels.length() {
        let pixel = final_pixels[pixel_index]
        let canvas_index = canvas_y * canvas.width + canvas_x

        // 画布索引边界检查
        if canvas_index >= 0 && canvas_index < canvas.pixels.length() {
          // 只绘制非透明像素
          if pixel.alpha > 0 {
            canvas.pixels[canvas_index] = pixel
          }
        }
      }
      pixel_index = pixel_index + 1
    }
  }
  Ok(())
}

///|
/// 为隔行扫描 GIF 图像去隔行处理像素
fn deinterlace_pixels(
  pixels : Array[RgbaColor],
  width : Int,
  height : Int,
) -> Array[RgbaColor] {
  if width <= 0 || height <= 0 || pixels.length() != width * height {
    return pixels // 返回原始数组以避免崩溃
  }
  let result = Array::make(pixels.length(), {
    red: 0,
    green: 0,
    blue: 0,
    alpha: 0,
  })
  let mut src_index = 0

  // 隔行扫描 GIF 使用 4 个遍历，具有不同的起始行和增量
  let passes = [
    (0, 8), // 遍历 1：每第 8 行，从第 0 行开始
    (4, 8), // 遍历 2：每第 8 行，从第 4 行开始
    (2, 4), // 遍历 3：每第 4 行，从第 2 行开始
    (1, 2),
  ] // 遍历 4：每第 2 行，从第 1 行开始
  for i = 0; i < passes.length(); i = i + 1 {
    let pass = passes[i]
    let start_row = pass.0
    let increment = pass.1
    let mut y = start_row
    while y < height && src_index < pixels.length() {
      for x = 0; x < width && src_index < pixels.length(); x = x + 1 {
        let dest_index = y * width + x
        if dest_index >= 0 && dest_index < result.length() {
          result[dest_index] = pixels[src_index]
        }
        src_index = src_index + 1
      }
      y = y + increment
    }
  }
  result
}

///|
/// 从图像数据创建帧，支持处理方法
pub fn create_frame(
  image_data : ImageData,
  global_color_table : @list.List[ColorTableEntry]?,
  graphic_control : GraphicControlExtension?,
  canvas_width : Int,
  canvas_height : Int,
) -> Result[ImageFrame, GifError] {
  // 验证画布尺寸
  if canvas_width <= 0 || canvas_height <= 0 {
    return Err(InvalidFormat)
  }

  // 获取有效颜色表
  let color_table = match
    get_effective_color_table(image_data, global_color_table) {
    Some(table) => table
    None => return Err(InvalidFormat)
  }

  // 获取透明度和处理信息
  let (transparent_index, disposal_method, delay) = match graphic_control {
    Some(gc) => {
      let trans_idx = if gc.transparent_color_flag {
        Some(gc.transparent_color_index)
      } else {
        None
      }
      let disposal = gc.disposal_method
      let frame_delay = if gc.delay_time > 0 { gc.delay_time } else { 10 }
      (trans_idx, disposal, frame_delay)
    }
    None => (None, 1, 10) // 默认：无透明度，不处置，0.1 秒延迟
  }

  // 创建画布并渲染
  let background = { red: 0, green: 0, blue: 0, alpha: 0 }
  let canvas = Canvas::new(canvas_width, canvas_height, background)
  match
    render_frame_to_canvas(canvas, image_data, color_table, transparent_index) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  Ok({
    width: canvas_width,
    height: canvas_height,
    pixels: canvas.pixels,
    delay,
    disposal_method,
    transparent_index,
  })
}

///|
/// 具有处理方法处理的高级画布渲染器
pub struct CanvasRenderer {
  canvas : Canvas
  mut previous_disposal : Int
  mut previous_bounds : (Int, Int, Int, Int) // 左, 上, 宽, 高
} derive(Show)

///|
/// 创建新画布渲染器
pub fn CanvasRenderer::new(
  width : Int,
  height : Int,
  background : RgbaColor,
) -> CanvasRenderer {
  {
    canvas: Canvas::new(width, height, background),
    previous_disposal: 1,
    previous_bounds: (0, 0, 0, 0),
  }
}

///|
/// 使用正确的处理方法渲染帧
pub fn render_frame_with_disposal(
  self : CanvasRenderer,
  frame : ImageFrame,
  image_descriptor : ImageDescriptor,
) -> Result[Unit, GifError] {
  // 应用上一帧的处理方法
  let (prev_left, prev_top, prev_width, prev_height) = self.previous_bounds
  self.canvas.apply_disposal_method(
    self.previous_disposal,
    prev_left,
    prev_top,
    prev_width,
    prev_height,
  )

  // 如果下一个处理方法可能需要，保存当前帧
  if frame.disposal_method == 3 {
    self.canvas.save_previous_frame()
  }

  // 将帧像素复制到画布
  let mut pixel_index = 0
  for y = 0
      y < frame.height && y + image_descriptor.top < self.canvas.height
      y = y + 1 {
    for x = 0
        x < frame.width && x + image_descriptor.left < self.canvas.width
        x = x + 1 {
      let canvas_x = image_descriptor.left + x
      let canvas_y = image_descriptor.top + y
      if canvas_x >= 0 && canvas_y >= 0 && pixel_index < frame.pixels.length() {
        let pixel = frame.pixels[pixel_index]
        let canvas_index = canvas_y * self.canvas.width + canvas_x
        if canvas_index >= 0 && canvas_index < self.canvas.pixels.length() {
          // 只绘制非透明像素
          if pixel.alpha > 0 {
            self.canvas.pixels[canvas_index] = pixel
          }
        }
      }
      pixel_index = pixel_index + 1
    }
  }

  // 为下一帧更新状态
  self.previous_disposal = frame.disposal_method
  self.previous_bounds = (
    image_descriptor.left,
    image_descriptor.top,
    image_descriptor.width,
    image_descriptor.height,
  )
  Ok(())
}

///|
/// 获取当前画布像素
pub fn get_canvas_pixels(self : CanvasRenderer) -> Array[RgbaColor] {
  self.canvas.pixels
}

///|
/// 从 GIF 数据渲染所有帧，正确处理处置方法
pub fn render_all_frames(gif : Gif) -> Result[@list.List[ImageFrame], GifError] {
  let mut frames = @list.new()
  let mut current_graphic_control : GraphicControlExtension? = None
  let canvas_width = gif.logical_screen.screen_width
  let canvas_height = gif.logical_screen.screen_height
  if canvas_width <= 0 || canvas_height <= 0 {
    return Err(InvalidFormat)
  }
  for block in gif.data_blocks {
    match block {
      Extension(ext_type) =>
        match ext_type {
          GraphicControl(gc) => current_graphic_control = Some(gc)
          _ => () // 暂时忽略其他扩展
        }
      Image(image_data) =>
        match
          create_frame(
            image_data,
            gif.global_color_table,
            current_graphic_control,
            canvas_width,
            canvas_height,
          ) {
          Ok(frame) => {
            frames = @list.cons(frame, frames)
            current_graphic_control = None // 使用后重置
          }
          Err(e) => return Err(e)
        }
      Trailer => break
    }
  }
  Ok(frames.rev())
}

///|
/// 带有处理方法跟踪的动画状态
pub struct AnimationState {
  mut current_frame : Int
  mut accumulated_time : Int
  total_frames : Int
  mut played_loops : Int
  loop_count : Int // 0 表示无限循环
  renderer : CanvasRenderer?
} derive(Show)

///|
/// 具有正确帧处理的动画控制器
pub struct AnimationController {
  frames : @list.List[ImageFrame]
  image_descriptors : @list.List[ImageDescriptor]
  state : AnimationState
} derive(Show)

///|
/// 创建支持帧处理的动画控制器
pub fn AnimationController::new(
  frames : @list.List[ImageFrame],
  descriptors : @list.List[ImageDescriptor],
  canvas_width : Int,
  canvas_height : Int,
  loop_count : Int,
) -> AnimationController {
  let total_frames = @list.List::length(frames)
  let background = { red: 0, green: 0, blue: 0, alpha: 255 }
  let renderer = if canvas_width > 0 && canvas_height > 0 {
    Some(CanvasRenderer::new(canvas_width, canvas_height, background))
  } else {
    None
  }
  {
    frames,
    image_descriptors: descriptors,
    state: {
      current_frame: 0,
      accumulated_time: 0,
      total_frames,
      played_loops: 0,
      loop_count: if loop_count < 0 {
        0
      } else {
        loop_count
      },
      renderer,
    },
  }
}

///| 更新动画状态（delta_ms 以毫秒为单位）

///|
/// 如果帧发生变化则返回 true
pub fn AnimationController::update(
  self : AnimationController,
  delta_ms : Int,
) -> Bool {
  if self.frames.is_empty() || self.state.total_frames == 0 {
    return false
  }

  // 如果循环次数用尽，停留在最后一帧
  if self.state.loop_count > 0 &&
    self.state.played_loops >= self.state.loop_count {
    self.state.current_frame = self.state.total_frames - 1
    return false
  }
  self.state.accumulated_time = self.state.accumulated_time + delta_ms
  let mut changed = false
  let mut safety_counter = 0 // 防止无限循环
  let max_iterations = 1000
  while safety_counter < max_iterations {
    safety_counter = safety_counter + 1
    let frame_opt = @list.List::nth(self.frames, self.state.current_frame)
    let frame = match frame_opt {
      Some(f) => f
      None => break // 如果无法检索帧则退出
    }
    let frame_delay = if frame.delay > 0 { frame.delay * 10 } else { 100 } // 最小 10ms 延迟
    if self.state.accumulated_time < frame_delay {
      break
    }
    self.state.accumulated_time = self.state.accumulated_time - frame_delay
    self.state.current_frame = self.state.current_frame + 1
    changed = true
    if self.state.current_frame >= self.state.total_frames {
      self.state.current_frame = 0
      self.state.played_loops = self.state.played_loops + 1

      // 如果循环次数用尽，停留在最后一帧
      if self.state.loop_count > 0 &&
        self.state.played_loops >= self.state.loop_count {
        self.state.current_frame = self.state.total_frames - 1
        self.state.accumulated_time = 0
        break
      }
    }
  }
  changed
}

///|
/// 获取当前渲染的帧像素
pub fn AnimationController::get_current_pixels(
  self : AnimationController,
) -> Array[RgbaColor]? {
  match
    (
      self.state.renderer,
      @list.List::nth(self.frames, self.state.current_frame),
      @list.List::nth(self.image_descriptors, self.state.current_frame),
    ) {
    (Some(renderer), Some(frame), Some(descriptor)) =>
      match renderer.render_frame_with_disposal(frame, descriptor) {
        Ok(_) => Some(renderer.get_canvas_pixels())
        Err(_) => None
      }
    _ => None
  }
}

///|
/// 获取当前帧
pub fn AnimationController::current_frame(
  self : AnimationController,
) -> ImageFrame? {
  @list.List::nth(self.frames, self.state.current_frame)
}

///|
/// 重置动画到开始
pub fn AnimationController::reset(self : AnimationController) -> Unit {
  self.state.current_frame = 0
  self.state.accumulated_time = 0
  self.state.played_loops = 0
}

///|
/// 检查动画是否结束
pub fn AnimationController::is_finished(self : AnimationController) -> Bool {
  if self.state.loop_count == 0 {
    return false // 无限循环，永不结束
  }
  self.state.played_loops >= self.state.loop_count
}

///|
/// 验证画布尺寸辅助函数
pub fn validate_dimensions(width : Int, height : Int) -> Result[Unit, GifError] {
  if width <= 0 || height <= 0 {
    Err(InvalidFormat)
  } else if width > 65535 || height > 65535 {
    Err(InvalidFormat) // GIF 最大尺寸
  } else {
    Ok(())
  }
}

///|
/// 动画循环信息
pub struct AnimationInfo {
  loop_count : Int // 0 = 无限，>0 = 具体次数
  background_color_index : Int
  pixel_aspect_ratio : Int
} derive(Show)

///|
/// 从 GIF 提取动画信息
pub fn extract_animation_info(gif : Gif) -> AnimationInfo {
  // 默认值
  let loop_count = 1
  let bg_color_index = gif.logical_screen.background_color_index
  let pixel_aspect = gif.logical_screen.pixel_aspect_ratio

  // 查找带有 NETSCAPE2.0 的应用程序扩展
  for block in gif.data_blocks {
    match block {
      Extension(ext_type) =>
        match ext_type {
          Application(app_ext) =>
            // 检查 NETSCAPE2.0 循环扩展
            if app_ext.application_identifier.length() >= 8 {
              // 实现将检查 "NETSCAPE" 标识符
              // 并从应用程序数据中提取循环次数
            }
          _ => ()
        }
      _ => ()
    }
  }
  {
    loop_count,
    background_color_index: bg_color_index,
    pixel_aspect_ratio: pixel_aspect,
  }
}

///|
/// 合并全局和局部颜色表
pub fn merge_color_tables(
  global : @list.List[ColorTableEntry]?,
  local_table : @list.List[ColorTableEntry]?,
  global_size : Int,
) -> @list.List[ColorTableEntry] {
  match local_table {
    Some(local_colors) => local_colors
    None =>
      match global {
        Some(global_colors) => global_colors
        None => {
          // 如果不存在，创建默认颜色表
          let mut default_table = @list.new()
          for i = 0; i < 1 << global_size; i = i + 1 {
            let color : ColorTableEntry = { red: 0, green: 0, blue: 0 }
            default_table = @list.cons(color, default_table)
          }
          default_table.rev()
        }
      }
  }
}

///|
/// 快速画布清除区域
pub fn fast_clear_region(
  canvas : Canvas,
  left : Int,
  top : Int,
  width : Int,
  height : Int,
  color : RgbaColor,
) -> Unit {
  for y = 0; y < height; y = y + 1 {
    for x = 0; x < width; x = x + 1 {
      let canvas_x = left + x
      let canvas_y = top + y
      if canvas_x >= 0 &&
        canvas_x < canvas.width &&
        canvas_y >= 0 &&
        canvas_y < canvas.height {
        let index = canvas_y * canvas.width + canvas_x
        if index >= 0 && index < canvas.pixels.length() {
          canvas.pixels[index] = color
        }
      }
    }
  }
}

///|
/// 创建 RgbaColor 实例
pub fn create_rgba_color(
  red : Int,
  green : Int,
  blue : Int,
  alpha : Int,
) -> RgbaColor {
  { red, green, blue, alpha }
}

///|
/// 创建 ColorTableEntry 实例  
pub fn create_color_entry(
  red : Int,
  green : Int,
  blue : Int,
) -> ColorTableEntry {
  { red, green, blue }
}

///|
/// 将像素渲染到画布，进行边界检查
pub fn render_pixels_to_canvas(
  canvas : Canvas,
  colors : @list.List[RgbaColor],
  descriptor : ImageDescriptor,
) -> Result[Canvas, GifError] {
  // 验证描述符尺寸
  if descriptor.width <= 0 || descriptor.height <= 0 {
    return Err(InvalidImageDescriptor)
  }
  let pixel_array = colors.to_array()
  let expected_pixels = descriptor.width * descriptor.height

  // 验证像素数量与预期尺寸匹配
  if pixel_array.length() != expected_pixels {
    return Err(InvalidFormat)
  }

  // 通过先去隔行处理隔行扫描图像
  let final_pixels = if descriptor.interlace_flag {
    deinterlace_pixels(pixel_array, descriptor.width, descriptor.height)
  } else {
    pixel_array
  }

  // 将像素复制到指定位置的画布
  let mut pixel_index = 0
  for y = 0; y < descriptor.height; y = y + 1 {
    for x = 0; x < descriptor.width; x = x + 1 {
      let canvas_x = descriptor.left + x
      let canvas_y = descriptor.top + y

      // 检查画布边界
      if canvas_x >= 0 &&
        canvas_x < canvas.width &&
        canvas_y >= 0 &&
        canvas_y < canvas.height &&
        pixel_index < final_pixels.length() {
        let pixel = final_pixels[pixel_index]
        let canvas_index = canvas_y * canvas.width + canvas_x

        // 画布索引边界检查
        if canvas_index >= 0 && canvas_index < canvas.pixels.length() {
          // 只绘制非透明像素（alpha > 0）
          if pixel.alpha > 0 {
            canvas.pixels[canvas_index] = pixel
          }
        }
      }
      pixel_index = pixel_index + 1
    }
  }
  Ok(canvas)
}
