import Foundation
import uchardet

// MARK: - CFStringEncoding 常量（避免依赖 CFStringBuiltInEncodings）

// 以下常量来自 CFString.h，直接使用原始值以兼容 Swift Package Manager
private enum CFEnc {
    // Latin
    static let isoLatin3:        CFStringEncoding = 0x0203  // ISO-8859-3 (Latin-3)
    static let isoLatin4:        CFStringEncoding = 0x0204  // ISO-8859-4 (Latin-4)
    static let isoLatinCyrillic: CFStringEncoding = 0x0205  // ISO-8859-5
    static let isoLatinArabic:   CFStringEncoding = 0x0206  // ISO-8859-6
    static let isoLatinGreek:    CFStringEncoding = 0x0207  // ISO-8859-7
    static let isoLatinHebrew:   CFStringEncoding = 0x0208  // ISO-8859-8
    static let isoLatin5:        CFStringEncoding = 0x0209  // ISO-8859-9 (Latin-5, Turkish)
    static let isoLatin6:        CFStringEncoding = 0x020A  // ISO-8859-10 (Latin-6)
    static let isoLatinThai:     CFStringEncoding = 0x041D  // TIS-620 / ISO-8859-11
    static let isoLatin7:        CFStringEncoding = 0x020D  // ISO-8859-13 (Latin-7)
    static let isoLatin9:        CFStringEncoding = 0x020F  // ISO-8859-15 (Latin-9)
    static let isoLatin10:       CFStringEncoding = 0x0210  // ISO-8859-16 (Latin-10)
    // Mac
    static let macCyrillic:        CFStringEncoding = 0x0007
    static let macCentralEurRoman: CFStringEncoding = 0x001D
    // Windows
    static let windowsLatin1:     CFStringEncoding = 0x0500  // Windows-1252
    static let windowsLatin2:     CFStringEncoding = 0x0501  // Windows-1250
    static let windowsCyrillic:   CFStringEncoding = 0x0502  // Windows-1251
    static let windowsGreek:      CFStringEncoding = 0x0503  // Windows-1253
    static let windowsLatin5:     CFStringEncoding = 0x0504  // Windows-1254 (Turkish)
    static let windowsHebrew:     CFStringEncoding = 0x0505  // Windows-1255
    static let windowsArabic:     CFStringEncoding = 0x0506  // Windows-1256
    static let windowsBalticRim:  CFStringEncoding = 0x0507  // Windows-1257
    static let windowsVietnamese: CFStringEncoding = 0x0508  // Windows-1258
    // DOS / IBM
    static let dosLatin2:   CFStringEncoding = 0x0412  // IBM852
    static let dosCyrillic: CFStringEncoding = 0x0413  // IBM855
    static let dosRussian:  CFStringEncoding = 0x041B  // IBM866
    static let dosNordic:   CFStringEncoding = 0x041A  // IBM865
    // CJK
    static let big5:    CFStringEncoding = 0x0A03
    static let gb2312:  CFStringEncoding = 0x0930
    static let gbk:     CFStringEncoding = 0x0631
    static let gb18030: CFStringEncoding = 0x0632
    static let eucTW:   CFStringEncoding = 0x0931
    static let eucKR:   CFStringEncoding = 0x0940
    // ISO-2022
    static let iso2022JP: CFStringEncoding = 0x0820
    static let iso2022KR: CFStringEncoding = 0x0840
    static let iso2022CN: CFStringEncoding = 0x0830
    // KOI8 / VISCII
    static let koi8R:  CFStringEncoding = 0x0A02
    static let koi8U:  CFStringEncoding = 0x0A08
    static let viscii: CFStringEncoding = 0x0A07
}

// MARK: - UchardetError

/// uchardet 检测过程中可能抛出的错误
public enum UchardetError: Error, CustomStringConvertible, LocalizedError {

    /// 数据为空或数据量不足，无法完成字符集检测
    case insufficientData

    /// uchardet 无法识别数据的字符集（置信度低于阈值）
    case unrecognizedEncoding

    /// uchardet 检测到字符集名称，但当前平台不支持该编码
    case unsupportedEncoding(String)

    public var description: String {
        switch self {
        case .insufficientData:
            return "数据为空或数据量不足，无法完成字符集检测"
        case .unrecognizedEncoding:
            return "无法识别数据的字符集（置信度低于阈值）"
        case .unsupportedEncoding(let charset):
            return "当前平台不支持该编码：\(charset)"
        }
    }
    
    public var errorDescription: String? {
        return description
    }
    
