import Foundation
import uchardet

// MARK: - CFStringEncoding 常量（避免依赖 CFStringBuiltInEncodings）

// 以下常量来自 CFString.h，直接使用原始值以兼容 Swift Package Manager
private enum CFEnc {
    // Latin（仅保留实际使用的常量）
    static let isoLatin3:        CFStringEncoding = 0x0203  // ISO-8859-3 (Latin-3)
    static let isoLatin4:        CFStringEncoding = 0x0204  // ISO-8859-4 (Latin-4)
    static let isoLatinCyrillic: CFStringEncoding = 0x0205  // ISO-8859-5
    static let isoLatinArabic:   CFStringEncoding = 0x0206  // ISO-8859-6
    static let isoLatinGreek:    CFStringEncoding = 0x0207  // ISO-8859-7
    static let isoLatinHebrew:   CFStringEncoding = 0x0208  // ISO-8859-8
    static let isoLatin5:        CFStringEncoding = 0x0209  // ISO-8859-9 (Latin-5, Turkish)
    static let isoLatin6:        CFStringEncoding = 0x020A  // ISO-8859-10 (Latin-6)
    static let isoLatinThai:     CFStringEncoding = 0x041D  // kCFStringEncodingISOLatinThai / TIS-620
    static let isoLatin7:        CFStringEncoding = 0x020D  // ISO-8859-13 (Latin-7)
    static let isoLatin9:        CFStringEncoding = 0x020F  // ISO-8859-15 (Latin-9)
    static let isoLatin10:       CFStringEncoding = 0x0210  // ISO-8859-16 (Latin-10)

    // Mac
    static let macCyrillic:        CFStringEncoding = 0x0007  // kCFStringEncodingMacCyrillic
    static let macCentralEurRoman: CFStringEncoding = 0x001D  // kCFStringEncodingMacCentralEurRoman (x-mac-centraleurroman)

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
    static let dosLatin2:   CFStringEncoding = 0x0412  // kCFStringEncodingDOSLatin2 (IBM852 / cp852)
    static let dosCyrillic: CFStringEncoding = 0x0413  // kCFStringEncodingDOSCyrillic (IBM855 / cp855)
    static let dosRussian:  CFStringEncoding = 0x041B  // kCFStringEncodingDOSRussian (IBM866 / cp866)
    static let dosNordic:   CFStringEncoding = 0x041A  // kCFStringEncodingDOSNordic (IBM865 / cp865)

    // CJK
    static let big5:    CFStringEncoding = 0x0A03  // kCFStringEncodingBig5
    static let gb2312:  CFStringEncoding = 0x0930  // kCFStringEncodingDOSChineseSimplif (GB 2312)
    static let gbk:     CFStringEncoding = 0x0631  // kCFStringEncodingGBK_95 (GBK)
    static let gb18030: CFStringEncoding = 0x0632  // kCFStringEncodingGB_18030_2000
    static let eucTW:   CFStringEncoding = 0x0931  // kCFStringEncodingEUC_TW
    static let eucKR:   CFStringEncoding = 0x0940  // kCFStringEncodingEUC_KR
    // ISO-2022
    static let iso2022JP: CFStringEncoding = 0x0820
    static let iso2022KR: CFStringEncoding = 0x0840
    static let iso2022CN: CFStringEncoding = 0x0830  // kCFStringEncodingISO_2022_CN

    // KOI8
    static let koi8R: CFStringEncoding = 0x0A02  // kCFStringEncodingKOI8_R
    static let koi8U: CFStringEncoding = 0x0A08  // kCFStringEncodingKOI8_U (Ukrainian)
    // VISCII
    static let viscii: CFStringEncoding = 0x0A07  // kCFStringEncodingVISCII

    // HZ-GB-2312（CFString 不直接支持，回退到 GB18030）
    // HZ 是 GB2312 的 7-bit ASCII 安全编码，Apple 平台无原生支持
}

// MARK: - String.Encoding 扩展：从 IANA/iconv 名称初始化

public extension String.Encoding {

