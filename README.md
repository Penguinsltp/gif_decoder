# GIF Decoder (MoonBit)
A lightweight GIF decoder implemented in [MoonBit](https://www.moonbitlang.com/)。

---
## Features

* 🖼️ Parse GIF headers and data blocks

* 🔍 Support basic decoding of GIF image data

* ⚡ Provide bitstream reading and byte utilities

* 🧪 Built-in unit tests for reliability

---

## Usage
### Install Dependency
Before running, install the required dependency:
```bash
moon add moonbitlang/x@0.4.34
```
### Run
```bash
moon run src/main <gif_file_path>
```
### Example
```bash
moon run src/main gif/__Attack.gif

moon run src/main /path/to/your/image.gif
```
### Example Output
```

GIF Decoder - Usage Guide

==================================================

GIF file successfully parsed:

Width: 256, Height: 256

Frames: 10

Loop Count: Infinite

```
---
## Tests
Run unit tests:
```bash
moon test
```
---
## Roadmap

* [ ] Add full GIF animation rendering

* [ ] Implement palette and transparency support

* [ ] Add more test cases

<<<<<<< HEAD
* [ ] Provide WebAssembly (WASM) build
=======
* [ ] Provide WebAssembly (WASM) build
>>>>>>> 58dedb08d10c0e064376c4287101f6d89d42d7bf