    public var failureReason: String? {
        return description
    }
}

// MARK: - DetectionResult

/// 字符集检测结果，同时携带原始名称与 `String.Encoding`
public struct DetectionResult: Equatable, CustomStringConvertible {

    /// uchardet 返回的原始字符集名称（iconv 兼容格式，如 `"UTF-8"`、`"GB18030"`）
    public let charset: String

    /// 对应的 `String.Encoding`
    public let encoding: String.Encoding

    public var description: String {
        return "\(charset) (\(encoding.rawValue))"
    }

    /// 使用检测到的编码将原始字节解码为字符串
    ///
    /// - Parameter data: 与本次检测结果对应的原始字节数据
    /// - Returns: 解码后的字符串；解码失败时返回 `nil`
    public func decode(_ data: Data) -> String? {
        return String(data: data, encoding: encoding)
    }

    /// 使用检测到的编码将原始字节解码为字符串，失败时使用回退编码
    ///
    /// - Parameters:
    ///   - data: 原始字节数据
    ///   - fallbackEncoding: 解码失败时使用的回退编码
    /// - Returns: 解码后的字符串；主编码与回退编码均失败时返回 `nil`
    public func decode(_ data: Data, fallbackEncoding: String.Encoding) -> String? {
        return decode(data) ?? String(data: data, encoding: fallbackEncoding)
    }
}

// MARK: - String.Encoding 扩展

public extension String.Encoding {

    /// 将 uchardet 返回的 charset 名称（iconv 兼容格式）转换为 `String.Encoding`。
    ///
    /// 支持 uchardet 可能返回的全部编码名称，大小写不敏感。
    ///
    /// - Parameter charsetName: uchardet 返回的字符集名称
    /// - Returns: 对应的 `String.Encoding`，无法映射时返回 `nil`
    init?(charsetName: String) {
        guard let encoding = String.Encoding.from(charsetName: charsetName) else { return nil }
        self = encoding
    }

