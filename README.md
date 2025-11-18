# GIF Decoder (MoonBit)

Select language / 选择语言：

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
