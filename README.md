# GIF Decoder (MoonBit)

A comprehensive GIF decoder implemented in [MoonBit](https://www.moonbitlang.com/), featuring complete GIF parsing, LZW decompression, and animation support.

## 🌟 Features

* 🖼️ **Complete GIF Parsing** - Parse GIF headers, logical screen descriptors, and all data blocks
* 🎬 **Animation Support** - Decode animated GIFs with frame timing and disposal methods  
* 🔍 **LZW Decompression** - Full LZW algorithm implementation for image data decompression
* 🌊 **Streaming Decoder** - Consume arbitrarily large GIFs chunk‑by‑chunk via `StreamingGifDecoder`
* 🧮 **GIF Optimization Tools** - `gif_optimizer.mbt` removes duplicate frames, trims palettes, and enforces transparency
* 🧑‍🎨 **Advanced Transparency Handling** - Customize blending/threshold strategies with `TransparencyOptions`
* 🧰 **GIF Encoder** - Build brand‑new GIFs (including from RGBA frames) using `gif_encoder.mbt`
* 🌐 **WebAssembly Bindings** - Ready-to-export helpers inside `wasm_bindings.mbt`
* 🧪 **Comprehensive Testing** - Full test coverage with snapshot testing
* 📈 **Performance Analysis** - Built-in benchmarking and structure analysis tools

## 🚀 Quick Start

### Prerequisites
```bash
# Install MoonBit (if not already installed)
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash

# Install project dependencies
moon add moonbitlang/x@0.4.34
```

### Basic Usage
```bash
# Analyze a GIF file
moon run src/main <gif_file_path>

# Run with demo files
moon run src/main gif/__Attack.gif

# Run full demonstration (no arguments)
moon run src/main
```

### Example Output
```
🎨 GIF解码器 - 文件分析
==================================================
📁 文件信息: gif/__Attack.gif (125.4 KB)
✅ 基本解析成功
   版本: GIF89a
   尺寸: 256x256
   全局颜色表: 是
   颜色数量: 256
   背景颜色索引: 0

📊 详细信息解析:
   版本: GIF89a
   尺寸: 256x256
   全局颜色表: 是
   颜色数量: 256
   颜色分辨率: 8 位
   
🖼️ 图像分析:
   共找到 10 个图像描述符
   - 图像 1: 位置(0, 0), 尺寸: 256×256
   - 局部颜色表: 否
   - 交错模式: 否
```

## 📚 API Reference

### Core Functions

```moonbit
// Basic GIF parsing
decode_gif_basic(data: Bytes) -> Result[String, String]
decode_gif_complete(data: Bytes) -> Result[String, String]

// Detailed parsing
parse_gif_info(data: Bytes) -> Result[GifInfo, String] 
parse_image_descriptor(data: Bytes, offset: Int) -> Result[(ImageDesc, Int), String]

// LZW decompression  
decode_lzw(data: @list.List[Byte], min_code_size: Int) -> Result[@list.List[Byte], GifError]

// GIF encoder + optimizer
GifEncoder::new(options: GifEncoderOptions) -> GifEncoder
GifEncoder::add_frame(frame: GifFrameInput) -> Result[Unit, GifError]
GifEncoder::build() -> Result[Bytes, GifError]
create_frame_from_rgba(width: Int, height: Int, left: Int, top: Int, pixels: Array[RgbaColor], delay: Int, disposal: Int) -> Result[GifFrameInput, GifError]
optimize_gif(gif: Gif, options: GifOptimizationOptions) -> (Gif, OptimizationReport)

// Streaming decode
StreamingGifDecoder::new(options: StreamingDecoderOptions) -> StreamingGifDecoder
StreamingGifDecoder::process_chunk(chunk: Bytes) -> Result[@list.List[StreamingEvent], GifError]

// WebAssembly helpers
wasm_decode_gif_summary(data: Bytes) -> Result[String, String]
wasm_stream_decode(data: Bytes, chunk_size: Int) -> Result[Int, String]
wasm_encode_single_frame(pixels: Array[RgbaColor], width: Int, height: Int) -> Result[Bytes, String]
```

### Data Types

```moonbit
// Basic structures
struct GifHeader { version: String }
struct LogicalScreenDescriptor { ... }
struct ImageDescriptor { ... }
struct ColorTableEntry { red: Int, green: Int, blue: Int }

// Advanced types
struct GraphicControlExtension { ... }
struct ImageFrame { width: Int, height: Int, pixels: Array[RgbaColor] }
enum DisposalMethod { None, DoNotDispose, RestoreToBackground, RestoreToPrevious }
```

## 🧑‍🏭 GIF Optimization & Encoding

- **Optimizer (`gif_optimizer.mbt`)** – invoke `optimize_gif` with `GifOptimizationOptions` to drop duplicate frames, trim local palettes, and enforce background transparency. Inspect the returned `OptimizationReport` for counts.
- **Encoder (`gif_encoder.mbt`)** – create frames via `create_frame_from_rgba` or by supplying pre-indexed data, feed them to `GifEncoder`, and `build()` to obtain fully-formed GIF bytes. Works seamlessly with the optimizer for round-tripping.

## 🌊 Streaming & Transparency

- **Streaming decoder** – `StreamingGifDecoder::process_chunk` produces structured `StreamingEvent`s while keeping memory usage bounded, unlocking huge-file workflows.
- **Advanced transparency** – `TransparencyOptions` allow binary / threshold / brightness-preserving strategies, background preservation, and fallback colors. Use `render_all_frames_with_options` or `render_frame_to_canvas_with_options` to control blending precisely.

## 🕸️ WebAssembly Target

- WASM-friendly helpers live in `wasm_bindings.mbt` (`wasm_decode_gif_summary`, `wasm_stream_decode`, `wasm_encode_single_frame`, …) and only expose `Bytes`/primitive arguments.
- Build for WebAssembly GC:
  ```bash
  moon build src/lib -target wasm-gc -entry wasm_bindings
  ```
- The resulting module exports the binding functions automatically, ready for JS/wasmtime hosts.

## 🧪 Testing

```bash
# Run all tests
moon test

# Update snapshots after changes
moon test --update

# Generate coverage report
moon coverage analyze > uncovered.log

# Format and check code
moon fmt && moon check
```

### Test Structure

- **[src/tests/](src/tests/)** - Black-box tests
  - [`gif_decoder_tests.mbt`](src/tests/gif_decoder_tests.mbt) - Main decoder tests
  - [`bit_reader_tests.mbt`](src/tests/bit_reader_tests.mbt) - Bit reading utilities tests
  - [`lzw_decoder_test.mbt`](src/tests/lzw_decoder_test.mbt) - LZW algorithm tests
- **White-box tests** (ending in `_wbtest.mbt`) - Internal implementation tests

## 🏗️ Project Structure

```
src/
├── lib/                          # Core library
│   ├── gif_decoder.mbt          # Main GIF decoder logic
│   ├── gif_types.mbt            # Type definitions  
│   ├── lzw_decoder.mbt          # LZW decompression
│   ├── bit_reader.mbt           # Bit-level reading
│   ├── byte_utils.mbt           # Byte manipulation utilities
│   └── image_renderer.mbt       # Image rendering functions
├── main/                        # Command-line interface
│   └── main.mbt                 # CLI implementation
└── tests/                       # Test suite
    └── ...
```

## 🔧 Development

### Code Style
- Follow MoonBit block style with `///|` separators
- Use [`moon fmt`](Agents.md) to format code automatically  
- Update interfaces with `moon info`
- Keep deprecated code in `deprecated.mbt` files

### Development Workflow
```bash
# 1. Make changes to source code
# 2. Format and update interfaces
moon info && moon fmt

# 3. Run tests
moon test

# 4. Check for issues  
moon check

# 5. Update snapshots if behavior changed
moon test --update
```

## 📈 Performance

The decoder includes built-in performance analysis:

```bash
# Performance benchmarking is included in demo mode
moon run src/main

# Look for "⚡ 6. 性能基准测试" section in output
```

Typical performance characteristics:
- **Small files** (< 1KB): Sub-millisecond parsing
- **Medium files** (1-100KB): < 10ms parsing  
- **Large files** (> 100KB): Scales linearly with file size

## 🐛 Troubleshooting

### Common Issues

1. **"Invalid signature" error**
   - Ensure file is a valid GIF (starts with "GIF87a" or "GIF89a")

2. **"LZW decompression failed"**  
   - File may be corrupted or use unsupported LZW variant

3. **"Image too large" error**
   - Adjust size limits in [`gif_types.mbt`](src/lib/gif_types.mbt)

### Debug Mode
```bash
# Enable verbose output by examining the demo functions
# in main.mbt for debugging examples
```

## 🛣️ Roadmap

- [x] Basic GIF header parsing
- [x] LZW decompression algorithm
- [x] Color table support  
- [x] Animation frame extraction
- [x] Extension block parsing
- [x] Comprehensive test suite
- [x] **WebAssembly build target**
- [x] **Advanced transparency handling**
- [x] **GIF optimization tools**
- [x] **Streaming decoder for large files**
- [x] **GIF creation/encoding support**