    private static func from(charsetName: String) -> String.Encoding? {
        let trimmed = charsetName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let name = trimmed.uppercased()
            .replacingOccurrences(of: "_", with: "-")

        switch name {
        // Unicode
        case "UTF-8", "UTF8":                                   return .utf8
        case "UTF-16", "UTF16":                                 return .utf16
        case "UTF-16BE", "UTF-16-BE", "UTF16BE":               return .utf16BigEndian
        case "UTF-16LE", "UTF-16-LE", "UTF16LE":               return .utf16LittleEndian
        case "UTF-32", "UTF32":                                 return .utf32
        case "UTF-32BE", "UTF-32-BE", "UTF32BE":               return .utf32BigEndian
        case "UTF-32LE", "UTF-32-LE", "UTF32LE":               return .utf32LittleEndian
        // 非标准字节序 UCS-4（Apple 平台无原生支持）
        case "X-ISO-10646-UCS-4-34121", "X-ISO-10646-UCS-4-21431": return nil
        // ASCII
        case "ASCII", "US-ASCII", "USASCII", "US ASCII":       return .ascii
        // 中文
        case "GB2312", "GB-2312", "CN-GB", "CSGB2312":         return cf(CFEnc.gb2312)
        case "GBK", "X-GBK":                                   return cf(CFEnc.gbk)
        case "GB18030", "GB-18030":                             return cf(CFEnc.gb18030)
        case "BIG5", "BIG-5", "BIG5-HKSCS", "BIG5-HKSCS:2004",
             "BIG5-HKSCS:2001", "BIG5-HKSCS:1999", "CN-BIG5": return cf(CFEnc.big5)
        case "EUC-TW", "EUCTW", "X-EUC-TW":                   return cf(CFEnc.eucTW)
        case "ISO-2022-CN", "ISO2022CN", "CSISO2022CN":        return cf(CFEnc.iso2022CN)
        // HZ-GB-2312 是 7-bit 转义编码，Apple 平台无原生支持，回退到 GB2312
        case "HZ-GB-2312", "HZ", "HZ-GB2312":                 return cf(CFEnc.gb2312)
        // 日文
        case "EUC-JP", "EUCJP", "X-EUC-JP":                   return .japaneseEUC
        case "SHIFT-JIS", "SHIFTJIS", "SJIS", "X-SJIS",
             "MS-KANJI", "SHIFT JIS":                          return .shiftJIS
        case "ISO-2022-JP", "ISO2022JP", "CSISO2022JP":        return cf(CFEnc.iso2022JP)
        // 韩文
        case "EUC-KR", "EUCKR", "UHC", "CP949",
             "KS-C-5601-1987", "KS-C-5601-1989",
             "ISO-IR-149", "CSEUCKR":                          return cf(CFEnc.eucKR)
        case "ISO-2022-KR", "ISO2022KR", "CSISO2022KR":       return cf(CFEnc.iso2022KR)
        // Cyrillic
        case "KOI8-R", "KOI8R", "CSKOI8R":                    return cf(CFEnc.koi8R)
        case "KOI8-U", "KOI8U":                                return cf(CFEnc.koi8U)
        case "WINDOWS-1251", "CP1251", "CP-1251", "X-CP1251": return cf(CFEnc.windowsCyrillic)
        case "ISO-8859-5", "ISO8859-5",
             "CYRILLIC", "CSISOLATINCYRILLIC":                 return cf(CFEnc.isoLatinCyrillic)
        case "IBM855", "CP855":                                 return cf(CFEnc.dosCyrillic)
        case "IBM866", "CP866":                                 return cf(CFEnc.dosRussian)
        case "MAC-CYRILLIC", "MACCYRILLIC", "X-MAC-CYRILLIC": return cf(CFEnc.macCyrillic)
        // 西欧 / Latin-1
        case "ISO-8859-1", "ISO8859-1", "LATIN1", "L1",
             "ISO-IR-100", "CSISOLATIN1":                      return .isoLatin1
        case "ISO-8859-15", "ISO8859-15", "LATIN9", "L9",
             "ISO-IR-203", "CSISOLATIN9":                      return cf(CFEnc.isoLatin9)
        case "WINDOWS-1252", "CP1252", "CP-1252", "X-CP1252": return cf(CFEnc.windowsLatin1)
        // 中东欧 / Latin-2
        case "ISO-8859-2", "ISO8859-2", "LATIN2", "L2",
             "ISO-IR-101", "CSISOLATIN2":                      return .isoLatin2
        case "WINDOWS-1250", "CP1250", "CP-1250", "X-CP1250": return cf(CFEnc.windowsLatin2)
        case "IBM852", "CP852":                                 return cf(CFEnc.dosLatin2)
        case "MAC-CENTRALEUROPE", "MACCENTRALEUROPE",
             "X-MAC-CENTRALEUROPE", "MAC-CE", "MACCE":        return cf(CFEnc.macCentralEurRoman)
        // 希腊语
        case "ISO-8859-7", "ISO8859-7", "GREEK", "GREEK8",
             "ISO-IR-126", "CSISOLATINGREEK":                  return cf(CFEnc.isoLatinGreek)
        case "WINDOWS-1253", "CP1253", "CP-1253", "X-CP1253": return cf(CFEnc.windowsGreek)
        // 希伯来语
        case "ISO-8859-8", "ISO8859-8", "HEBREW",
             "ISO-IR-138", "CSISOLATINHEBREW":                 return cf(CFEnc.isoLatinHebrew)
        case "WINDOWS-1255", "CP1255", "CP-1255", "X-CP1255": return cf(CFEnc.windowsHebrew)
        // 阿拉伯语
        case "ISO-8859-6", "ISO8859-6", "ARABIC",
             "ISO-IR-127", "CSISOLATINARABIC":                 return cf(CFEnc.isoLatinArabic)
        case "WINDOWS-1256", "CP1256", "CP-1256", "X-CP1256": return cf(CFEnc.windowsArabic)
        // 波罗的海 / Baltic
        case "ISO-8859-4", "ISO8859-4", "LATIN4", "L4",
             "ISO-IR-110", "CSISOLATIN4":                      return cf(CFEnc.isoLatin4)
        case "ISO-8859-10", "ISO8859-10", "LATIN6", "L6",
             "ISO-IR-157", "CSISOLATIN6":                      return cf(CFEnc.isoLatin6)
        case "ISO-8859-13", "ISO8859-13", "LATIN7", "L7",
             "ISO-IR-179":                                     return cf(CFEnc.isoLatin7)
        case "WINDOWS-1257", "CP1257", "CP-1257", "X-CP1257": return cf(CFEnc.windowsBalticRim)
        case "IBM865", "CP865":                                 return cf(CFEnc.dosNordic)
        // 土耳其语
        case "ISO-8859-3", "ISO8859-3", "LATIN3", "L3",
             "ISO-IR-109", "CSISOLATIN3":                      return cf(CFEnc.isoLatin3)
        case "ISO-8859-9", "ISO8859-9", "LATIN5", "L5",
             "ISO-IR-148", "CSISOLATIN5":                      return cf(CFEnc.isoLatin5)
        case "WINDOWS-1254", "CP1254", "CP-1254", "X-CP1254": return cf(CFEnc.windowsLatin5)
        // 泰语
        case "TIS-620", "TIS620",
             "ISO-8859-11", "ISO8859-11":                      return cf(CFEnc.isoLatinThai)
        // 越南语
        case "WINDOWS-1258", "CP1258", "CP-1258", "X-CP1258": return cf(CFEnc.windowsVietnamese)
        case "VISCII", "VISCII1.1-1":                          return cf(CFEnc.viscii)
        // 罗马尼亚语
        case "ISO-8859-16", "ISO8859-16", "LATIN10", "L10",
             "ISO-IR-226":                                     return cf(CFEnc.isoLatin10)
        default:
            // 回退：通过 CFString IANA 名称转换
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
            guard cfEncoding != kCFStringEncodingInvalidId,
                  CFStringIsEncodingAvailable(cfEncoding) else { return nil }
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            guard nsEncoding != UInt(kCFStringEncodingInvalidId),
                  nsEncoding != UInt.max else { return nil }
            return String.Encoding(rawValue: nsEncoding)
        }
    }

