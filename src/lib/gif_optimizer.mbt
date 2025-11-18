// GIF 优化工具

///|
pub struct GifOptimizationOptions {
  remove_duplicate_frames : Bool
  enforce_transparent_background : Bool
  prefer_global_palette : Bool
  shrink_local_palettes : Bool
} derive(Show)

///|
pub struct OptimizationReport {
  removed_frames : Int
  updated_transparency : Int
  normalized_palettes : Int
} derive(Show)

///|
pub fn default_optimization_options() -> GifOptimizationOptions {
  {
    remove_duplicate_frames: true,
    enforce_transparent_background: true,
    prefer_global_palette: true,
    shrink_local_palettes: true,
  }
}

///|
pub fn optimize_gif(
  gif : Gif,
  options : GifOptimizationOptions,
) -> (Gif, OptimizationReport) {
  let mut new_blocks = @list.new()
  let mut pending_graphic_control : GraphicControlExtension? = None
  let mut last_signature : String? = None
  let mut removed_frames = 0
  let mut updated_transparency = 0
  let mut normalized_palettes = 0
  for block in gif.data_blocks {
    match block {
      Extension(ext_type) =>
        match ext_type {
          GraphicControl(gce) => pending_graphic_control = Some(gce)
          _ => new_blocks = @list.cons(Extension(ext_type), new_blocks)
        }
      Image(image_data) => {
        let mut processed_image = if options.shrink_local_palettes {
          shrink_image_palette(image_data)
        } else {
          image_data
        }
        if options.prefer_global_palette {
          match
            try_promote_to_global_palette(
              processed_image,
              gif.global_color_table,
            ) {
            Some((updated, changed)) => {
              if changed {
                normalized_palettes = normalized_palettes + 1
              }
              processed_image = updated
            }
            None => ()
          }
        }
        if options.remove_duplicate_frames {
          let signature = image_signature(processed_image)
          match last_signature {
            Some(sig) =>
              if sig == signature {
                removed_frames = removed_frames + 1
                pending_graphic_control = None
                continue
              } else {
                last_signature = Some(signature)
              }
            None => last_signature = Some(signature)
          }
        }
        let mut gce_to_emit = pending_graphic_control
        if options.enforce_transparent_background {
          match
            enforce_transparency_rule(
              gce_to_emit,
              processed_image,
              gif.global_color_table,
              gif.logical_screen.background_color_index,
            ) {
            (updated_gce, changed) => {
              if changed {
                updated_transparency = updated_transparency + 1
              }
              gce_to_emit = updated_gce
            }
          }
        }
        match gce_to_emit {
          Some(gce) => {
            new_blocks = @list.cons(Extension(GraphicControl(gce)), new_blocks)
            pending_graphic_control = None
          }
          None => pending_graphic_control = None
        }
        new_blocks = @list.cons(Image(processed_image), new_blocks)
      }
      Trailer => new_blocks = @list.cons(Trailer, new_blocks)
    }
  }
  let optimized_gif = Gif::{
    header: gif.header,
    logical_screen: gif.logical_screen,
    global_color_table: gif.global_color_table,
    data_blocks: new_blocks.rev(),
  }
  (
    optimized_gif,
    OptimizationReport::{
      removed_frames,
      updated_transparency,
      normalized_palettes,
    },
  )
}

///|
fn image_signature(image_data : ImageData) -> String {
  let descriptor = image_data.descriptor
  let mut builder = "frame:".to_string()
  builder = builder +
    descriptor.left.to_string() +
    "," +
    descriptor.top.to_string() +
    "," +
    descriptor.width.to_string() +
    "x" +
    descriptor.height.to_string()
  let mut counter = 0
  for byte in image_data.image_data {
    if counter >= 32 {
      break
    }
    builder = builder + ":" + byte.to_int().to_string()
    counter = counter + 1
  }
  builder
}

///|
fn shrink_image_palette(image_data : ImageData) -> ImageData {
  match image_data.local_color_table {
    Some(table) => {
      let used_index = max_color_index(image_data.image_data)
      let required_size = next_power_of_two(used_index + 1)
      let table_array = table.to_array()
      if required_size >= table_array.length() {
        image_data
      } else {
        let mut trimmed = @list.new()
        for i = required_size - 1; i >= 0; i = i - 1 {
          if i < table_array.length() {
            trimmed = @list.cons(table_array[i], trimmed)
          }
          if i == 0 {
            break
          }
        }
        ImageData::{
          descriptor: image_data.descriptor,
          local_color_table: Some(trimmed),
          image_data: image_data.image_data,
        }
      }
    }
    None => image_data
  }
}

///|
fn max_color_index(indices : @list.List[Byte]) -> Int {
  let mut max_value = 0
  for byte in indices {
    let value = byte.to_int()
    if value > max_value {
      max_value = value
    }
  }
  max_value
}

///|
fn next_power_of_two(value : Int) -> Int {
  if value <= 0 {
    return 1
  }
  let mut power = 1
  while power < value && power < 256 {
    power = power * 2
  }
  power
}

///|
fn try_promote_to_global_palette(
  image_data : ImageData,
  global_color_table : @list.List[ColorTableEntry]?,
) -> (ImageData, Bool)? {
  match (image_data.local_color_table, global_color_table) {
    (Some(local_table), Some(global_table)) =>
      if color_tables_equal(local_table, global_table) {
        Some(
          (
            ImageData::{
              descriptor: image_data.descriptor,
              local_color_table: None,
              image_data: image_data.image_data,
            },
            true,
          ),
        )
      } else {
        None
      }
    _ => None
  }
}

///|
fn color_tables_equal(
  a : @list.List[ColorTableEntry],
  b : @list.List[ColorTableEntry],
) -> Bool {
  let arr_a = a.to_array()
  let arr_b = b.to_array()
  if arr_a.length() != arr_b.length() {
    return false
  }
  for i = 0; i < arr_a.length(); i = i + 1 {
    if arr_a[i] != arr_b[i] {
      return false
    }
  }
  true
}

///|
fn enforce_transparency_rule(
  gce : GraphicControlExtension?,
  image_data : ImageData,
  global_color_table : @list.List[ColorTableEntry]?,
  background_index : Int,
) -> (GraphicControlExtension?, Bool) {
  match gce {
    Some(gc) => {
      if gc.transparent_color_flag {
        return (Some(gc), false)
      }
      let color_table = match image_data.local_color_table {
        Some(local_table) => Some(local_table)
        None => global_color_table
      }
      match color_table {
        Some(table) => {
          let table_array = table.to_array()
          if background_index >= 0 && background_index < table_array.length() {
            let updated = GraphicControlExtension::{
              disposal_method: gc.disposal_method,
              user_input_flag: gc.user_input_flag,
              transparent_color_flag: true,
              delay_time: gc.delay_time,
              transparent_color_index: background_index,
            }
            (Some(updated), true)
          } else {
            (Some(gc), false)
          }
        }
        None => (Some(gc), false)
      }
    }
    None => (None, false)
  }
}