    /// 将 uchardet 返回的 charset 名称（iconv 兼容格式）转换为 `String.Encoding`。
    ///
    /// 支持的编码名称涵盖 uchardet 可能返回的所有结果，包括：
    /// - Unicode 系列：UTF-8、UTF-16 BE/LE、UTF-32 BE/LE
    /// - ASCII
    /// - 中文：GB2312、GBK、GB18030、Big5、EUC-TW、HZ-GB-2312、ISO-2022-CN
    /// - 日文：EUC-JP、Shift_JIS、ISO-2022-JP
    /// - 韩文：EUC-KR、UHC、ISO-2022-KR
    /// - Cyrillic：KOI8-R、KOI8-U、Windows-1251、ISO-8859-5、IBM855/866、Mac-Cyrillic
    /// - 西欧：ISO-8859-1/15、Windows-1252
    /// - 中东欧：ISO-8859-2、Windows-1250、IBM852、Mac-CentralEurope
    /// - 希腊语：ISO-8859-7、Windows-1253
    /// - 希伯来语：ISO-8859-8、Windows-1255
    /// - 阿拉伯语：ISO-8859-6、Windows-1256
    /// - 波罗的海：ISO-8859-4/10/13、Windows-1257
    /// - 土耳其语：ISO-8859-3/9
    /// - 泰语：TIS-620、ISO-8859-11
    /// - 越南语：Windows-1258、VISCII
    /// - 罗马尼亚语：ISO-8859-16
    ///
    /// - Parameter charsetName: uchardet 返回的字符集名称（大小写不敏感）
    /// - Returns: 对应的 `String.Encoding`，无法映射时返回 `nil`
    init?(charsetName: String) {
        guard let encoding = String.Encoding.from(charsetName: charsetName) else {
            return nil
        }
        self = encoding
    }