    private static func cf(_ cfEncoding: CFStringEncoding) -> String.Encoding? {
        guard cfEncoding != kCFStringEncodingInvalidId,
              CFStringIsEncodingAvailable(cfEncoding) else { return nil }
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        guard nsEncoding != UInt(kCFStringEncodingInvalidId),
              nsEncoding != UInt.max else { return nil }
        return String.Encoding(rawValue: nsEncoding)
    }
}

// MARK: - Uchardet 主类

/// uchardet 字符集检测器的 Swift 封装
///
/// ## 快速上手
///
/// **一次性检测：**
/// ```swift
/// // 检测 Data（失败时抛出错误）
/// let result = try Uchardet.detect(data)
/// print(result.charset)   // "GB18030"
/// print(result.encoding)  // String.Encoding
///
/// // 检测字节数组
/// let result = try Uchardet.detect(bytes: bytes)
///
/// // 流式检测文件（大文件友好，仅采样头部；失败时抛出错误）
/// let result = try Uchardet.detect(fileURL)
/// print(result.charset)    // "UTF-8"
/// ```
///
/// **流式检测（手动控制）：**
/// ```swift
/// let detector = Uchardet()
/// detector.feed(chunk1).feed(chunk2)
/// let result = try detector.finalize()
/// ```
///
/// **解码：**
/// ```swift
/// let result = try Uchardet.detect(data)
/// let text = result.decode(data)
///
/// let result = try Uchardet.detect(fileURL)
/// let text = result.decode(try Data(contentsOf: fileURL))
/// ```
///
/// ## 线程安全性
///
/// 实例本身**非线程安全**。若需并发检测，请为每个任务创建独立实例。
/// 静态便捷方法内部各自创建独立实例，可安全并发调用。
public final class Uchardet {

    private let handle: uchardet_t
    private var _finalized = false

    /// 创建一个新的字符集检测器实例
    public init() {
        handle = uchardet_new()
    }

    deinit {
        uchardet_delete(handle)
    }

    // MARK: - 流式喂入 API

    /// 向检测器喂入数据块
    ///
    /// 可多次调用以累积数据，最后调用 `finalize()` 获取结果。
    ///
    /// - Parameter data: 待检测的原始字节数据
    /// - Returns: `self`，支持链式调用
    @discardableResult
    public func feed(_ data: Data) -> Self {
        guard !data.isEmpty, !_finalized else { return self }
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let base = ptr.baseAddress else { return }
            _ = uchardet_handle_data(
                handle,
                base.assumingMemoryBound(to: CChar.self),
                size_t(data.count)
            )
        }
        return self
    }

    /// 向检测器喂入字节数组
    ///
    /// - Parameter bytes: 待检测的原始字节数组
    /// - Returns: `self`，支持链式调用
    @discardableResult
    public func feed(_ bytes: [UInt8]) -> Self {
        guard !bytes.isEmpty, !_finalized else { return self }
        bytes.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let base = ptr.baseAddress else { return }
            _ = uchardet_handle_data(
                handle,
                base.assumingMemoryBound(to: CChar.self),
                size_t(bytes.count)
            )
        }
        return self
    }

    /// 结束数据输入并返回检测结果
    ///
    /// 调用后检测器进入已完成状态，继续调用 `feed()` 将被忽略。
    /// 若需重新检测，请调用 `reset()` 或创建新实例。
    ///
    /// - Returns: 检测结果
    /// - Throws: 数据不足或无法识别时抛出 `UchardetError.unrecognizedEncoding`；
    ///           当前平台不支持检测到的编码时抛出 `UchardetError.unsupportedEncoding`
    @discardableResult
    public func finalize() throws -> DetectionResult {
        if !_finalized {
            uchardet_data_end(handle)
            _finalized = true
        }
        guard let cStr = uchardet_get_charset(handle) else {
            throw UchardetError.unrecognizedEncoding
        }
        let charset = String(cString: cStr)
        guard !charset.isEmpty else {
            throw UchardetError.unrecognizedEncoding
        }
        guard let encoding = String.Encoding(charsetName: charset) else {
            throw UchardetError.unsupportedEncoding(charset)
        }
        return DetectionResult(charset: charset, encoding: encoding)
    }

    /// 重置检测器状态，以便复用实例检测新数据
    public func reset() {
        uchardet_reset(handle)
        _finalized = false
    }
}

