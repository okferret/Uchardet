# uchardet

[uchardet](https://www.freedesktop.org/wiki/Software/uchardet/) 是一个字符编码检测库，能够对未知编码的字节序列进行分析，并自动推断其字符集。返回的编码名称与 [iconv](https://www.gnu.org/software/libiconv/) 兼容。

uchardet 最初是 Mozilla 通用字符集检测库（universalchardet）的 C 语言绑定，现已支持比原始实现更多的字符集，检测准确率也更高。

本仓库将 uchardet C 库封装为 XCFramework，并提供一套符合 Swift 惯用风格的 API，支持在 Apple 全平台（macOS、iOS、tvOS、watchOS、visionOS）上进行字符编码检测。

## 支持的语言 / 编码

  * 国际通用（Unicode）
    * UTF-8
    * UTF-16BE / UTF-16LE
    * UTF-32BE / UTF-32LE / X-ISO-10646-UCS-4-34121 / X-ISO-10646-UCS-4-21431
  * 阿拉伯语
    * ISO-8859-6
    * WINDOWS-1256
  * 保加利亚语
    * ISO-8859-5
    * WINDOWS-1251
  * 中文
    * ISO-2022-CN
    * BIG5
    * EUC-TW
    * GB18030
    * HZ-GB-2312
  * 克罗地亚语
    * ISO-8859-2
    * ISO-8859-13
    * ISO-8859-16
    * Windows-1250
    * IBM852
    * MAC-CENTRALEUROPE
  * 捷克语
    * Windows-1250
    * ISO-8859-2
    * IBM852
    * MAC-CENTRALEUROPE
  * 丹麦语
    * IBM865
    * ISO-8859-1
    * ISO-8859-15
    * WINDOWS-1252
  * 英语
    * ASCII
  * 世界语（Esperanto）
    * ISO-8859-3
  * 爱沙尼亚语
    * ISO-8859-4
    * ISO-8859-13
    * Windows-1252
    * Windows-1257
  * 芬兰语
    * ISO-8859-1
    * ISO-8859-4
    * ISO-8859-9
    * ISO-8859-13
    * ISO-8859-15
    * WINDOWS-1252
  * 法语
    * ISO-8859-1
    * ISO-8859-15
    * WINDOWS-1252
  * 德语
    * ISO-8859-1
    * WINDOWS-1252
  * 希腊语
    * ISO-8859-7
    * WINDOWS-1253
  * 希伯来语
    * ISO-8859-8
    * WINDOWS-1255
  * 匈牙利语
    * ISO-8859-2
    * WINDOWS-1250
  * 爱尔兰盖尔语
    * ISO-8859-1
    * ISO-8859-9
    * ISO-8859-15
    * WINDOWS-1252
  * 意大利语
    * ISO-8859-1
    * ISO-8859-3
    * ISO-8859-9
    * ISO-8859-15
    * WINDOWS-1252
  * 日语
    * ISO-2022-JP
    * SHIFT_JIS
    * EUC-JP
  * 韩语
    * ISO-2022-KR
    * EUC-KR / UHC
  * 立陶宛语
    * ISO-8859-4
    * ISO-8859-10
    * ISO-8859-13
  * 拉脱维亚语
    * ISO-8859-4
    * ISO-8859-10
    * ISO-8859-13
  * 马耳他语
    * ISO-8859-3
  * 挪威语
    * IBM865
    * ISO-8859-1
    * ISO-8859-15
    * WINDOWS-1252
  * 波兰语
    * ISO-8859-2
    * ISO-8859-13
    * ISO-8859-16
    * Windows-1250
    * IBM852
    * MAC-CENTRALEUROPE
  * 葡萄牙语
    * ISO-8859-1
    * ISO-8859-9
    * ISO-8859-15
    * WINDOWS-1252
  * 罗马尼亚语
    * ISO-8859-2
    * ISO-8859-16
    * Windows-1250
    * IBM852
  * 俄语
    * ISO-8859-5
    * KOI8-R
    * WINDOWS-1251
    * MAC-CYRILLIC
    * IBM866
    * IBM855
  * 斯洛伐克语
    * Windows-1250
    * ISO-8859-2
    * IBM852
    * MAC-CENTRALEUROPE
  * 斯洛文尼亚语
    * ISO-8859-2
    * ISO-8859-16
    * Windows-1250
    * IBM852
    * MAC-CENTRALEUROPE
  * 西班牙语
    * ISO-8859-1
    * ISO-8859-15
    * WINDOWS-1252
  * 瑞典语
    * ISO-8859-1
    * ISO-8859-4
    * ISO-8859-9
    * ISO-8859-15
    * WINDOWS-1252
  * 泰语
    * TIS-620
    * ISO-8859-11
  * 土耳其语
    * ISO-8859-3
    * ISO-8859-9
  * 越南语
    * VISCII
    * Windows-1258
  * 其他
    * WINDOWS-1252

## Swift Package

### 系统要求

| 平台       | 最低版本 |
|------------|---------|
| macOS      | 10.15+  |
| iOS        | 13.0+   |
| tvOS       | 13.0+   |
| watchOS    | 6.0+    |
| visionOS   | 1.0+    |

### 通过 Swift Package Manager 集成

在 `Package.swift` 中添加依赖：

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/your-org/uchardet.git", from: "1.0.0"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "Uchardet", package: "uchardet"),
        ]
    ),
]
```

也可以通过 Xcode 添加：**File → Add Package Dependencies…**，粘贴仓库地址并选择版本即可。

---

## Swift 使用教程

### 导入模块

```swift
import Uchardet
```

### 1. 从 `Data` 一次性检测

```swift
import Foundation
import Uchardet

