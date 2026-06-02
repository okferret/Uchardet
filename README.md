# Uchardet

[uchardet](https://www.freedesktop.org/wiki/Software/uchardet/) 是一个编码检测库，能够对未知字符编码的字节序列进行分析，并尝试确定其文本编码。返回的编码名称与 [iconv](https://www.gnu.org/software/libiconv/) 兼容。

uchardet 最初是 Mozilla 通用字符集检测库的 C 语言绑定，现已能够比原始实现检测更多字符集，且准确率更高。

本仓库提供了对 uchardet C 库的 Swift 封装（`Uchardet`），以预构建 XCFramework 二进制目标的形式通过 Swift Package Manager 分发。

## 要求

- Swift 5.9+
- Xcode 15+
- macOS 10.15+ / iOS 13+ / tvOS 13+ / watchOS 6+ / visionOS 1+

> **注意：** 从命令行构建时，请使用 `xcrun swift build` 而非 `swift build`，以确保使用 Xcode 工具链并与 SDK 版本匹配。

## 安装

### Xcode

通过 **File → Add Package Dependencies…** 添加包，并输入仓库 URL。

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/okferret/Uchardet.git", from: "1.0.0"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["Uchardet"]
    ),
]
```

## 构建

```bash
# 使用 xcrun 确保选择 Xcode 工具链
xcrun swift build

# 运行测试
xcrun swift test
```

## 使用

### 快速检测

```swift
import Uchardet

// 检测 Data 的编码
let data: Data = ...
let result = try Uchardet.detect(data)
print(result.charset)   // e.g. "UTF-8"、"GB18030"、"SHIFT-JIS"
print(result.encoding)  // String.Encoding

// 检测字节数组的编码
let bytes: [UInt8] = ...
let result = try Uchardet.detect(bytes: bytes)

// 流式检测文件（大文件友好，仅采样头部）
let result = try Uchardet.detect(fileURL)
```

### 检测并解码

```swift
import Uchardet

let data = try Data(contentsOf: someURL)
let result = try Uchardet.detect(data)

// 使用检测到的编码解码
if let text = result.decode(data) {
    print(text)
}

// 使用回退编码
let text = result.decode(data, fallbackEncoding: .utf8)
```

### 流式检测（手动控制）

```swift
import Uchardet

let detector = Uchardet()

// 分块喂入数据（支持链式调用）
detector.feed(chunk1).feed(chunk2)

// 结束输入并获取结果
let result = try detector.finalize()
print(result.charset)

// 重置并复用实例
detector.reset()
detector.feed(newData)
let result2 = try detector.finalize()
```

### 文件检测（自定义采样参数）

```swift
import Uchardet

// 默认采样前 64 KB，每次读取 4 KB
let result = try Uchardet.detect(fileURL)

// 自定义采样大小和块大小
let result = try Uchardet.detect(fileURL, sampleSize: 32_768, chunkSize: 8_192)
```

### 从 charset 名称初始化编码

```swift
import Uchardet

