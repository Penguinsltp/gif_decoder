# GIF 解码器（MoonBit）

一个使用 [MoonBit](https://www.moonbitlang.com/) 实现的完整 GIF 解码器，涵盖 GIF 解析、LZW 解压、动画渲染以及 WebAssembly 绑定等高级能力。

## 🌟 功能特色

* 🖼️ **完整 GIF 解析**：解析 GIF 头、逻辑屏幕描述符及所有数据块
* 🎬 **动画支持**：处理帧延迟、处置方式等动画信息
* 🔍 **LZW 解压**：实现 GIF 所需的 LZW 解码流程
* 🌊 **流式解码器**：`StreamingGifDecoder` 支持按数据块解析超大 GIF
* 🧮 **GIF 优化工具**：`gif_optimizer.mbt` 删除重复帧、裁剪调色板并校验透明度
* 🧑‍🎨 **高级透明度策略**：`TransparencyOptions` 允许配置阈值、背景保护等
* 🧰 **GIF 编码器**：`gif_encoder.mbt` 可将 RGBA 帧重新编码为 GIF
* 🌐 **WebAssembly 绑定**：`wasm_bindings.mbt` 暴露易于接入的 wasm API
* 🧪 **完善测试**：黑盒/白盒测试与快照测试覆盖核心逻辑
* 📈 **性能分析**：在 CLI 演示模式下包含性能基准输出

## 🚀 快速开始

### 前置要求
```bash
# 安装 MoonBit（若尚未安装）
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash

# 安装项目依赖
moon add moonbitlang/x@0.4.34
```

### 基本用法
```bash
# 解析 GIF（默认命令）
moon run src/main analyze gif/__Attack.gif

# 以流式方式解析大文件
moon run src/main stream gif/__Attack.gif 4096

# 打印优化报告（重复帧 / 透明度修复 / 调色板规范化）
moon run src/main optimize gif/__Attack.gif

# 生成示例 GIF 并保存（默认输出 encoded_demo.gif）
moon run src/main encode-demo out/demo.gif

# 使用自定义 ParseOptions 输出摘要（strict 可为 true/false）
moon run src/main summary gif/__Attack.gif false

# 仍可直接传入路径，自动执行 analyze
moon run src/main gif/__Attack.gif
```

### 示例输出
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

## 📚 API 参考

### 核心函数

```moonbit
// 基础解析
decode_gif_basic(data: Bytes) -> Result[String, String]
decode_gif_complete(data: Bytes) -> Result[String, String]

// 详细解析
parse_gif_info(data: Bytes) -> Result[GifInfo, String] 
parse_image_descriptor(data: Bytes, offset: Int) -> Result[(ImageDesc, Int), String]

// LZW 解压
decode_lzw(data: @list.List[Byte], min_code_size: Int) -> Result[@list.List[Byte], GifError]

// 编码与优化
GifEncoder::new(options: GifEncoderOptions) -> GifEncoder
GifEncoder::add_frame(frame: GifFrameInput) -> Result[Unit, GifError]
GifEncoder::build() -> Result[Bytes, GifError]
create_frame_from_rgba(width: Int, height: Int, left: Int, top: Int, pixels: Array[RgbaColor], delay: Int, disposal: Int) -> Result[GifFrameInput, GifError]
optimize_gif(gif: Gif, options: GifOptimizationOptions) -> (Gif, OptimizationReport)

// 流式解码
StreamingGifDecoder::new(options: StreamingDecoderOptions) -> StreamingGifDecoder
StreamingGifDecoder::process_chunk(chunk: Bytes) -> Result[@list.List[StreamingEvent], GifError]

// WebAssembly 辅助函数
wasm_decode_gif_summary(data: Bytes) -> Result[String, String]
wasm_stream_decode(data: Bytes, chunk_size: Int) -> Result[Int, String]
wasm_encode_single_frame(pixels: Array[RgbaColor], width: Int, height: Int) -> Result[Bytes, String]
```

### 数据结构

```moonbit
// 基础结构
struct GifHeader { version: String }
struct LogicalScreenDescriptor { ... }
struct ImageDescriptor { ... }
struct ColorTableEntry { red: Int, green: Int, blue: Int }

// 高级类型
struct GraphicControlExtension { ... }
struct ImageFrame { width: Int, height: Int, pixels: Array[RgbaColor] }
enum DisposalMethod { None, DoNotDispose, RestoreToBackground, RestoreToPrevious }
```

## 🧑‍🏭 GIF 优化与编码

- **Optimizer (`gif_optimizer.mbt`)**：调用 `optimize_gif` 并传入 `GifOptimizationOptions`，可移除重复帧、收缩局部调色板并自动设置透明度，返回的 `OptimizationReport` 会列出具体统计。
- **Encoder (`gif_encoder.mbt`)**：可通过 `create_frame_from_rgba` 或直接输入索引数据，借助 `GifEncoder` 重新打包成 GIF；与优化器可实现“解析 → 优化 → 重新编码”的完整流程。
- **命令行实践**：`moon run src/main encode-demo` 会输出示例 GIF 字节；`moon run src/main optimize your.gif` 可查看优化报告。

## 🌊 流式处理与透明度

- **Streaming decoder**：`StreamingGifDecoder::process_chunk` 支持按块输入，返回 `StreamingEvent`（Header、Image、Extension、Trailer…），用于大文件或网络流场景。
- **TransparencyOptions**：可配置二值透明、阈值透明或保持亮度的策略，并支持保护背景色。`render_all_frames_with_options` / `render_frame_to_canvas_with_options` 可应用自定义策略。
- **CLI**：`moon run src/main stream your.gif 4096` 会实时输出解析过程；`moon run src/main summary your.gif true` 使用 `GifParseOptions` 打印数据块摘要。

## 🕸️ WebAssembly

- `wasm_bindings.mbt` 暴露 `wasm_decode_gif_summary`、`wasm_stream_decode`、`wasm_encode_single_frame` 等函数，参数均为 `Bytes` 或基础类型，方便 JS/wasmtime 使用。
- 构建命令：
  ```bash
  moon build src/lib -target wasm-gc -entry wasm_bindings
  ```
- 生成的模块会自动导出上述绑定函数，可直接被 Web/wasmtime 等运行时加载。

## 🧪 测试

```bash
# 运行全部测试
moon test

# 如果改动影响快照
moon test --update

# 覆盖率
moon coverage analyze > uncovered.log

# 格式化与检查
moon fmt && moon check
```

### 测试结构

- **[src/tests/](src/tests/)** —— 黑盒测试
  - `gif_decoder_tests.mbt`：解码核心测试
  - `bit_reader_tests.mbt`：位读取工具
  - `lzw_decoder_test.mbt`：LZW 算法
- **White-box**：文件名以 `_wbtest.mbt` 结尾，覆盖内部实现

## 🏗️ 项目结构

```
src/
├── lib/                          # 核心库
│   ├── gif_decoder.mbt          # GIF 解码主逻辑
│   ├── gif_types.mbt            # 类型定义
│   ├── lzw_decoder.mbt          # LZW 解压
│   ├── bit_reader.mbt           # 位级读取
│   ├── byte_utils.mbt           # 字节工具
│   └── image_renderer.mbt       # 帧渲染与透明度
├── main/                        # CLI
│   └── main.mbt
└── tests/                       # 测试
    └── ...
```

## 🔧 开发指南

### 代码风格
- 使用 `///|` 分隔 block
- `moon fmt` 自动格式化
- 改动后运行 `moon info` 同步接口
- 废弃代码放入 `deprecated.mbt`

### 工作流程
```bash
# 1. 修改代码
# 2. 更新接口 / 格式化
moon info && moon fmt

# 3. 跑测试
moon test

# 4. 静态检查
moon check

# 5. 若行为变化，更新快照
moon test --update
```

## 📈 性能

CLI 演示模式包含性能基准：
```bash
moon run src/main

# 输出里搜 “⚡ 6. 性能基准测试”
```

典型性能：
- **小文件** (< 1KB)：毫秒级
- **中等文件** (1–100KB)：< 10ms
- **大文件** (> 100KB)：随大小线性增长

## 🐛 常见问题

1. **“Invalid signature”** —— 确认文件以 “GIF87a” 或 “GIF89a” 开头  
2. **“LZW decompression failed”** —— 文件损坏或使用了不支持的 LZW 变种  
3. **“Image too large”** —— 在 [`gif_types.mbt`](src/lib/gif_types.mbt) 中放宽尺寸限制  

调试时可参考 `main.mbt` 中演示函数的 verbose 输出。

## 🛣️ 路线图

- [x] GIF 头解析
- [x] LZW 解压
- [x] 颜色表支持
- [x] 动画帧处理
- [x] 扩展块解析
- [x] 完整测试覆盖
- [x] **WebAssembly 目标**
- [x] **高级透明度**
- [x] **GIF 优化工具**
- [x] **大文件流式解码**
- [x] **GIF 创建/编码**