    /// 将 charset 名称映射为 `String.Encoding`（内部实现）
    private static func from(charsetName: String) -> String.Encoding? {
        guard !charsetName.isEmpty else { return nil }

        let name = charsetName.uppercased()
            .replacingOccurrences(of: "_", with: "-")
            .trimmingCharacters(in: .whitespaces)

        switch name {

        // MARK: Unicode
        case "UTF-8", "UTF8":
            return .utf8
        case "UTF-16", "UTF16":
            return .utf16
        case "UTF-16BE", "UTF-16-BE", "UTF16BE":
            return .utf16BigEndian
        case "UTF-16LE", "UTF-16-LE", "UTF16LE":
            return .utf16LittleEndian
        case "UTF-32", "UTF32":
            return .utf32
        case "UTF-32BE", "UTF-32-BE", "UTF32BE":
            return .utf32BigEndian
        case "UTF-32LE", "UTF-32-LE", "UTF32LE":
            return .utf32LittleEndian

        // MARK: UCS-4 变体（uchardet 可能返回的特殊名称）
        // X-ISO-10646-UCS-4-34121 / X-ISO-10646-UCS-4-21431 是 uchardet 对
        // 非标准字节序 UTF-32 的命名，映射到最接近的标准编码
        case "X-ISO-10646-UCS-4-34121":
            // 字节序：3-4-1-2，非标准，映射到 UTF-32BE 作为最佳近似
            return .utf32BigEndian
        case "X-ISO-10646-UCS-4-21431":
            // 字节序：2-1-4-3，非标准，映射到 UTF-32LE 作为最佳近似
            return .utf32LittleEndian

        // MARK: ASCII
        case "ASCII", "US-ASCII", "USASCII", "US ASCII":
            return .ascii

        // MARK: 中文
        // uchardet 对简体中文编码的检测结果通常为 GB2312 或 GB18030，
        // 各名称按 Apple 平台实际支持的编码精确映射：
        // - GB2312 / CN-GB / CSGB2312 → kCFStringEncodingDOSChineseSimplif (GB 2312)
        // - GBK / X-GBK               → kCFStringEncodingGBK_95 (GBK)
        // - GB18030 / GB-18030        → kCFStringEncodingGB_18030_2000 (GB 18030)
        // GB18030 是 GBK 的超集，GBK 是 GB2312 的超集，三者均可解码 GB2312 内容
        case "GB2312", "GB-2312", "CN-GB", "CSGB2312":
            return cf(CFEnc.gb2312)
        case "GBK", "X-GBK":
            return cf(CFEnc.gbk)
        case "GB18030", "GB-18030":
            return cf(CFEnc.gb18030)
        case "BIG5", "BIG-5", "BIG5-HKSCS", "BIG5-HKSCS:2004",
             "BIG5-HKSCS:2001", "BIG5-HKSCS:1999", "CN-BIG5":
            return cf(CFEnc.big5)
        case "EUC-TW", "EUCTW", "X-EUC-TW":
            return cf(CFEnc.eucTW)
        case "ISO-2022-CN", "ISO2022CN", "CSISO2022CN":
            // Apple 平台支持 ISO-2022-CN，通过 CFString 映射
            return cf(CFEnc.iso2022CN)
        case "HZ-GB-2312", "HZ", "HZ-GB2312":
            // HZ-GB-2312 是 GB2312 的 7-bit 变体，Apple 平台无原生支持
            // 回退到 GB18030（超集，可正确解码 GB2312 内容）
            return cf(CFEnc.gb18030)

        // MARK: 日文
        case "EUC-JP", "EUCJP", "X-EUC-JP":
            return .japaneseEUC
        case "SHIFT-JIS", "SHIFTJIS", "SJIS", "X-SJIS", "MS-KANJI", "SHIFT JIS":
            return .shiftJIS
        case "ISO-2022-JP", "ISO2022JP", "CSISO2022JP":
            return cf(CFEnc.iso2022JP)

        // MARK: 韩文
        case "EUC-KR", "EUCKR", "UHC", "CP949", "KS-C-5601-1987",
             "KS-C-5601-1989", "ISO-IR-149", "CSEUCKR":
            return cf(CFEnc.eucKR)
        case "ISO-2022-KR", "ISO2022KR", "CSISO2022KR":
            return cf(CFEnc.iso2022KR)

        // MARK: Cyrillic
        case "KOI8-R", "KOI8R", "CSKOI8R":
            return cf(CFEnc.koi8R)
        case "KOI8-U", "KOI8U":
            return cf(CFEnc.koi8U)
        case "WINDOWS-1251", "CP1251", "CP-1251", "X-CP1251":
            return cf(CFEnc.windowsCyrillic)
        case "ISO-8859-5", "ISO8859-5", "CYRILLIC", "CSISOLATINCYRILLIC":
            return cf(CFEnc.isoLatinCyrillic)
        case "IBM855", "CP855":
            return cf(CFEnc.dosCyrillic)
        case "IBM866", "CP866":
            return cf(CFEnc.dosRussian)
        case "MAC-CYRILLIC", "MACCYRILLIC", "X-MAC-CYRILLIC":
            return cf(CFEnc.macCyrillic)

        // MARK: 西欧 / Latin-1
        case "ISO-8859-1", "ISO8859-1", "LATIN1", "L1",
             "ISO-IR-100", "CSISOLATIN1":
            return .isoLatin1
        case "ISO-8859-15", "ISO8859-15", "LATIN9", "L9",
             "ISO-IR-203", "CSISOLATIN9":
            return cf(CFEnc.isoLatin9)
        case "WINDOWS-1252", "CP1252", "CP-1252", "X-CP1252":
            return cf(CFEnc.windowsLatin1)

        // MARK: 中东欧 / Latin-2
        case "ISO-8859-2", "ISO8859-2", "LATIN2", "L2",
             "ISO-IR-101", "CSISOLATIN2":
            return .isoLatin2
        case "WINDOWS-1250", "CP1250", "CP-1250", "X-CP1250":
            return cf(CFEnc.windowsLatin2)
        case "IBM852", "CP852":
            return cf(CFEnc.dosLatin2)
        case "MAC-CENTRALEUROPE", "MACCENTRALEUROPE", "X-MAC-CENTRALEUROPE",
             "MAC-CE", "MACCE":
            return cf(CFEnc.macCentralEurRoman)

        // MARK: 希腊语
        case "ISO-8859-7", "ISO8859-7", "GREEK", "GREEK8",
             "ISO-IR-126", "CSISOLATINGREEK":
            return cf(CFEnc.isoLatinGreek)
        case "WINDOWS-1253", "CP1253", "CP-1253", "X-CP1253":
            return cf(CFEnc.windowsGreek)

        // MARK: 希伯来语
        case "ISO-8859-8", "ISO8859-8", "HEBREW",
             "ISO-IR-138", "CSISOLATINHEBREW":
            return cf(CFEnc.isoLatinHebrew)
        case "WINDOWS-1255", "CP1255", "CP-1255", "X-CP1255":
            return cf(CFEnc.windowsHebrew)

        // MARK: 阿拉伯语
        case "ISO-8859-6", "ISO8859-6", "ARABIC",
             "ISO-IR-127", "CSISOLATINARABIC":
            return cf(CFEnc.isoLatinArabic)
        case "WINDOWS-1256", "CP1256", "CP-1256", "X-CP1256":
            return cf(CFEnc.windowsArabic)

        // MARK: 波罗的海 / Baltic
        case "ISO-8859-4", "ISO8859-4", "LATIN4", "L4",
             "ISO-IR-110", "CSISOLATIN4":
            return cf(CFEnc.isoLatin4)
        case "ISO-8859-10", "ISO8859-10", "LATIN6", "L6",
             "ISO-IR-157", "CSISOLATIN6":
            return cf(CFEnc.isoLatin6)
        case "ISO-8859-13", "ISO8859-13", "LATIN7", "L7",
             "ISO-IR-179":
            return cf(CFEnc.isoLatin7)
        case "WINDOWS-1257", "CP1257", "CP-1257", "X-CP1257":
            return cf(CFEnc.windowsBalticRim)
        case "IBM865", "CP865":
            return cf(CFEnc.dosNordic)

        // MARK: 土耳其语
        case "ISO-8859-3", "ISO8859-3", "LATIN3", "L3",
             "ISO-IR-109", "CSISOLATIN3":
            return cf(CFEnc.isoLatin3)
        case "ISO-8859-9", "ISO8859-9", "LATIN5", "L5",
             "ISO-IR-148", "CSISOLATIN5":
            return cf(CFEnc.isoLatin5)
        case "WINDOWS-1254", "CP1254", "CP-1254", "X-CP1254":
            return cf(CFEnc.windowsLatin5)

        // MARK: 泰语
        case "TIS-620", "TIS620", "ISO-8859-11", "ISO8859-11":
            return cf(CFEnc.isoLatinThai)

        // MARK: 越南语
        case "WINDOWS-1258", "CP1258", "CP-1258", "X-CP1258":
            return cf(CFEnc.windowsVietnamese)
        case "VISCII", "VISCII1.1-1":
            return cf(CFEnc.viscii)

        // MARK: 罗马尼亚语
        case "ISO-8859-16", "ISO8859-16", "LATIN10", "L10",
             "ISO-IR-226":
            return cf(CFEnc.isoLatin10)

        default:
            // 尝试通过 CFString 的 IANA 名称转换（使用规范化后的大写名称以提高匹配率）
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
            guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            return String.Encoding(rawValue: nsEncoding)
        }
    }

