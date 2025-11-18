// GIF 编码与优化测试

///|
test "gif encoder produces valid header" {
  let color = @gif_decoder_lib.create_rgba_color(255, 0, 0, 255)
  let pixels = Array::make(4, color)
  match @gif_decoder_lib.create_frame_from_rgba(2, 2, 0, 0, pixels, 5, 2) {
    Ok(frame) => {
      let options = @gif_decoder_lib.create_gif_encoder_options(
        2,
        2,
        None,
        0,
        0,
        0,
      )
      let encoder = @gif_decoder_lib.GifEncoder::new(options)
      match encoder.add_frame(frame) {
        Ok(_) => ()
        Err(err) => inspect(err, content="Frame should be accepted")
      }
      match encoder.build() {
        Ok(bytes) => {
          inspect(bytes.length() > 0, content="true")
          inspect(bytes[0].to_int(), content="71") // 'G'
          match @gif_decoder_lib.decode_gif_basic(bytes) {
            Ok(summary) => inspect(summary.has_prefix("GIF"), content="true")
            Err(msg) => inspect(msg, content="Encoder output should decode")
          }
        }
        Err(err) => inspect(err, content="Encoder should succeed")
      }
    }
    Err(err) => inspect(err, content="Frame creation failed")
  }
}

///|
test "optimizer removes duplicate frames" {
  let source = @gif_decoder_lib.create_test_gif_data()
  let parse_options = @gif_decoder_lib.create_parse_options(false, false, None)
  match @gif_decoder_lib.parse_gif_with_options(source, parse_options) {
    Ok(gif) => {
      let blocks = gif.data_blocks.to_array()
      let mut duplicate : @gif_decoder_lib.GifDataBlock? = None
      for block in blocks {
        match block {
          @gif_decoder_lib.GifDataBlock::Image(_) => {
            duplicate = Some(block)
            break
          }
          _ => ()
        }
      }
      match duplicate {
        Some(image_block) => {
          let rebuilt : Array[@gif_decoder_lib.GifDataBlock] = []
          for block in blocks {
            match block {
              @gif_decoder_lib.GifDataBlock::Trailer =>
                rebuilt.push(image_block)
              _ => ()
            }
            rebuilt.push(block)
          }
          let mut new_list = @list.new()
          for i = rebuilt.length() - 1; i >= 0; i = i - 1 {
            new_list = @list.cons(rebuilt[i], new_list)
            if i == 0 {
              break
            }
          }
          let extended = @gif_decoder_lib.rebuild_gif(gif, new_list)
          let (_, report) = @gif_decoder_lib.optimize_gif(
            extended,
            @gif_decoder_lib.default_optimization_options(),
          )
          inspect(report.removed_frames, content="1")
        }
        None =>
          inspect("missing image", content="Test GIF should contain image")
      }
    }
    Err(err) => inspect(err, content="Should parse test gif")
  }
}

///|
test "advanced transparency handles brightness threshold" {
  let options = @gif_decoder_lib.create_transparency_options(
    @gif_decoder_lib.transparency_strategy_alpha_threshold(),
    100,
    true,
    @gif_decoder_lib.create_rgba_color(0, 0, 0, 0),
  )
  let color_table = @list.of([
    @gif_decoder_lib.create_color_entry(10, 10, 10),
    @gif_decoder_lib.create_color_entry(240, 240, 240),
  ])
  let indices = @list.of([b'\x00', b'\x01'])
  let converted = @gif_decoder_lib.apply_color_table_with_options(
    indices,
    color_table,
    None,
    options,
  )
  let array = converted.to_array()
  inspect(array[0].alpha, content="0")
  inspect(array[1].alpha, content="255")
}