let bytes: [UInt8] = [0xE4, 0xB8, 0xAD, 0xE6, 0x96, 0x87]  // "中文" 的 UTF-8 字节
let data = Data(bytes)

// 检测字符集名称（iconv 兼容格式）
if let charset = Uchardet.detect(data) {
    print("检测到的字符集：", charset)  // "UTF-8"
}

// 检测为 String.Encoding
if let encoding = Uchardet.detectEncoding(data) {
    print("检测到的编码：", encoding)  // String.Encoding.utf8
    let text = String(data: data, encoding: encoding)
    print("解码文本：", text ?? "")
}
```

### 2. 从 `String` 一次性检测

```swift
import Uchardet

let sample = "Héllo wörld"

if let charset = Uchardet.detect(sample) {
    print("字符集：", charset)
}

if let encoding = Uchardet.detectEncoding(sample) {
    print("编码：", encoding)
}
```

### 3. 大文件流式检测（节省内存）

对于大文件，推荐使用流式 API，仅采样文件头部数据，避免将整个文件加载到内存：

```swift
import Foundation
import Uchardet

let fileURL = URL(fileURLWithPath: "/path/to/file.txt")

do {
    // 检测字符集名称
    if let charset = try Uchardet.detect(contentsOf: fileURL) {
        print("文件字符集：", charset)
    }

    // 检测为 String.Encoding，并用检测到的编码读取文件内容
    if let encoding = try Uchardet.detectEncoding(contentsOf: fileURL) {
        print("文件编码：", encoding)
        let text = try String(contentsOf: fileURL, encoding: encoding)
        print("文件内容：", text)
    }
} catch {
    print("错误：", error)
}
```

可以自定义采样参数：

```swift
// 最多采样 128 KB，每次读取 8 KB
let charset = try Uchardet.detect(
    contentsOf: fileURL,
    sampleSize: 131_072,
    chunkSize: 8_192
)
```

### 4. 从 `[UInt8]` 字节数组检测

```swift
import Uchardet

let bytes: [UInt8] = [0xE4, 0xB8, 0xAD, 0xE6, 0x96, 0x87]  // "中文" 的 UTF-8 字节

// 检测字符集名称
if let charset = Uchardet.detect(bytes: bytes) {
    print("字符集：", charset)  // "UTF-8"
}

// 检测为 String.Encoding
if let encoding = Uchardet.detectEncoding(bytes: bytes) {
    print("编码：", encoding)
}
```

### 5. 增量（手动）检测

当需要精细控制数据喂入时（例如处理网络数据流），可直接使用 `Uchardet` 类：

```swift
import Uchardet

let detector = Uchardet()

// 逐块喂入数据
for chunk in receivedChunks {
    let ok = detector.handleData(chunk)
    if !ok {
        // 底层 C API 报告错误，停止继续喂入
        break
    }
}

// 通知检测器数据已结束
detector.dataEnd()

// 读取检测结果
if let charset = detector.charset {
    print("字符集：", charset)
}
if let encoding = detector.encoding {
    print("编码：", encoding)
}

// 重置以复用检测器
detector.reset()
```

### 6. 将字符集名称转换为 `String.Encoding`

`String.Encoding` 扩展可独立使用，无需经过检测流程：

```swift
import Uchardet

// 通过 iconv 兼容的字符集名称初始化
if let encoding = String.Encoding(charsetName: "WINDOWS-1252") {
    print(encoding)  // 对应 Windows-1252 的 String.Encoding
}

if let encoding = String.Encoding(charsetName: "EUC-JP") {
    let text = String(data: jpData, encoding: encoding)
}
```

---

## 安装（C 库 / 命令行工具）

### Debian / Ubuntu / Mint

    apt-get install uchardet libuchardet-dev

### Mageia

    urpmi libuchardet libuchardet-devel

### Fedora

    dnf install uchardet uchardet-devel

### Gentoo

    emerge uchardet

### macOS

    brew install uchardet

  或

    port install uchardet

### Windows

Fedora 和 Msys2 仓库提供了预编译的二进制包。此外，该库在 Windows 下也非常容易编译，可使用 [CMake Windows 安装包](https://cmake.org/download/) 配合 MinGW 或 MinGW-w64 进行构建（支持 32 位和 64 位 DLL）。

该库也支持交叉编译（例如在 GNU/Linux 机器上为 Windows 构建，可借助 [crossroad](https://pypi.org/project/crossroad/)）。

### 从源码构建

发布版本下载地址：
https://www.freedesktop.org/software/uchardet/releases/

如需开发版本，克隆 Git 仓库：

    git clone https://gitlab.freedesktop.org/uchardet/uchardet.git

源码浏览：https://gitlab.freedesktop.org/uchardet/uchardet

    cmake .
    make
    make install

### 通过 flatpak-builder 构建

在 Flatpak JSON 清单中添加如下 `modules` 片段：

```json
"modules": [
    {
        "name": "uchardet",
        "buildsystem": "cmake",
        "builddir": true,
        "config-opts": [ "-DCMAKE_INSTALL_LIBDIR=lib" ],
        "sources": [
            {
                ...
            }
        ]
    }
]
```

### 通过 CMake 导出目标使用

uchardet 安装了标准的 pkg-config 文件，可被任何现代构建系统发现。如果你的项目也使用 CMake，可以通过导出目标来查找并链接 uchardet：

```cmake
project(sample LANGUAGES C)
find_package(uchardet)
if(uchardet_FOUND)
  add_executable(sample sample.c)
  target_link_libraries(sample PRIVATE uchardet::libuchardet)