// MARK: - 静态便捷方法

public extension Uchardet {

    /// 检测 `Data` 的字符集
    ///
    /// ```swift
    /// let result = try Uchardet.detect(data)
    /// print(result.charset)   // "UTF-8"
    /// let text = result.decode(data)
    /// ```
    ///
    /// - Parameter data: 待检测的原始字节数据
    /// - Returns: 检测结果
    /// - Throws: 数据不足或无法识别时抛出 `UchardetError.unrecognizedEncoding`；
    ///           当前平台不支持检测到的编码时抛出 `UchardetError.unsupportedEncoding`
    static func detect(_ data: Data) throws -> DetectionResult {
        try Uchardet().feed(data).finalize()
    }

    /// 检测字节数组的字符集
    ///
    /// - Parameter bytes: 待检测的原始字节数组
    /// - Returns: 检测结果
    /// - Throws: 数据不足或无法识别时抛出 `UchardetError.unrecognizedEncoding`；
    ///           当前平台不支持检测到的编码时抛出 `UchardetError.unsupportedEncoding`
    static func detect(bytes: [UInt8]) throws -> DetectionResult {
        try Uchardet().feed(bytes).finalize()
    }

    /// 流式读取文件并检测字符集（仅采样头部，大文件友好）
    ///
    /// ```swift
    /// let result = try Uchardet.detect(fileURL)
    /// let data = try Data(contentsOf: fileURL)
    /// let text = result.decode(data)
    /// ```
    ///
    /// - Parameters:
    ///   - url: 待检测文件的 URL
    ///   - sampleSize: 最多采样的字节数，默认 65536（64 KB）
    ///   - chunkSize: 每次读取的块大小，默认 4096（4 KB）
    /// - Returns: 检测结果
    /// - Throws: 文件无法打开或读取时抛出 `CocoaError`；
    ///           数据为空或不足时抛出 `UchardetError.unrecognizedEncoding`；
    ///           当前平台不支持检测到的编码时抛出 `UchardetError.unsupportedEncoding`
    static func detect(
        _ url: URL,
        sampleSize: Int = 65_536,
        chunkSize: Int = 4_096
    ) throws -> DetectionResult {
        let detector = Uchardet()
        try detector.feedFile(at: url, sampleSize: sampleSize, chunkSize: chunkSize)
        return try detector.finalize()
    }
}

// MARK: - 内部：文件流式喂入

private extension Uchardet {

    func feedFile(at url: URL, sampleSize: Int, chunkSize: Int) throws {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { fileHandle.closeFile() }

        let effectiveChunk = max(1, min(chunkSize, sampleSize))
        var totalRead = 0

        while totalRead < sampleSize {
            let toRead = min(effectiveChunk, sampleSize - totalRead)
            let chunk: Data

            // FileHandle.read(upToCount:) 在 macOS 10.15.4 / iOS 13.4 引入。
            // 注意：当前 SDK 中该方法返回 Data?（可选），需要解包。
            // 旧版本使用 readData(ofLength:) 兼容。
            if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
                guard let c = try fileHandle.read(upToCount: toRead), !c.isEmpty else { break }
                chunk = c
            } else {
                let c = fileHandle.readData(ofLength: toRead)
                guard !c.isEmpty else { break }
                chunk = c
            }

            totalRead += chunk.count
            feed(chunk)
        }
    }
}