    /// 将 CFStringEncoding 转换为 String.Encoding 的辅助函数
    private static func cf(_ cfEncoding: CFStringEncoding) -> String.Encoding? {
        // 先验证 CFStringEncoding 本身是否有效，避免传入无效值给转换函数
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        // CFStringConvertEncodingToNSStringEncoding 对无效编码返回 kCFStringEncodingInvalidId
        // 对应的 NSStringEncoding 值（即 UInt(0xffffffff) = 4294967295）。
        // 使用 UInt(kCFStringEncodingInvalidId) 而非 UInt.max，以确保在 32-bit 和 64-bit
        // 平台上语义一致（32-bit 上两者相等，64-bit 上 UInt.max 更大）。
        guard nsEncoding != UInt(kCFStringEncodingInvalidId) else { return nil }
        return String.Encoding(rawValue: nsEncoding)
    }
}

// MARK: - Uchardet 主类

/// uchardet 字符集检测器的 Swift 封装
///
/// `Uchardet` 封装了底层 C 库的生命周期管理，提供面向 Swift 的惯用 API。
/// 实例本身**非线程安全**——同一实例不应在多个线程中并发调用；
/// 若需并发检测，请为每个任务创建独立实例，或使用线程安全的静态便捷方法。
public final class Uchardet: @unchecked Sendable {