endif()
```

> 推荐优先使用 `pkg-config` 方式发现库，因为它是通用标准，即使构建系统发生变化也能正常工作。

## 命令行用法

```
uchardet Command Line Tool
Version 0.0.8

Authors: BYVoid, Jehan
Bug Report: https://gitlab.freedesktop.org/uchardet/uchardet/-/issues

Usage:
 uchardet [Options] [File]...

Options:
 -v, --version         打印版本和构建信息
 -h, --help            打印帮助信息
```

## C 库用法

参见 [uchardet.h](https://gitlab.freedesktop.org/uchardet/uchardet/-/blob/master/src/uchardet.h)

## 历史

如简介所述，uchardet 最初是 Mozilla 的项目，用于改善网页编码检测，曾是 Firefox 的一部分。如今大多数网站已明确声明编码，UTF-8 也已广泛普及，该功能已从 Firefox 中移除。

universalchardet 所使用的技术描述见：https://www-archive.mozilla.org/projects/intl/universalcharsetdetection

虽然代码已经历了大量变化，但核心思路依然保留——检测不仅依赖编码规则，更重要的是基于语言字符统计分析。

Mozilla 的原始代码已难以找到，但应与本仓库的初始提交相差不远。

2011 年，BYVoid 将 Mozilla 代码提取并打包为独立库 `uchardet`，托管于个人仓库。2015 年起，Jehan 开始参与贡献，将输出标准化为 iconv 兼容格式，增加了多种编码/语言支持，并通过 Python 脚本利用维基百科文本作为语言统计来源，简化了新编码/语言支持的生成流程，随后成为共同维护者。2016 年，`uchardet` 成为 freedesktop 项目。

## 相关项目

以下项目部分为 `uchardet` 的绑定，部分为同一初始代码的分支，部分为其他语言的原生移植。此列表不完整，仅供参考，我们不跟踪这些项目的状态。

  * [R-uchardet](https://cran.r-project.org/package=uchardet) — CRAN 上的 R 语言绑定
  * [python-chardet](https://github.com/chardet/chardet) — Python 移植版
  * [ruby-rchardet](http://rubyforge.org/projects/chardet/) — Ruby 移植版
  * [juniversalchardet](http://code.google.com/p/juniversalchardet/) — universalchardet 的 Java 移植版
  * [jchardet](http://jchardet.sourceforge.net/) — chardet 的 Java 移植版
  * [nuniversalchardet](http://code.google.com/p/nuniversalchardet/) — universalchardet 的 C# 移植版
  * [nchardet](http://www.conceptdevelopment.net/Localization/NCharDet/) — chardet 的 C# 移植版
  * [uchardet-enhanced](https://bitbucket.org/medoc/uchardet-enhanced) — mozilla universalchardet 的分支
  * [rust-uchardet](https://github.com/emk/rust-uchardet) — uchardet 的 Rust 语言绑定
  * [libchardet](https://github.com/Joungkyun/libchardet) — 另一个封装 Mozilla 代码的 C/C++ API

## 使用者

* [mpv](https://mpv.io/) — 用于字幕编码检测
* [Tepl](https://wiki.gnome.org/Projects/Tepl)
* [Nextcloud iOS app](https://github.com/nextcloud/ios)
* [Codelite](https://codelite.org)
* [QtAV](https://www.qtav.org/)
* …

## 许可证

* [Mozilla Public License Version 1.1](http://www.mozilla.org/MPL/1.1/)
* [GNU General Public License, version 2.0](http://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html) 或更高版本
* [GNU Lesser General Public License, version 2.1](http://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html) 或更高版本

完整许可证文本见 `COPYING` 文件。

## 行为准则

`uchardet` 项目由 [freedesktop.org](https://www.freedesktop.org/) 托管，遵循其行为准则，即以尊重的态度对待所有人，并期望所有人同样如此。

请阅读 [freedesktop.org 行为准则](https://www.freedesktop.org/wiki/CodeOfConduct)。

如在 uchardet 项目中遇到任何不当行为问题，请联系维护者（Jehan）或提交 Bug 报告（如有需要可设为私密）。