// 从 iconv 兼容的 charset 名称初始化（大小写不敏感）
let encoding = String.Encoding(charsetName: "GB18030")
let encoding = String.Encoding(charsetName: "shift-jis")
let encoding = String.Encoding(charsetName: "windows-1251")
```

## API 参考

### `UchardetError`

| 错误 | 说明 |
|---|---|
| `insufficientData` | 数据为空或数据量不足，无法完成字符集检测 |
| `unrecognizedEncoding` | uchardet 无法识别数据的字符集（置信度低于阈值） |
| `unsupportedEncoding(String)` | 检测到字符集名称，但当前平台不支持该编码 |

### `DetectionResult`

| 属性 / 方法 | 说明 |
|---|---|
| `charset: String` | uchardet 返回的原始字符集名称（iconv 兼容格式，如 `"UTF-8"`、`"GB18030"`） |
| `encoding: String.Encoding` | 对应的 `String.Encoding` |
| `description: String` | 可读描述，如 `"UTF-8 (6)"` |
| `decode(_ data: Data) -> String?` | 使用检测到的编码将原始字节解码为字符串 |
| `decode(_ data: Data, fallbackEncoding:) -> String?` | 解码失败时使用回退编码 |

### `Uchardet`

| 方法 | 说明 |
|---|---|
| `init()` | 创建新的检测器实例 |
| `feed(_ data: Data) -> Self` | 喂入数据块（可链式调用） |
| `feed(_ bytes: [UInt8]) -> Self` | 喂入字节数组（可链式调用） |
| `finalize() throws -> DetectionResult` | 结束输入并返回检测结果 |
| `reset()` | 重置检测器以复用实例 |
| `static detect(_ data: Data) throws -> DetectionResult` | 一次性检测 `Data` |
| `static detect(bytes: [UInt8]) throws -> DetectionResult` | 一次性检测字节数组 |
| `static detect(_ url: URL, sampleSize:, chunkSize:) throws -> DetectionResult` | 流式文件检测 |

### `String.Encoding` 扩展

| 方法 | 说明 |
|---|---|
| `init?(charsetName: String)` | 从 iconv 兼容的 charset 名称初始化（大小写不敏感），无法映射时返回 `nil` |

## 错误处理

所有检测方法均通过 Swift 的 `throws` 机制报告错误：

```swift
do {
    let result = try Uchardet.detect(data)
    print(result.charset)
} catch UchardetError.unrecognizedEncoding {
    print("无法识别编码")
} catch UchardetError.unsupportedEncoding(let charset) {
    print("不支持的编码：\(charset)")
} catch {
    print("其他错误：\(error)")
}
```

## 线程安全性

`Uchardet` 实例本身**非线程安全**。若需并发检测，请为每个任务创建独立实例。静态便捷方法（`Uchardet.detect(...)`）内部各自创建独立实例，可安全并发调用。

---

## 支持的语言 / 编码

- **国际（Unicode）**
  - UTF-8
  - UTF-16BE / UTF-16LE
  - UTF-32BE / UTF-32LE / X-ISO-10646-UCS-4-34121 / X-ISO-10646-UCS-4-21431
- **阿拉伯语**：ISO-8859-6、WINDOWS-1256
- **保加利亚语**：ISO-8859-5、WINDOWS-1251
- **中文**：ISO-2022-CN、BIG5、EUC-TW、GB18030、HZ-GB-2312
- **克罗地亚语**：ISO-8859-2、ISO-8859-13、ISO-8859-16、Windows-1250、IBM852、MAC-CENTRALEUROPE
- **捷克语**：Windows-1250、ISO-8859-2、IBM852、MAC-CENTRALEUROPE
- **丹麦语**：IBM865、ISO-8859-1、ISO-8859-15、WINDOWS-1252
- **英语**：ASCII
- **世界语**：ISO-8859-3
- **爱沙尼亚语**：ISO-8859-4、ISO-8859-13、Windows-1252、Windows-1257
- **芬兰语**：ISO-8859-1、ISO-8859-4、ISO-8859-9、ISO-8859-13、ISO-8859-15、WINDOWS-1252
- **法语**：ISO-8859-1、ISO-8859-15、WINDOWS-1252
- **德语**：ISO-8859-1、WINDOWS-1252
- **希腊语**：ISO-8859-7、WINDOWS-1253
- **希伯来语**：ISO-8859-8、WINDOWS-1255
- **匈牙利语**：ISO-8859-2、WINDOWS-1250
- **爱尔兰盖尔语**：ISO-8859-1、ISO-8859-9、ISO-8859-15、WINDOWS-1252
- **意大利语**：ISO-8859-1、ISO-8859-3、ISO-8859-9、ISO-8859-15、WINDOWS-1252
- **日语**：ISO-2022-JP、SHIFT_JIS、EUC-JP
- **韩语**：ISO-2022-KR、EUC-KR / UHC
- **立陶宛语**：ISO-8859-4、ISO-8859-10、ISO-8859-13
- **拉脱维亚语**：ISO-8859-4、ISO-8859-10、ISO-8859-13
- **马耳他语**：ISO-8859-3
- **挪威语**：IBM865、ISO-8859-1、ISO-8859-15、WINDOWS-1252
- **波兰语**：ISO-8859-2、ISO-8859-13、ISO-8859-16、Windows-1250、IBM852、MAC-CENTRALEUROPE
- **葡萄牙语**：ISO-8859-1、ISO-8859-9、ISO-8859-15、WINDOWS-1252
- **罗马尼亚语**：ISO-8859-2、ISO-8859-16、Windows-1250、IBM852
- **俄语**：ISO-8859-5、KOI8-R、WINDOWS-1251、MAC-CYRILLIC、IBM866、IBM855
- **斯洛伐克语**：Windows-1250、ISO-8859-2、IBM852、MAC-CENTRALEUROPE
- **斯洛文尼亚语**：ISO-8859-2、ISO-8859-16、Windows-1250、IBM852、MAC-CENTRALEUROPE
- **西班牙语**：ISO-8859-1、ISO-8859-15、WINDOWS-1252
- **瑞典语**：ISO-8859-1、ISO-8859-4、ISO-8859-9、ISO-8859-15、WINDOWS-1252
- **泰语**：TIS-620、ISO-8859-11
- **土耳其语**：ISO-8859-3、ISO-8859-9
- **越南语**：VISCII、Windows-1258
- **其他**：WINDOWS-1252

---

## 关于 uchardet

### 历史

uchardet 最初是 Mozilla 的项目，用于更好地检测页面编码，曾是 Firefox 的一部分。2011 年，BYVoid 将 Mozilla 代码提取并打包为独立库 `uchardet`。2015 年起，Jehan 开始贡献代码，将输出标准化为 iconv 兼容格式，并增加了更多编码/语言支持。2016 年，`uchardet` 成为 freedesktop 项目。

检测技术详见：https://www-archive.mozilla.org/projects/intl/universalcharsetdetection

### 相关项目

- [R-uchardet](https://cran.r-project.org/package=uchardet) — R 绑定
- [python-chardet](https://github.com/chardet/chardet) — Python 移植
- [ruby-rchardet](http://rubyforge.org/projects/chardet/) — Ruby 移植
- [juniversalchardet](http://code.google.com/p/juniversalchardet/) — Java 移植
- [rust-uchardet](https://github.com/emk/rust-uchardet) — Rust 绑定
- [libchardet](https://github.com/Joungkyun/libchardet) — 另一个 C/C++ 封装

### 使用者

- [mpv](https://mpv.io/) — 字幕编码检测
- [Tepl](https://wiki.gnome.org/Projects/Tepl)
- [Nextcloud iOS app](https://github.com/nextcloud/ios)
- [Codelite](https://codelite.org)
- [QtAV](https://www.qtav.org/)

## 许可证

- [Mozilla Public License Version 1.1](http://www.mozilla.org/MPL/1.1/)
- [GNU General Public License, version 2.0](http://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html) or later
- [GNU Lesser General Public License, version 2.1](http://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html) or later

完整许可证文本见 `LICENSE` 文件。