    private let handle: uchardet_t

    /// 创建一个新的字符集检测器实例
    public init() {
        handle = uchardet_new()
    }

    deinit {
        uchardet_delete(handle)
    }

    // MARK: - 实例方法

    /// 向检测器喂入数据
    /// - Parameter data: 待检测的原始字节数据
    /// - Returns: 数据被成功处理返回 `true`；底层 C API 返回非零错误码时返回 `false`
    @discardableResult
    public func handleData(_ data: Data) -> Bool {
        guard !data.isEmpty else { return true }
        return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Bool in
            guard let baseAddress = ptr.baseAddress else { return true }
            let result = uchardet_handle_data(
                handle,
                baseAddress.assumingMemoryBound(to: CChar.self),
                data.count
            )
            return result == 0
        }
    }

    /// 向检测器喂入字节数组
    /// - Parameter bytes: 待检测的原始字节数组
    /// - Returns: 数据被成功处理返回 `true`；底层 C API 返回非零错误码时返回 `false`
    @discardableResult
    public func handleData(_ bytes: [UInt8]) -> Bool {
        guard !bytes.isEmpty else { return true }
        return bytes.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Bool in
            // 非空数组的 baseAddress 不会为 nil，此处 guard 仅作防御性检查
            guard let baseAddress = ptr.baseAddress else { return true }
            let result = uchardet_handle_data(
                handle,
                baseAddress.assumingMemoryBound(to: CChar.self),
                bytes.count
            )
            return result == 0
        }
    }

    /// 通知检测器数据已结束
    public func dataEnd() {
        uchardet_data_end(handle)
    }

    /// 重置检测器状态，以便复用实例检测新数据
    public func reset() {
        uchardet_reset(handle)
    }

    /// 获取检测到的字符集名称（iconv 兼容格式）
    /// - Returns: 字符集名称字符串，检测失败时返回 `nil`
    public var charset: String? {
        guard let cString = uchardet_get_charset(handle) else { return nil }
        let result = String(cString: cString)
        return result.isEmpty ? nil : result
    }

    /// 获取检测到的字符集对应的 `String.Encoding`
    /// - Returns: 对应的 `String.Encoding`，无法映射时返回 `nil`
    public var encoding: String.Encoding? {
        guard let name = charset else { return nil }
        return String.Encoding(charsetName: name)
    }

    // MARK: - 静态便捷方法（Data）

    /// 一次性检测数据的字符集名称
    /// - Parameter data: 待检测的原始字节数据
    /// - Returns: 检测到的字符集名称，失败时返回 `nil`
    public static func detect(_ data: Data) -> String? {
        let detector = Uchardet()
        detector.handleData(data)
        detector.dataEnd()
        return detector.charset
    }

    /// 一次性检测字符串（UTF-8 编码）的字符集名称
    /// - Parameter string: 待检测的字符串
    /// - Returns: 检测到的字符集名称，失败时返回 `nil`
    public static func detect(_ string: String) -> String? {
        guard let data = string.data(using: .utf8) else { return nil }
        return detect(data)
    }

    /// 一次性检测字节数组的字符集名称
    /// - Parameter bytes: 待检测的原始字节数组
    /// - Returns: 检测到的字符集名称，失败时返回 `nil`
    public static func detect(bytes: [UInt8]) -> String? {
        let detector = Uchardet()
        detector.handleData(bytes)
        detector.dataEnd()
        return detector.charset
    }

    /// 一次性检测数据的 `String.Encoding`
    /// - Parameter data: 待检测的原始字节数据
    /// - Returns: 检测到的 `String.Encoding`，失败或无法映射时返回 `nil`
    public static func detectEncoding(_ data: Data) -> String.Encoding? {
        let detector = Uchardet()
        detector.handleData(data)
        detector.dataEnd()
        return detector.encoding
    }

    /// 一次性检测字符串（UTF-8 编码）的 `String.Encoding`
    /// - Parameter string: 待检测的字符串
    /// - Returns: 检测到的 `String.Encoding`，失败或无法映射时返回 `nil`
    public static func detectEncoding(_ string: String) -> String.Encoding? {
        guard let data = string.data(using: .utf8) else { return nil }
        return detectEncoding(data)
    }

    /// 一次性检测字节数组的 `String.Encoding`
    /// - Parameter bytes: 待检测的原始字节数组
    /// - Returns: 检测到的 `String.Encoding`，失败或无法映射时返回 `nil`
    public static func detectEncoding(bytes: [UInt8]) -> String.Encoding? {
        let detector = Uchardet()
        detector.handleData(bytes)
        detector.dataEnd()
        return detector.encoding
    }

    // MARK: - 大文件流式检测 API

    /// 流式读取文件并检测字符集名称（仅采样头部数据，避免将整个文件加载到内存）
    ///
    /// 通过 `FileHandle` 分块读取文件，最多读取 `sampleSize` 字节。
    /// 遇到读取错误时会提前停止。
    ///
    /// - Parameters:
    ///   - url: 待检测文件的 URL
    ///   - sampleSize: 最多采样的字节数，默认 65536（64 KB）
    ///   - chunkSize: 每次读取的块大小，默认 4096（4 KB）
    /// - Returns: 检测到的字符集名称（iconv 兼容格式），失败时返回 `nil`
    /// - Throws: 文件无法打开或读取时抛出 `CocoaError`
    public static func detect(
        contentsOf url: URL,
        sampleSize: Int = 65_536,
        chunkSize: Int = 4_096
    ) throws -> String? {
        let detector = Uchardet()
        try detector.feedFile(at: url, sampleSize: sampleSize, chunkSize: chunkSize)
        detector.dataEnd()
        return detector.charset
    }

    /// 流式读取文件并检测 `String.Encoding`（仅采样头部数据，避免将整个文件加载到内存）
    ///
    /// - Parameters:
    ///   - url: 待检测文件的 URL
    ///   - sampleSize: 最多采样的字节数，默认 65536（64 KB）
    ///   - chunkSize: 每次读取的块大小，默认 4096（4 KB）
    /// - Returns: 检测到的 `String.Encoding`，失败或无法映射时返回 `nil`
    /// - Throws: 文件无法打开或读取时抛出 `CocoaError`
    public static func detectEncoding(
        contentsOf url: URL,
        sampleSize: Int = 65_536,
        chunkSize: Int = 4_096
    ) throws -> String.Encoding? {
        let detector = Uchardet()
        try detector.feedFile(at: url, sampleSize: sampleSize, chunkSize: chunkSize)
        detector.dataEnd()
        return detector.encoding
    }

    /// 分块读取文件并向检测器喂入数据（内部实现）
    ///
    /// - Parameters:
    ///   - url: 待读取文件的 URL
    ///   - sampleSize: 最多读取的总字节数
    ///   - chunkSize: 每次读取的块大小
    /// - Throws: 文件无法打开时抛出错误
    private func feedFile(at url: URL, sampleSize: Int, chunkSize: Int) throws {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { fileHandle.closeFile() }

        let effectiveChunk = max(1, min(chunkSize, sampleSize))
        var totalRead = 0

        while totalRead < sampleSize {
            let remaining = sampleSize - totalRead
            let toRead = min(effectiveChunk, remaining)
            let chunk: Data

            // FileHandle.read(upToCount:) 在 macOS 10.15.4+ 引入，抛出错误而非返回 nil，
            // 但在部分 SDK 版本中其返回类型仍为 Data?，故使用 guard let 解包以兼容所有版本。
            if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
                guard let c = try fileHandle.read(upToCount: toRead), !c.isEmpty else { break }
                chunk = c
            } else {
                let c = fileHandle.readData(ofLength: toRead)
                guard !c.isEmpty else { break }
                chunk = c
            }

            totalRead += chunk.count
            // handleData 返回 false 表示底层 C API 报告错误，停止继续喂入数据
            let shouldContinue = handleData(chunk)
            if !shouldContinue { break }
        }
    }
}
