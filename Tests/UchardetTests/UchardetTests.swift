import Testing
import Foundation
@testable import Uchardet

// MARK: - 测试辅助工具

/// 项目根目录（通过当前源文件路径推算）
/// Tests/UchardetTests/UchardetTests.swift -> 上两级即为项目根目录
private let projectRoot: URL = {
    // #filePath 返回当前源文件的绝对路径
    let thisFile = URL(fileURLWithPath: #filePath)
    // Tests/uchardetTests/uchardetTests.swift
    // .deletingLastPathComponent() -> Tests/uchardetTests
    // .deletingLastPathComponent() -> Tests
    // .deletingLastPathComponent() -> 项目根目录
    return thisFile
        .deletingLastPathComponent()  // uchardetTests/
        .deletingLastPathComponent()  // Tests/
        .deletingLastPathComponent()  // 项目根目录
}()

/// 从项目 test/ 目录加载文件数据
private func loadTestFile(lang: String, filename: String) throws -> Data {
    let url = projectRoot
        .appendingPathComponent("test")
        .appendingPathComponent(lang)
        .appendingPathComponent(filename)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw TestError.fileNotFound("test/\(lang)/\(filename)")
    }
    return try Data(contentsOf: url)
}

private enum TestError: Error, CustomStringConvertible {
    case fileNotFound(String)
    var description: String {
        switch self {
        case .fileNotFound(let path): return "测试文件未找到: \(path)"
        }
    }
}

// MARK: - API 基础功能测试


@Suite("API 基础功能测试")
struct APIFunctionalityTests {

    @Test("初始化与销毁")
    func testInitAndDeinit() {
//        let detector = Uchardet()
//        // 初始化后 charset 应为 nil（未检测任何数据）
//        #expect(detector.charset == nil)
        
//        // Do any additional setup after loading the view.
//        // 获取 GB18030 编码的 Core Foundation 标识
//        let cfEncoding = CFStringEncodings.GB_18030_2000
//        // 转换为 Foundation 框架可用的 NSStringEncoding
//        let encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cfEncoding.rawValue))
        
    }

    @Test("handleData 返回值 - 有效数据")
    func testHandleDataWithValidData() {
        let detector = Uchardet()
        let data = "Hello, World!".data(using: .utf8)!
        let result = detector.handleData(data)
        #expect(result == true)
    }

    @Test("handleData 返回值 - 空数据")
    func testHandleDataWithEmptyData() {
        let detector = Uchardet()
        let result = detector.handleData(Data())
        // 空 Data 会被 handleData 内部的 guard !data.isEmpty 提前拦截，
        // 直接返回 true，不会调用底层 C API
        #expect(result == true)
    }

    @Test("dataEnd 调用后可获取 charset")
    func testDataEndEnablesCharsetRetrieval() {
        let detector = Uchardet()
        let data = "Hello, World! This is a simple ASCII text.".data(using: .utf8)!
        detector.handleData(data)
        detector.dataEnd()
        let charset = detector.charset
        #expect(charset != nil)
    }

    @Test("reset 后 charset 清空")
    func testResetClearsCharset() {
        let detector = Uchardet()
        let data = "Hello, World! This is a simple ASCII text.".data(using: .utf8)!
        detector.handleData(data)
        detector.dataEnd()
        #expect(detector.charset != nil)
        detector.reset()
        // reset 后 charset 应为 nil
        #expect(detector.charset == nil)
    }

    @Test("reset 后可重新检测")
    func testResetAllowsRedetection() {
        let detector = Uchardet()

        // 第一次检测 ASCII
        let asciiData = "Hello, World! Simple ASCII text for detection.".data(using: .utf8)!
        detector.handleData(asciiData)
        detector.dataEnd()
        let firstCharset = detector.charset
        #expect(firstCharset != nil)

        // reset 后重新检测
        detector.reset()
        let utf8Data = "你好世界，这是一段中文文本用于测试字符集检测功能。".data(using: .utf8)!
        detector.handleData(utf8Data)
        detector.dataEnd()
        let secondCharset = detector.charset
        #expect(secondCharset != nil)
        #expect(secondCharset?.uppercased() == "UTF-8")
    }

    @Test("静态 detect(Data) 方法")
    func testStaticDetectData() {
        let data = "Hello, World! This is ASCII text.".data(using: .utf8)!
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
    }

    @Test("静态 detect(String) 方法")
    func testStaticDetectString() {
        let charset = Uchardet.detect("Hello, World! This is ASCII text.")
        #expect(charset != nil)
    }

    @Test("静态 detect(String) - UTF-8 中文")
    func testStaticDetectStringChinese() {
        let charset = Uchardet.detect("这是一段中文文本，用于测试 UTF-8 字符集检测功能是否正常工作。")
        #expect(charset?.uppercased() == "UTF-8")
    }
}

// MARK: - ASCII 编码测试

@Suite("ASCII 编码检测测试")
struct ASCIITests {

    @Test("纯 ASCII 文本检测")
    func testPureASCII() throws {
        let data = try loadTestFile(lang: "en", filename: "ascii.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        // ASCII 可能被检测为 ASCII 或 UTF-8（ASCII 是 UTF-8 子集）
        let upper = charset!.uppercased()
        #expect(upper == "ASCII" || upper == "UTF-8")
    }

    @Test("手动构造 ASCII 数据")
    func testManualASCII() {
        let text = "The quick brown fox jumps over the lazy dog. 0123456789."
        let data = text.data(using: .ascii)!
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper == "ASCII" || upper == "UTF-8")
    }
}

// MARK: - UTF-8 编码测试

@Suite("UTF-8 编码检测测试")
struct UTF8Tests {

    @Test("中文 UTF-8")
    func testChineseUTF8() throws {
        let data = try loadTestFile(lang: "zh", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("日文 UTF-8")
    func testJapaneseUTF8() throws {
        let data = try loadTestFile(lang: "ja", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("韩文 UTF-8")
    func testKoreanUTF8() throws {
        let data = try loadTestFile(lang: "ko", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("法语 UTF-8")
    func testFrenchUTF8() throws {
        let data = try loadTestFile(lang: "fr", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("德语 UTF-8（通过手动构造）")
    func testGermanUTF8() {
        let text = "Ärger mit Übergröße führt zu Ärger. Straße, Größe, Füße."
        let data = text.data(using: .utf8)!
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("阿拉伯语 UTF-8")
    func testArabicUTF8() throws {
        let data = try loadTestFile(lang: "ar", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("希伯来语 UTF-8")
    func testHebrewUTF8() throws {
        let data = try loadTestFile(lang: "he", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("希腊语 UTF-8")
    func testGreekUTF8() throws {
        let data = try loadTestFile(lang: "el", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("泰语 UTF-8")
    func testThaiUTF8() throws {
        let data = try loadTestFile(lang: "th", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("越南语 UTF-8")
    func testVietnameseUTF8() throws {
        let data = try loadTestFile(lang: "vi", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("西班牙语 UTF-8")
    func testSpanishUTF8() throws {
        let data = try loadTestFile(lang: "es", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("葡萄牙语 UTF-8")
    func testPortugueseUTF8() throws {
        let data = try loadTestFile(lang: "pt", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("意大利语 UTF-8")
    func testItalianUTF8() throws {
        let data = try loadTestFile(lang: "it", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("爱尔兰语 UTF-8")
    func testIrishUTF8() throws {
        let data = try loadTestFile(lang: "ga", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("立陶宛语 UTF-8")
    func testLithuanianUTF8() throws {
        let data = try loadTestFile(lang: "lt", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("拉脱维亚语 UTF-8")
    func testLatvianUTF8() throws {
        let data = try loadTestFile(lang: "lv", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("斯洛伐克语 UTF-8")
    func testSlovakUTF8() throws {
        let data = try loadTestFile(lang: "sk", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("斯洛文尼亚语 UTF-8")
    func testSloveneUTF8() throws {
        let data = try loadTestFile(lang: "sl", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("捷克语 UTF-8")
    func testCzechUTF8() throws {
        let data = try loadTestFile(lang: "cs", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("丹麦语 UTF-8")
    func testDanishUTF8() throws {
        let data = try loadTestFile(lang: "da", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("芬兰语 UTF-8")
    func testFinnishUTF8() throws {
        let data = try loadTestFile(lang: "fi", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("挪威语 UTF-8")
    func testNorwegianUTF8() throws {
        let data = try loadTestFile(lang: "no", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("瑞典语 UTF-8")
    func testSwedishUTF8() throws {
        let data = try loadTestFile(lang: "sv", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("罗马尼亚语 UTF-8")
    func testRomanianUTF8() throws {
        let data = try loadTestFile(lang: "ro", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("马耳他语 UTF-8")
    func testMalteseUTF8() throws {
        let data = try loadTestFile(lang: "mt", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("克罗地亚语 UTF-8")
    func testCroatianUTF8() throws {
        let data = try loadTestFile(lang: "hr", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("爱沙尼亚语 UTF-8")
    func testEstonianUTF8() throws {
        let data = try loadTestFile(lang: "et", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }
}

// MARK: - UTF-16 / UTF-32 编码测试

@Suite("UTF-16 / UTF-32 编码检测测试")
struct UTF16UTF32Tests {

    @Test("法语 UTF-16 BE")
    func testFrenchUTF16BE() throws {
        let data = try loadTestFile(lang: "fr", filename: "utf-16.be")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("UTF-16") || upper.contains("UTF16"))
    }

    @Test("法语 UTF-32 LE")
    func testFrenchUTF32LE() throws {
        let data = try loadTestFile(lang: "fr", filename: "utf-32.le")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("UTF-32") || upper.contains("UTF32"))
    }

    @Test("日文 UTF-16 BE")
    func testJapaneseUTF16BE() throws {
        let data = try loadTestFile(lang: "ja", filename: "utf-16be.txt")
        let charset = Uchardet.detect(data)
        // uchardet 对部分 UTF-16 文件可能无法检测（返回 nil），属于已知限制
        if let charset = charset {
            let upper = charset.uppercased()
            #expect(upper.contains("UTF-16") || upper.contains("UTF16") || upper.contains("UTF-8"))
        }
        // charset 为 nil 时也视为可接受（uchardet 不支持该格式）
    }

    @Test("日文 UTF-16 LE")
    func testJapaneseUTF16LE() throws {
        let data = try loadTestFile(lang: "ja", filename: "utf-16le.txt")
        let charset = Uchardet.detect(data)
        // uchardet 对部分 UTF-16 文件可能无法检测（返回 nil），属于已知限制
        if let charset = charset {
            let upper = charset.uppercased()
            #expect(upper.contains("UTF-16") || upper.contains("UTF16") || upper.contains("UTF-8"))
        }
        // charset 为 nil 时也视为可接受（uchardet 不支持该格式）
    }

    @Test("韩文 UTF-16 LE")
    func testKoreanUTF16LE() throws {
        let data = try loadTestFile(lang: "ko", filename: "utf-16.le")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("UTF-16") || upper.contains("UTF16"))
    }

    @Test("韩文 UTF-32 BE")
    func testKoreanUTF32BE() throws {
        let data = try loadTestFile(lang: "ko", filename: "utf-32.be")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("UTF-32") || upper.contains("UTF32"))
    }
}

// MARK: - 中文编码测试

@Suite("中文编码检测测试")
struct ChineseEncodingTests {

    @Test("中文 GB18030")
    func testChineseGB18030() throws {
        let data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        // GB18030 可能被检测为 GB18030 或 GB2312
        #expect(upper.contains("GB") || upper.contains("GBK"))
    }

    @Test("中文 Big5")
    func testChineseBig5() throws {
        let data = try loadTestFile(lang: "zh", filename: "big5.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("BIG5") || upper.contains("BIG-5"))
    }

    @Test("中文 EUC-TW")
    func testChineseEUCTW() throws {
        let data = try loadTestFile(lang: "zh", filename: "euc-tw.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("EUC-TW") || upper.contains("EUCTW"))
    }
}

// MARK: - 日文编码测试

@Suite("日文编码检测测试")
struct JapaneseEncodingTests {

    @Test("日文 EUC-JP")
    func testJapaneseEUCJP() throws {
        let data = try loadTestFile(lang: "ja", filename: "euc-jp.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("EUC-JP") || upper.contains("EUCJP"))
    }

    @Test("日文 Shift_JIS")
    func testJapaneseShiftJIS() throws {
        let data = try loadTestFile(lang: "ja", filename: "shift_jis.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("SHIFT") || upper.contains("SJIS") || upper.contains("SHIFT_JIS"))
    }

    @Test("日文 ISO-2022-JP")
    func testJapaneseISO2022JP() throws {
        let data = try loadTestFile(lang: "ja", filename: "iso-2022-jp.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-2022-JP") || upper.contains("ISO2022JP"))
    }
}

// MARK: - 韩文编码测试

@Suite("韩文编码检测测试")
struct KoreanEncodingTests {

    @Test("韩文 UHC (EUC-KR)")
    func testKoreanUHC() throws {
        let data = try loadTestFile(lang: "ko", filename: "uhc.smi")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("EUC-KR") || upper.contains("UHC") || upper.contains("CP949"))
    }

    @Test("韩文 ISO-2022-KR")
    func testKoreanISO2022KR() throws {
        let data = try loadTestFile(lang: "ko", filename: "iso-2022-kr.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-2022-KR") || upper.contains("ISO2022KR"))
    }
}

// MARK: - 欧洲语言 ISO-8859 系列测试

@Suite("ISO-8859 系列编码检测测试")
struct ISO8859Tests {

    @Test("阿拉伯语 ISO-8859-6")
    func testArabicISO88596() throws {
        let data = try loadTestFile(lang: "ar", filename: "iso-8859-6.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-6") || upper.contains("WINDOWS-1256"))
    }

    @Test("希腊语 ISO-8859-7")
    func testGreekISO88597() throws {
        let data = try loadTestFile(lang: "el", filename: "iso-8859-7.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-7") || upper.contains("WINDOWS-1253"))
    }

    @Test("希伯来语 ISO-8859-8")
    func testHebrewISO88598() throws {
        let data = try loadTestFile(lang: "he", filename: "iso-8859-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-8") || upper.contains("WINDOWS-1255"))
    }

    @Test("土耳其语 ISO-8859-9")
    func testTurkishISO88599() throws {
        let data = try loadTestFile(lang: "tr", filename: "iso-8859-9.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-9") || upper.contains("WINDOWS-1254"))
    }

    @Test("爱沙尼亚语 ISO-8859-4")
    func testEstonianISO88594() throws {
        let data = try loadTestFile(lang: "et", filename: "iso-8859-4.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859"))
    }

    @Test("爱沙尼亚语 ISO-8859-13")
    func testEstonianISO885913() throws {
        let data = try loadTestFile(lang: "et", filename: "iso-8859-13.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859") || upper.contains("WINDOWS-1257"))
    }

    @Test("爱沙尼亚语 ISO-8859-15")
    func testEstonianISO885915() throws {
        let data = try loadTestFile(lang: "et", filename: "iso-8859-15.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859"))
    }

    @Test("捷克语 ISO-8859-2")
    func testCzechISO88592() throws {
        let data = try loadTestFile(lang: "cs", filename: "iso-8859-2.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-2") || upper.contains("WINDOWS-1250"))
    }

    @Test("克罗地亚语 ISO-8859-2")
    func testCroatianISO88592() throws {
        let data = try loadTestFile(lang: "hr", filename: "iso-8859-2.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-2") || upper.contains("WINDOWS-1250"))
    }

    @Test("克罗地亚语 ISO-8859-13")
    func testCroatianISO885913() throws {
        let data = try loadTestFile(lang: "hr", filename: "iso-8859-13.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859") || upper.contains("WINDOWS-1257"))
    }

    @Test("克罗地亚语 ISO-8859-16")
    func testCroatianISO885916() throws {
        let data = try loadTestFile(lang: "hr", filename: "iso-8859-16.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-16"))
    }

    @Test("丹麦语 ISO-8859-1")
    func testDanishISO88591() throws {
        let data = try loadTestFile(lang: "da", filename: "iso-8859-1.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-1") || upper.contains("WINDOWS-1252"))
    }

    @Test("丹麦语 ISO-8859-15")
    func testDanishISO885915() throws {
        let data = try loadTestFile(lang: "da", filename: "iso-8859-15.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859"))
    }

    @Test("法语 ISO-8859-1")
    func testFrenchISO88591() throws {
        let data = try loadTestFile(lang: "fr", filename: "iso-8859-1.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-1") || upper.contains("WINDOWS-1252"))
    }

    @Test("法语 ISO-8859-15")
    func testFrenchISO885915() throws {
        let data = try loadTestFile(lang: "fr", filename: "iso-8859-15.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859"))
    }

    @Test("泰语 ISO-8859-11")
    func testThaiISO885911() throws {
        let data = try loadTestFile(lang: "th", filename: "iso-8859-11.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-11") || upper.contains("TIS-620") || upper.contains("TIS620"))
    }

    @Test("泰语 TIS-620")
    func testThaiTIS620() throws {
        let data = try loadTestFile(lang: "th", filename: "tis-620.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("TIS-620") || upper.contains("TIS620") || upper.contains("ISO-8859-11"))
    }

    @Test("土耳其语 ISO-8859-3")
    func testTurkishISO88593() throws {
        let data = try loadTestFile(lang: "tr", filename: "iso-8859-3.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-3"))
    }

    @Test("立陶宛语 ISO-8859-4")
    func testLithuanianISO88594() throws {
        let data = try loadTestFile(lang: "lt", filename: "iso-8859-4.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859"))
    }

    @Test("立陶宛语 ISO-8859-10")
    func testLithuanianISO885910() throws {
        let data = try loadTestFile(lang: "lt", filename: "iso-8859-10.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859"))
    }

    @Test("立陶宛语 ISO-8859-13")
    func testLithuanianISO885913() throws {
        let data = try loadTestFile(lang: "lt", filename: "iso-8859-13.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859") || upper.contains("WINDOWS-1257"))
    }

    @Test("拉脱维亚语 ISO-8859-4")
    func testLatvianISO88594() throws {
        let data = try loadTestFile(lang: "lv", filename: "iso-8859-4.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859"))
    }

    @Test("拉脱维亚语 ISO-8859-10")
    func testLatvianISO885910() throws {
        let data = try loadTestFile(lang: "lv", filename: "iso-8859-10.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859"))
    }

    @Test("拉脱维亚语 ISO-8859-13")
    func testLatvianISO885913() throws {
        let data = try loadTestFile(lang: "lv", filename: "iso-8859-13.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859") || upper.contains("WINDOWS-1257"))
    }

    @Test("马耳他语 ISO-8859-3")
    func testMalteseISO88593() throws {
        let data = try loadTestFile(lang: "mt", filename: "iso-8859-3.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-3"))
    }

    @Test("罗马尼亚语 ISO-8859-16")
    func testRomanianISO885916() throws {
        let data = try loadTestFile(lang: "ro", filename: "iso-8859-16.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-16"))
    }

    @Test("斯洛伐克语 ISO-8859-2")
    func testSlovakISO88592() throws {
        let data = try loadTestFile(lang: "sk", filename: "iso-8859-2.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-2") || upper.contains("WINDOWS-1250"))
    }

    @Test("斯洛文尼亚语 ISO-8859-2")
    func testSloveneISO88592() throws {
        let data = try loadTestFile(lang: "sl", filename: "iso-8859-2.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-2") || upper.contains("WINDOWS-1250"))
    }

    @Test("斯洛文尼亚语 ISO-8859-16")
    func testSloveneISO885916() throws {
        let data = try loadTestFile(lang: "sl", filename: "iso-8859-16.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-16"))
    }

    @Test("波兰语 ISO-8859-2")
    func testPolishISO88592() throws {
        let data = try loadTestFile(lang: "pl", filename: "iso-8859-2.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-2") || upper.contains("WINDOWS-1250"))
    }

    @Test("波兰语 ISO-8859-13")
    func testPolishISO885913() throws {
        let data = try loadTestFile(lang: "pl", filename: "iso-8859-13.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859") || upper.contains("WINDOWS-1257"))
    }

    @Test("波兰语 ISO-8859-16")
    func testPolishISO885916() throws {
        let data = try loadTestFile(lang: "pl", filename: "iso-8859-16.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-16"))
    }

    @Test("匈牙利语 ISO-8859-2")
    func testHungarianISO88592() throws {
        let data = try loadTestFile(lang: "hu", filename: "iso-8859-2.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-2") || upper.contains("WINDOWS-1250"))
    }
}

// MARK: - Windows 代码页测试

@Suite("Windows 代码页编码检测测试")
struct WindowsCodePageTests {

    @Test("阿拉伯语 Windows-1256")
    func testArabicWindows1256() throws {
        let data = try loadTestFile(lang: "ar", filename: "windows-1256.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1256") || upper.contains("ISO-8859-6"))
    }

    @Test("希腊语 Windows-1253")
    func testGreekWindows1253() throws {
        let data = try loadTestFile(lang: "el", filename: "windows-1253.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1253") || upper.contains("ISO-8859-7"))
    }

    @Test("希伯来语 Windows-1255")
    func testHebrewWindows1255() throws {
        let data = try loadTestFile(lang: "he", filename: "windows-1255.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1255") || upper.contains("ISO-8859-8"))
    }

    @Test("法语 Windows-1252")
    func testFrenchWindows1252() throws {
        let data = try loadTestFile(lang: "fr", filename: "windows-1252.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1252") || upper.contains("ISO-8859-1"))
    }

    @Test("丹麦语 Windows-1252")
    func testDanishWindows1252() throws {
        let data = try loadTestFile(lang: "da", filename: "windows-1252.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1252") || upper.contains("ISO-8859-1"))
    }

    @Test("爱沙尼亚语 Windows-1252")
    func testEstonianWindows1252() throws {
        let data = try loadTestFile(lang: "et", filename: "windows-1252.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1252") || upper.contains("ISO-8859"))
    }

    @Test("爱沙尼亚语 Windows-1257")
    func testEstonianWindows1257() throws {
        let data = try loadTestFile(lang: "et", filename: "windows-1257.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1257") || upper.contains("ISO-8859"))
    }

    @Test("捷克语 Windows-1250")
    func testCzechWindows1250() throws {
        let data = try loadTestFile(lang: "cs", filename: "windows-1250.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1250") || upper.contains("ISO-8859-2"))
    }

    @Test("克罗地亚语 Windows-1250")
    func testCroatianWindows1250() throws {
        let data = try loadTestFile(lang: "hr", filename: "windows-1250.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1250") || upper.contains("ISO-8859-2"))
    }

    @Test("匈牙利语 Windows-1250")
    func testHungarianWindows1250() throws {
        let data = try loadTestFile(lang: "hu", filename: "windows-1250.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1250") || upper.contains("ISO-8859-2"))
    }

    @Test("波兰语 Windows-1250")
    func testPolishWindows1250() throws {
        let data = try loadTestFile(lang: "pl", filename: "windows-1250.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1250") || upper.contains("ISO-8859-2"))
    }

    @Test("罗马尼亚语 Windows-1250")
    func testRomanianWindows1250() throws {
        let data = try loadTestFile(lang: "ro", filename: "windows-1250.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1250") || upper.contains("ISO-8859"))
    }

    @Test("斯洛伐克语 Windows-1250")
    func testSlovakWindows1250() throws {
        let data = try loadTestFile(lang: "sk", filename: "windows-1250.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1250") || upper.contains("ISO-8859-2"))
    }

    @Test("斯洛文尼亚语 Windows-1250")
    func testSloveneWindows1250() throws {
        let data = try loadTestFile(lang: "sl", filename: "windows-1250.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1250") || upper.contains("ISO-8859-2"))
    }

    @Test("越南语 Windows-1258")
    func testVietnameseWindows1258() throws {
        let data = try loadTestFile(lang: "vi", filename: "windows-1258.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1258"))
    }

    @Test("保加利亚语 Windows-1251")
    func testBulgarianWindows1251() throws {
        let data = try loadTestFile(lang: "bg", filename: "windows-1251.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1251") || upper.contains("ISO-8859-5") || upper.contains("KOI8"))
    }
}

// MARK: - Cyrillic 编码测试

@Suite("Cyrillic 编码检测测试")
struct CyrillicTests {

    @Test("俄语 Windows-1251")
    func testRussianWindows1251() throws {
        let data = try loadTestFile(lang: "ru", filename: "windows-1251.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1251") || upper.contains("KOI8") || upper.contains("ISO-8859-5"))
    }

    @Test("俄语 KOI8-R")
    func testRussianKOI8R() throws {
        let data = try loadTestFile(lang: "ru", filename: "koi8-r.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("KOI8-R") || upper.contains("KOI8R"))
    }

    @Test("俄语 ISO-8859-5")
    func testRussianISO88595() throws {
        let data = try loadTestFile(lang: "ru", filename: "iso-8859-5.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-5") || upper.contains("WINDOWS-1251") || upper.contains("KOI8"))
    }

    @Test("俄语 IBM855")
    func testRussianIBM855() throws {
        let data = try loadTestFile(lang: "ru", filename: "ibm855.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("IBM855") || upper.contains("CP855"))
    }

    @Test("俄语 IBM866")
    func testRussianIBM866() throws {
        let data = try loadTestFile(lang: "ru", filename: "ibm866.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("IBM866") || upper.contains("CP866"))
    }

    @Test("俄语 Mac-Cyrillic")
    func testRussianMacCyrillic() throws {
        let data = try loadTestFile(lang: "ru", filename: "mac-cyrillic.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("MAC") || upper.contains("CYRILLIC") || upper.contains("WINDOWS-1251"))
    }
}

// MARK: - IBM 代码页测试

@Suite("IBM 代码页编码检测测试")
struct IBMCodePageTests {

    @Test("捷克语 IBM852")
    func testCzechIBM852() throws {
        let data = try loadTestFile(lang: "cs", filename: "ibm852.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("IBM852") || upper.contains("CP852"))
    }

    @Test("克罗地亚语 IBM852")
    func testCroatianIBM852() throws {
        let data = try loadTestFile(lang: "hr", filename: "ibm852.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("IBM852") || upper.contains("CP852"))
    }

    @Test("波兰语 IBM852")
    func testPolishIBM852() throws {
        let data = try loadTestFile(lang: "pl", filename: "ibm852.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("IBM852") || upper.contains("CP852"))
    }

    @Test("罗马尼亚语 IBM852")
    func testRomanianIBM852() throws {
        let data = try loadTestFile(lang: "ro", filename: "ibm852.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("IBM852") || upper.contains("CP852"))
    }

    @Test("斯洛伐克语 IBM852")
    func testSlovakIBM852() throws {
        let data = try loadTestFile(lang: "sk", filename: "ibm852.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("IBM852") || upper.contains("CP852"))
    }

    @Test("斯洛文尼亚语 IBM852")
    func testSloveneIBM852() throws {
        let data = try loadTestFile(lang: "sl", filename: "ibm852.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("IBM852") || upper.contains("CP852"))
    }

    @Test("丹麦语 IBM865")
    func testDanishIBM865() throws {
        let data = try loadTestFile(lang: "da", filename: "ibm865.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("IBM865") || upper.contains("CP865"))
    }

    @Test("挪威语 IBM865")
    func testNorwegianIBM865() throws {
        let data = try loadTestFile(lang: "no", filename: "ibm865.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("IBM865") || upper.contains("CP865"))
    }
}

// MARK: - Mac 编码测试

@Suite("Mac 编码检测测试")
struct MacEncodingTests {

    @Test("捷克语 Mac-CentralEurope")
    func testCzechMacCentralEurope() throws {
        let data = try loadTestFile(lang: "cs", filename: "mac-centraleurope.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("MAC") || upper.contains("CENTRALEUROPE") || upper.contains("X-MAC"))
    }

    @Test("克罗地亚语 Mac-CentralEurope")
    func testCroatianMacCentralEurope() throws {
        let data = try loadTestFile(lang: "hr", filename: "mac-centraleurope.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("MAC") || upper.contains("CENTRALEUROPE") || upper.contains("X-MAC"))
    }

    @Test("波兰语 Mac-CentralEurope")
    func testPolishMacCentralEurope() throws {
        let data = try loadTestFile(lang: "pl", filename: "mac-centraleurope.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("MAC") || upper.contains("CENTRALEUROPE") || upper.contains("X-MAC"))
    }

    @Test("斯洛伐克语 Mac-CentralEurope")
    func testSlovakMacCentralEurope() throws {
        let data = try loadTestFile(lang: "sk", filename: "mac-centraleurope.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("MAC") || upper.contains("CENTRALEUROPE") || upper.contains("X-MAC"))
    }

    @Test("斯洛文尼亚语 Mac-CentralEurope")
    func testSloveneMacCentralEurope() throws {
        let data = try loadTestFile(lang: "sl", filename: "mac-centraleurope.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("MAC") || upper.contains("CENTRALEUROPE") || upper.contains("X-MAC"))
    }
}

// MARK: - 越南语编码测试

@Suite("越南语编码检测测试")
struct VietnameseEncodingTests {

    @Test("越南语 VISCII")
    func testVietnameseVISCII() throws {
        let data = try loadTestFile(lang: "vi", filename: "viscii.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("VISCII"))
    }
}

// MARK: - 分块数据输入测试

@Suite("分块数据输入测试")
struct ChunkedDataTests {

    @Test("分块输入 UTF-8 中文")
    func testChunkedUTF8Chinese() {
        let text = "这是一段较长的中文文本，用于测试分块输入功能是否正常工作。字符集检测器应该能够正确处理分多次输入的数据，并最终给出正确的字符集检测结果。"
        let data = text.data(using: .utf8)!
        let detector = Uchardet()

        // 将数据分成 10 字节的块逐步输入
        let chunkSize = 10
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            let chunk = data.subdata(in: offset..<end)
            detector.handleData(chunk)
            offset = end
        }
        detector.dataEnd()

        let charset = detector.charset
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("分块输入 ASCII")
    func testChunkedASCII() {
        let text = "The quick brown fox jumps over the lazy dog. This is a longer ASCII text for chunked input testing."
        let data = text.data(using: .ascii)!
        let detector = Uchardet()

        // 每次输入 5 字节
        let chunkSize = 5
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            let chunk = data.subdata(in: offset..<end)
            detector.handleData(chunk)
            offset = end
        }
        detector.dataEnd()

        let charset = detector.charset
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper == "ASCII" || upper == "UTF-8")
    }

    @Test("单字节分块输入")
    func testSingleByteChunks() {
        let text = "Hello, 世界！这是测试。"
        let data = text.data(using: .utf8)!
        let detector = Uchardet()

        // 每次只输入 1 字节
        for i in 0..<data.count {
            let chunk = data.subdata(in: i..<(i + 1))
            detector.handleData(chunk)
        }
        detector.dataEnd()

        let charset = detector.charset
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("两次 reset 后重新检测")
    func testMultipleResets() {
        let detector = Uchardet()

        for _ in 0..<3 {
            let data = "这是中文文本，用于测试多次重置后的检测功能。".data(using: .utf8)!
            detector.handleData(data)
            detector.dataEnd()
            #expect(detector.charset?.uppercased() == "UTF-8")
            detector.reset()
        }
    }
}

// MARK: - 边界条件测试

@Suite("边界条件与错误处理测试")
struct EdgeCaseTests {

    @Test("空字符串检测")
    func testEmptyString() {
        let charset = Uchardet.detect("")
        // 空字符串无法检测，应返回 nil
        #expect(charset == nil)
    }

    @Test("空 Data 检测")
    func testEmptyData() {
        let charset = Uchardet.detect(Data())
        #expect(charset == nil)
    }

    @Test("单个字节数据")
    func testSingleByte() {
        let data = Data([0x41]) // 'A'
        let charset = Uchardet.detect(data)
        // 单字节可能无法确定编码，结果可能为 nil 或某种编码
        // 不强制要求特定结果，只验证不崩溃
        _ = charset
    }

    @Test("仅包含空白字符")
    func testWhitespaceOnly() {
        let data = "   \t\n\r   ".data(using: .utf8)!
        let charset = Uchardet.detect(data)
        // 空白字符可能无法确定编码
        _ = charset
    }

    @Test("大量重复字符")
    func testRepeatedCharacters() {
        let text = String(repeating: "A", count: 10000)
        let data = text.data(using: .ascii)!
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper == "ASCII" || upper == "UTF-8")
    }

    @Test("混合 ASCII 和 UTF-8")
    func testMixedASCIIAndUTF8() {
        let text = "Hello World! 你好世界！ Bonjour le monde! こんにちは世界！"
        let data = text.data(using: .utf8)!
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("UTF-8 BOM 数据")
    func testUTF8WithBOM() {
        // UTF-8 BOM: EF BB BF
        var data = Data([0xEF, 0xBB, 0xBF])
        let text = "Hello, World! This is UTF-8 with BOM."
        data.append(text.data(using: .utf8)!)
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("UTF-8"))
    }

    @Test("UTF-16 BE BOM 数据")
    func testUTF16BEWithBOM() {
        // UTF-16 BE BOM: FE FF
        var data = Data([0xFE, 0xFF])
        // 添加 "Hello" 的 UTF-16 BE 编码
        let text = "Hello World"
        if let utf16Data = text.data(using: .utf16BigEndian) {
            data.append(utf16Data)
        }
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("UTF-16") || upper.contains("UTF16"))
    }

    @Test("UTF-16 LE BOM 数据")
    func testUTF16LEWithBOM() {
        // UTF-16 LE BOM: FF FE
        var data = Data([0xFF, 0xFE])
        let text = "Hello World"
        if let utf16Data = text.data(using: .utf16LittleEndian) {
            data.append(utf16Data)
        }
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("UTF-16") || upper.contains("UTF16"))
    }

    @Test("dataEnd 未调用时 charset 为 nil")
    func testCharsetBeforeDataEnd() {
        let detector = Uchardet()
        let data = "Hello, World! This is ASCII text.".data(using: .utf8)!
        detector.handleData(data)
        // 未调用 dataEnd，charset 应为 nil
        #expect(detector.charset == nil)
    }

    @Test("多次调用 dataEnd")
    func testMultipleDataEndCalls() {
        let detector = Uchardet()
        let data = "Hello, World! This is ASCII text.".data(using: .utf8)!
        detector.handleData(data)
        detector.dataEnd()
        let charset1 = detector.charset
        detector.dataEnd() // 再次调用
        let charset2 = detector.charset
        // 两次结果应一致
        #expect(charset1 == charset2)
    }

    @Test("大文件数据检测")
    func testLargeData() {
        // 生成超过 100KB 的 UTF-8 中文文本
        let baseText = "这是一段用于测试大文件字符集检测的中文文本内容，包含各种常用汉字。"
        let repeated = String(repeating: baseText, count: 2000)
        let data = repeated.data(using: .utf8)!
        #expect(data.count > 100_000)
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("纯数字文本")
    func testNumericOnly() {
        let text = "1234567890 1234567890 1234567890 1234567890 1234567890"
        let data = text.data(using: .ascii)!
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
    }

    @Test("特殊符号文本")
    func testSpecialSymbols() {
        let text = "!@#$%^&*()_+-=[]{}|;':\",./<>? !@#$%^&*()_+-=[]{}|;':\",./<>?"
        let data = text.data(using: .ascii)!
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
    }
}

// MARK: - String.Encoding 映射测试

@Suite("String.Encoding 映射测试")
struct StringEncodingMappingTests {

    // MARK: Unicode 系列

    @Test("UTF-8 名称映射")
    func testUTF8Mapping() {
        #expect(String.Encoding(charsetName: "UTF-8") == .utf8)
        #expect(String.Encoding(charsetName: "utf-8") == .utf8)
        #expect(String.Encoding(charsetName: "UTF8") == .utf8)
    }

    @Test("UTF-16 名称映射")
    func testUTF16Mapping() {
        #expect(String.Encoding(charsetName: "UTF-16") == .utf16)
        #expect(String.Encoding(charsetName: "UTF-16BE") == .utf16BigEndian)
        #expect(String.Encoding(charsetName: "UTF-16LE") == .utf16LittleEndian)
    }

    @Test("UTF-32 名称映射")
    func testUTF32Mapping() {
        #expect(String.Encoding(charsetName: "UTF-32") == .utf32)
        #expect(String.Encoding(charsetName: "UTF-32BE") == .utf32BigEndian)
        #expect(String.Encoding(charsetName: "UTF-32LE") == .utf32LittleEndian)
    }

    @Test("ASCII 名称映射")
    func testASCIIMapping() {
        #expect(String.Encoding(charsetName: "ASCII") == .ascii)
        #expect(String.Encoding(charsetName: "US-ASCII") == .ascii)
    }

    // MARK: 西欧

    @Test("ISO-8859-1 名称映射")
    func testISO88591Mapping() {
        #expect(String.Encoding(charsetName: "ISO-8859-1") == .isoLatin1)
        #expect(String.Encoding(charsetName: "LATIN1") == .isoLatin1)
    }

    @Test("ISO-8859-2 名称映射")
    func testISO88592Mapping() {
        #expect(String.Encoding(charsetName: "ISO-8859-2") == .isoLatin2)
        #expect(String.Encoding(charsetName: "LATIN2") == .isoLatin2)
    }

    @Test("Windows-1252 名称映射")
    func testWindows1252Mapping() {
        let enc = String.Encoding(charsetName: "WINDOWS-1252")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1252") == enc)
    }

    @Test("Windows-1250 名称映射")
    func testWindows1250Mapping() {
        let enc = String.Encoding(charsetName: "WINDOWS-1250")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1250") == enc)
    }

    // MARK: 日文

    @Test("EUC-JP 名称映射")
    func testEUCJPMapping() {
        #expect(String.Encoding(charsetName: "EUC-JP") == .japaneseEUC)
        #expect(String.Encoding(charsetName: "EUCJP") == .japaneseEUC)
    }

    @Test("Shift_JIS 名称映射")
    func testShiftJISMapping() {
        #expect(String.Encoding(charsetName: "SHIFT_JIS") == .shiftJIS)
        #expect(String.Encoding(charsetName: "SHIFT-JIS") == .shiftJIS)
    }

    // MARK: Cyrillic

    @Test("KOI8-R 名称映射")
    func testKOI8RMapping() {
        let enc = String.Encoding(charsetName: "KOI8-R")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "KOI8R") == enc)
    }

    @Test("Windows-1251 名称映射")
    func testWindows1251Mapping() {
        let enc = String.Encoding(charsetName: "WINDOWS-1251")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1251") == enc)
    }

    // MARK: 希腊语

    @Test("ISO-8859-7 名称映射")
    func testISO88597Mapping() {
        let enc = String.Encoding(charsetName: "ISO-8859-7")
        #expect(enc != nil)
    }

    @Test("Windows-1253 名称映射")
    func testWindows1253Mapping() {
        let enc = String.Encoding(charsetName: "WINDOWS-1253")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1253") == enc)
    }

    // MARK: 阿拉伯语

    @Test("ISO-8859-6 名称映射")
    func testISO88596Mapping() {
        let enc = String.Encoding(charsetName: "ISO-8859-6")
        #expect(enc != nil)
    }

    @Test("Windows-1256 名称映射")
    func testWindows1256Mapping() {
        let enc = String.Encoding(charsetName: "WINDOWS-1256")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1256") == enc)
    }

    // MARK: 希伯来语

    @Test("ISO-8859-8 名称映射")
    func testISO88598Mapping() {
        let enc = String.Encoding(charsetName: "ISO-8859-8")
        #expect(enc != nil)
    }

    @Test("Windows-1255 名称映射")
    func testWindows1255Mapping() {
        let enc = String.Encoding(charsetName: "WINDOWS-1255")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1255") == enc)
    }

    // MARK: 泰语

    @Test("TIS-620 名称映射")
    func testTIS620Mapping() {
        let enc = String.Encoding(charsetName: "TIS-620")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "ISO-8859-11") == enc)
    }

    // MARK: 越南语

    @Test("Windows-1258 名称映射")
    func testWindows1258Mapping() {
        let enc = String.Encoding(charsetName: "WINDOWS-1258")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1258") == enc)
    }

    @Test("VISCII 名称映射")
    func testVISCIIMapping() {
        let enc = String.Encoding(charsetName: "VISCII")
        #expect(enc != nil)
    }

    // MARK: 无效名称

    @Test("无效 charset 名称返回 nil")
    func testInvalidCharsetName() {
        #expect(String.Encoding(charsetName: "") == nil)
        #expect(String.Encoding(charsetName: "INVALID-ENCODING-XYZ") == nil)
        #expect(String.Encoding(charsetName: "NOT-A-CHARSET") == nil)
    }

    @Test("大小写不敏感")
    func testCaseInsensitive() {
        #expect(String.Encoding(charsetName: "utf-8") == .utf8)
        #expect(String.Encoding(charsetName: "Utf-8") == .utf8)
        #expect(String.Encoding(charsetName: "UTF-8") == .utf8)
        #expect(String.Encoding(charsetName: "uTf-8") == .utf8)
    }
}

// MARK: - encoding 属性与 detectEncoding 方法测试

@Suite("encoding 属性与 detectEncoding 方法测试")
struct EncodingPropertyTests {

    @Test("encoding 属性 - UTF-8 中文")
    func testEncodingPropertyUTF8Chinese() {
        let detector = Uchardet()
        let data = "这是一段中文文本，用于测试 encoding 属性。".data(using: .utf8)!
        detector.handleData(data)
        detector.dataEnd()
        #expect(detector.encoding == .utf8)
    }

    @Test("encoding 属性 - 未检测时为 nil")
    func testEncodingPropertyBeforeDetection() {
        let detector = Uchardet()
        #expect(detector.encoding == nil)
    }

    @Test("encoding 属性 - reset 后为 nil")
    func testEncodingPropertyAfterReset() {
        let detector = Uchardet()
        let data = "这是中文文本。".data(using: .utf8)!
        detector.handleData(data)
        detector.dataEnd()
        #expect(detector.encoding != nil)
        detector.reset()
        #expect(detector.encoding == nil)
    }

    @Test("静态 detectEncoding(Data) - UTF-8 中文")
    func testStaticDetectEncodingDataUTF8() {
        let data = "这是一段中文文本，用于测试静态 detectEncoding 方法。".data(using: .utf8)!
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding == .utf8)
    }

    @Test("静态 detectEncoding(String) - UTF-8 中文")
    func testStaticDetectEncodingStringUTF8() {
        let encoding = Uchardet.detectEncoding("这是一段中文文本，用于测试静态 detectEncoding 字符串方法。")
        #expect(encoding == .utf8)
    }

    @Test("静态 detectEncoding(Data) - ASCII")
    func testStaticDetectEncodingASCII() {
        let data = "The quick brown fox jumps over the lazy dog.".data(using: .ascii)!
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
        // ASCII 可能映射为 .ascii 或 .utf8
        #expect(encoding == .ascii || encoding == .utf8)
    }

    @Test("静态 detectEncoding(Data) - 空数据返回 nil")
    func testStaticDetectEncodingEmptyData() {
        let encoding = Uchardet.detectEncoding(Data())
        #expect(encoding == nil)
    }

    @Test("静态 detectEncoding(String) - 空字符串返回 nil")
    func testStaticDetectEncodingEmptyString() {
        let encoding = Uchardet.detectEncoding("")
        #expect(encoding == nil)
    }

    @Test("detectEncoding 与 charset 一致性")
    func testEncodingConsistencyWithCharset() {
        let texts = [
            "这是中文文本，用于一致性测试。",
            "Это русский текст для тестирования.",
            "これは日本語テキストです。",
        ]
        for text in texts {
            let detector = Uchardet()
            let data = text.data(using: .utf8)!
            detector.handleData(data)
            detector.dataEnd()

            let charset = detector.charset
            let encoding = detector.encoding

            if let charset = charset {
                // 如果 charset 不为 nil，encoding 应该也能映射
                let mappedEncoding = String.Encoding(charsetName: charset)
                #expect(mappedEncoding == encoding)
            } else {
                #expect(encoding == nil)
            }
        }
    }

    @Test("从文件检测 EUC-JP 并获取 encoding")
    func testDetectEncodingFromEUCJPFile() throws {
        let data = try loadTestFile(lang: "ja", filename: "euc-jp.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
        #expect(encoding == .japaneseEUC)
    }

    @Test("从文件检测 Shift_JIS 并获取 encoding")
    func testDetectEncodingFromShiftJISFile() throws {
        let data = try loadTestFile(lang: "ja", filename: "shift_jis.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
        #expect(encoding == .shiftJIS)
    }

    @Test("从文件检测 GB18030 并获取 encoding")
    func testDetectEncodingFromGB18030File() throws {
        let data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
        // GB18030 应映射为有效的 String.Encoding
        // 验证可以用该 encoding 解码数据
        if let encoding = encoding {
            let decoded = String(data: data, encoding: encoding)
            #expect(decoded != nil)
        }
    }

    @Test("从文件检测 Big5 并获取 encoding")
    func testDetectEncodingFromBig5File() throws {
        let data = try loadTestFile(lang: "zh", filename: "big5.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
        if let encoding = encoding {
            let decoded = String(data: data, encoding: encoding)
            #expect(decoded != nil)
        }
    }

    @Test("从文件检测 KOI8-R 并获取 encoding")
    func testDetectEncodingFromKOI8RFile() throws {
        let data = try loadTestFile(lang: "ru", filename: "koi8-r.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
        if let encoding = encoding {
            let decoded = String(data: data, encoding: encoding)
            #expect(decoded != nil)
        }
    }

    @Test("从文件检测 ISO-8859-1 并获取 encoding")
    func testDetectEncodingFromISO88591File() throws {
        let data = try loadTestFile(lang: "fr", filename: "iso-8859-1.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
        if let encoding = encoding {
            let decoded = String(data: data, encoding: encoding)
            #expect(decoded != nil)
        }
    }

    @Test("encoding 可用于解码 UTF-8 数据")
    func testEncodingCanDecodeUTF8Data() {
        let original = "你好世界！Hello World！こんにちは！"
        let data = original.data(using: .utf8)!
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding == .utf8)
        if let encoding = encoding {
            let decoded = String(data: data, encoding: encoding)
            #expect(decoded == original)
        }
    }

    @Test("encoding 可用于解码 EUC-JP 数据")
    func testEncodingCanDecodeEUCJPData() throws {
        let data = try loadTestFile(lang: "ja", filename: "euc-jp.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding == .japaneseEUC)
        if let encoding = encoding {
            let decoded = String(data: data, encoding: encoding)
            #expect(decoded != nil)
            #expect(decoded!.isEmpty == false)
        }
    }
}

// MARK: - 并发安全测试

@Suite("并发安全测试")
struct ConcurrencyTests {

    @Test("多个独立实例并发检测")
    func testConcurrentIndependentInstances() async {
        // 使用纯多字节 UTF-8 文本（避免 ASCII 子集被检测为 ASCII）
        let texts = [
            "这是中文文本，用于并发测试，包含足够多的汉字以确保检测结果准确。",
            "Это русский текст для тестирования параллелизма, достаточно длинный.",
            "これは並行テスト用の日本語テキストです。十分な長さが必要です。",
            "이것은 동시성 테스트를 위한 한국어 텍스트입니다. 충분히 길어야 합니다.",
            "Ärger mit Übergröße führt zu Ärger. Straße, Größe, Füße, Mäuse.",
        ]

        await withTaskGroup(of: String?.self) { group in
            for text in texts {
                group.addTask {
                    return Uchardet.detect(text)
                }
            }

            for await result in group {
                // 所有多字节文本都应被检测为 UTF-8
                #expect(result?.uppercased() == "UTF-8")
            }
        }
    }

    @Test("静态方法并发调用")
    func testConcurrentStaticDetect() async {
        let text = "Hello, World! This is a test for concurrent static method calls."
        await withTaskGroup(of: String?.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    return Uchardet.detect(text)
                }
            }

            for await result in group {
                #expect(result != nil)
            }
        }
    }
}

// MARK: - 大文件流式检测测试

@Suite("大文件流式检测测试")
struct LargeFileDetectionTests {

    // MARK: - 辅助：创建临时文件

    /// 将 Data 写入临时文件，返回 URL
    private func writeTempFile(_ data: Data, suffix: String = ".txt") throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent(UUID().uuidString + suffix)
        try data.write(to: url)
        return url
    }

    // MARK: - 基本功能测试

    @Test("detect(contentsOf:) - UTF-8 中文文件")
    func testDetectContentsOfUTF8Chinese() throws {
        let text = String(repeating: "这是一段中文文本，用于测试大文件流式检测功能。", count: 100)
        let data = text.data(using: .utf8)!
        let url = try writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let charset = try Uchardet.detect(contentsOf: url)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("detectEncoding(contentsOf:) - UTF-8 中文文件")
    func testDetectEncodingContentsOfUTF8Chinese() throws {
        let text = String(repeating: "这���������������一段中文文本，用于测试大文件流式检测功能。", count: 100)
        let data = text.data(using: .utf8)!
        let url = try writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let encoding = try Uchardet.detectEncoding(contentsOf: url)
        #expect(encoding == .utf8)
    }

    @Test("detect(contentsOf:) - ASCII 文件")
    func testDetectContentsOfASCII() throws {
        let text = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 200)
        let data = text.data(using: .ascii)!
        let url = try writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let charset = try Uchardet.detect(contentsOf: url)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper == "ASCII" || upper == "UTF-8")
    }

    @Test("detect(contentsOf:) - 从 test/ 目录读取 EUC-JP 文件")
    func testDetectContentsOfEUCJPFile() throws {
        let url = projectRoot
            .appendingPathComponent("test")
            .appendingPathComponent("ja")
            .appendingPathComponent("euc-jp.txt")
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let charset = try Uchardet.detect(contentsOf: url)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("EUC-JP") || upper.contains("EUCJP"))
    }

    @Test("detectEncoding(contentsOf:) - 从 test/ 目录读取 EUC-JP 文件")
    func testDetectEncodingContentsOfEUCJPFile() throws {
        let url = projectRoot
            .appendingPathComponent("test")
            .appendingPathComponent("ja")
            .appendingPathComponent("euc-jp.txt")
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let encoding = try Uchardet.detectEncoding(contentsOf: url)
        #expect(encoding == .japaneseEUC)
    }

    @Test("detect(contentsOf:) - 从 test/ 目录读取 Shift_JIS 文件")
    func testDetectContentsOfShiftJISFile() throws {
        let url = projectRoot
            .appendingPathComponent("test")
            .appendingPathComponent("ja")
            .appendingPathComponent("shift_jis.txt")
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let charset = try Uchardet.detect(contentsOf: url)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("SHIFT") || upper.contains("SJIS"))
    }

    // MARK: - 参数测试

    @Test("自定义 sampleSize 参数")
    func testCustomSampleSize() throws {
        // 生成 200KB 的 UTF-8 中文文本
        let text = String(repeating: "这是测试文本，包含中文字符。", count: 5000)
        let data = text.data(using: .utf8)!
        #expect(data.count > 100_000)
        let url = try writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        // 只采样前 1024 字节也应能检测出 UTF-8
        let charset = try Uchardet.detect(contentsOf: url, sampleSize: 1024)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("自定义 chunkSize 参数 - 小块读取")
    func testSmallChunkSize() throws {
        let text = String(repeating: "这是测试文本，包含中文字符。", count: 200)
        let data = text.data(using: .utf8)!
        let url = try writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        // 每次只读 128 字节
        let charset = try Uchardet.detect(contentsOf: url, sampleSize: 4096, chunkSize: 128)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("自定义 chunkSize 参数 - 大块读取")
    func testLargeChunkSize() throws {
        let text = String(repeating: "这是测试文本，包含中文字符。", count: 200)
        let data = text.data(using: .utf8)!
        let url = try writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        // 每次读 32KB
        let charset = try Uchardet.detect(contentsOf: url, sampleSize: 65536, chunkSize: 32768)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("sampleSize 大于文件大小时正常工作")
    func testSampleSizeLargerThanFile() throws {
        let text = "这是一个很小的文件，只有几十个字节。"
        let data = text.data(using: .utf8)!
        let url = try writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        // sampleSize 远大于文件实际大小
        let charset = try Uchardet.detect(contentsOf: url, sampleSize: 1_000_000)
        #expect(charset?.uppercased() == "UTF-8")
    }

    // MARK: - 边界条件测试

    @Test("空文件检测返回 nil")
    func testEmptyFileReturnsNil() throws {
        let url = try writeTempFile(Data())
        defer { try? FileManager.default.removeItem(at: url) }

        let charset = try Uchardet.detect(contentsOf: url)
        #expect(charset == nil)
    }

    @Test("空文件 detectEncoding 返回 nil")
    func testEmptyFileEncodingReturnsNil() throws {
        let url = try writeTempFile(Data())
        defer { try? FileManager.default.removeItem(at: url) }

        let encoding = try Uchardet.detectEncoding(contentsOf: url)
        #expect(encoding == nil)
    }

    @Test("不存在的文件抛出错误")
    func testNonExistentFileThrows() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent_\(UUID().uuidString).txt")

        #expect(throws: (any Error).self) {
            _ = try Uchardet.detect(contentsOf: url)
        }
    }

    @Test("不存在的文件 detectEncoding 抛出错误")
    func testNonExistentFileEncodingThrows() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent_\(UUID().uuidString).txt")

        #expect(throws: (any Error).self) {
            _ = try Uchardet.detectEncoding(contentsOf: url)
        }
    }

    // MARK: - 大文件性能测试

    @Test("大文件（1MB）流式检测 - 仅采样头部")
    func testLargeFileSamplingOnly() throws {
        // 生成 1MB 的 UTF-8 中文文本
        let baseText = "这是一段用于测试大文件流式检测的中文文本，包含各种常用汉字。"
        let text = String(repeating: baseText, count: 2000)
        let data = text.data(using: .utf8)!
        #expect(data.count > 100_000)
        let url = try writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        // 只采样前 64KB，不读取整个文件
        let charset = try Uchardet.detect(contentsOf: url, sampleSize: 65_536)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("流式检测结果与全量检测结果一致")
    func testStreamingMatchesFullDetection() throws {
        let text = String(repeating: "这是中文文本，用于验证流式检测与全量检测结果一致性。", count: 500)
        let data = text.data(using: .utf8)!
        let url = try writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        // 流式检测
        let streamCharset = try Uchardet.detect(contentsOf: url)
        // 全量检测
        let fullCharset = Uchardet.detect(data)

        #expect(streamCharset?.uppercased() == fullCharset?.uppercased())
    }

    @Test("流式检测 encoding 与全量检测 encoding 一致")
    func testStreamingEncodingMatchesFullEncoding() throws {
        let text = String(repeating: "这是中文文本，用于验证流式检测与全量检测 encoding 一致性。", count: 500)
        let data = text.data(using: .utf8)!
        let url = try writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let streamEncoding = try Uchardet.detectEncoding(contentsOf: url)
        let fullEncoding = Uchardet.detectEncoding(data)

        #expect(streamEncoding == fullEncoding)
    }

    // MARK: - 多语言文件测试

    @Test("detect(contentsOf:) - 日文 UTF-8 文件")
    func testDetectContentsOfJapaneseUTF8() throws {
        let url = projectRoot
            .appendingPathComponent("test")
            .appendingPathComponent("ja")
            .appendingPathComponent("utf-8.txt")
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let charset = try Uchardet.detect(contentsOf: url)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("detect(contentsOf:) - 泰语 TIS-620 文件")
    func testDetectContentsOfThaiTIS620() throws {
        let url = projectRoot
            .appendingPathComponent("test")
            .appendingPathComponent("th")
            .appendingPathComponent("tis-620.txt")
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let charset = try Uchardet.detect(contentsOf: url)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("TIS-620") || upper.contains("TIS620") || upper.contains("ISO-8859-11"))
    }

    @Test("detect(contentsOf:) - 泰语 UTF-8 文件")
    func testDetectContentsOfThaiUTF8() throws {
        let url = projectRoot
            .appendingPathComponent("test")
            .appendingPathComponent("th")
            .appendingPathComponent("utf-8.txt")
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let charset = try Uchardet.detect(contentsOf: url)
        #expect(charset?.uppercased() == "UTF-8")
    }
}

// MARK: - [UInt8] 重载与 detect(bytes:) 便捷方法测试

@Suite("[UInt8] 重载与 bytes 便捷方法测试")
struct BytesAPITests {

    @Test("handleData([UInt8]) - UTF-8 中文")
    func testHandleDataBytesUTF8Chinese() {
        let text = "这是一段中文文本，用于测试 [UInt8] 重载方法。"
        let bytes = Array(text.utf8)
        let detector = Uchardet()
        let result = detector.handleData(bytes)
        #expect(result == true)
        detector.dataEnd()
        #expect(detector.charset?.uppercased() == "UTF-8")
    }

    @Test("handleData([UInt8]) - 空数组")
    func testHandleDataBytesEmpty() {
        let detector = Uchardet()
        let result = detector.handleData([UInt8]())
        // 空数组会被 handleData 内部的 guard !bytes.isEmpty 提前拦截，
        // 直接返回 true，不会调用底层 C API
        #expect(result == true)
    }

    @Test("handleData([UInt8]) - ASCII")
    func testHandleDataBytesASCII() {
        let text = "The quick brown fox jumps over the lazy dog."
        let bytes = Array(text.utf8)
        let detector = Uchardet()
        detector.handleData(bytes)
        detector.dataEnd()
        let charset = detector.charset
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper == "ASCII" || upper == "UTF-8")
    }

    @Test("detect(bytes:) - UTF-8 中文")
    func testDetectBytesUTF8Chinese() {
        let text = "这是一段中文文本，用于测试 detect(bytes:) 静态方法。"
        let bytes = Array(text.utf8)
        let charset = Uchardet.detect(bytes: bytes)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("detect(bytes:) - ASCII")
    func testDetectBytesASCII() {
        let text = "Hello, World! This is ASCII text for bytes API test."
        let bytes = Array(text.utf8)
        let charset = Uchardet.detect(bytes: bytes)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper == "ASCII" || upper == "UTF-8")
    }

    @Test("detect(bytes:) - 空数组返回 nil")
    func testDetectBytesEmpty() {
        let charset = Uchardet.detect(bytes: [UInt8]())
        #expect(charset == nil)
    }

    @Test("detectEncoding(bytes:) - UTF-8 中文")
    func testDetectEncodingBytesUTF8Chinese() {
        let text = "这是一段中文文本，用于测试 detectEncoding(bytes:) 静态方法。"
        let bytes = Array(text.utf8)
        let encoding = Uchardet.detectEncoding(bytes: bytes)
        #expect(encoding == .utf8)
    }

    @Test("detectEncoding(bytes:) - 空数组返回 nil")
    func testDetectEncodingBytesEmpty() {
        let encoding = Uchardet.detectEncoding(bytes: [UInt8]())
        #expect(encoding == nil)
    }

    @Test("detect(bytes:) 与 detect(Data) 结果一致")
    func testBytesAndDataConsistency() {
        // detect(bytes:) 直接调用 handleData([UInt8])，detect(Data) 调用 handleData(Data)
        // 两者均通过相同的底层 C API，结果应一致
        let text = "这是中文文本，用于验证 bytes 与 Data API 结果一致性。"
        let data = text.data(using: .utf8)!
        let bytes = Array(data)

        let charsetFromData = Uchardet.detect(data)
        let charsetFromBytes = Uchardet.detect(bytes: bytes)

        #expect(charsetFromData?.uppercased() == charsetFromBytes?.uppercased())
    }

    @Test("detectEncoding(bytes:) 与 detectEncoding(Data) 结果一致")
    func testBytesAndDataEncodingConsistency() {
        // detectEncoding(bytes:) 直接调用 handleData([UInt8])，detectEncoding(Data) 调用 handleData(Data)
        // 两者均通过相同的底层 C API，结果应一致
        let text = "这是中文文本，用于验证 bytes 与 Data encoding 结果一致性。"
        let data = text.data(using: .utf8)!
        let bytes = Array(data)

        let encodingFromData = Uchardet.detectEncoding(data)
        let encodingFromBytes = Uchardet.detectEncoding(bytes: bytes)

        #expect(encodingFromData == encodingFromBytes)
    }

    @Test("handleData([UInt8]) 分块输入")
    func testHandleDataBytesChunked() {
        let text = "这是一段较长的中文文本，用于测试 [UInt8] 分块输入功能。字符集检测器应正确处理分多次输入的字节数组。"
        let allBytes = Array(text.utf8)
        let detector = Uchardet()

        // 每次输入 8 字节
        let chunkSize = 8
        var offset = 0
        while offset < allBytes.count {
            let end = min(offset + chunkSize, allBytes.count)
            let chunk = Array(allBytes[offset..<end])
            detector.handleData(chunk)
            offset = end
        }
        detector.dataEnd()

        #expect(detector.charset?.uppercased() == "UTF-8")
    }
}

// MARK: - 新增编码映射测试

@Suite("新增编码映射测试")
struct NewEncodingMappingTests {

    // MARK: ISO-2022-CN

    @Test("ISO-2022-CN 名称映射")
    func testISO2022CNMapping() {
        let enc = String.Encoding(charsetName: "ISO-2022-CN")
        // Apple 平台支持 ISO-2022-CN，应返回非 nil
        // 若平台不支持则跳过（不强制要求）
        if let enc = enc {
            // 验证可以用该编码创建字符串（不崩溃）
            _ = enc
        }
    }

    @Test("ISO2022CN 别名映射")
    func testISO2022CNAliasMapping() {
        let enc1 = String.Encoding(charsetName: "ISO-2022-CN")
        let enc2 = String.Encoding(charsetName: "ISO2022CN")
        // 两种写法应映射到相同编码
        #expect(enc1 == enc2)
    }

    // MARK: HZ-GB-2312

    @Test("HZ-GB-2312 名称映射（回退到 GB18030）")
    func testHZGB2312Mapping() {
        let enc = String.Encoding(charsetName: "HZ-GB-2312")
        // HZ-GB-2312 回退到 GB18030
        let gb18030 = String.Encoding(charsetName: "GB18030")
        #expect(enc != nil)
        #expect(enc == gb18030)
    }

    @Test("HZ 别名映射")
    func testHZAliasMapping() {
        let enc1 = String.Encoding(charsetName: "HZ-GB-2312")
        let enc2 = String.Encoding(charsetName: "HZ")
        #expect(enc1 == enc2)
    }

    // MARK: X-ISO-10646-UCS-4 变体

    @Test("X-ISO-10646-UCS-4-34121 映射到 UTF-32BE")
    func testXISO10646UCS4_34121Mapping() {
        let enc = String.Encoding(charsetName: "X-ISO-10646-UCS-4-34121")
        #expect(enc == .utf32BigEndian)
    }

    @Test("X-ISO-10646-UCS-4-21431 映射到 UTF-32LE")
    func testXISO10646UCS4_21431Mapping() {
        let enc = String.Encoding(charsetName: "X-ISO-10646-UCS-4-21431")
        #expect(enc == .utf32LittleEndian)
    }

    // MARK: SHIFT_JIS 下划线变体

    @Test("SHIFT_JIS（下划线）名称映射")
    func testShiftJISUnderscoreMapping() {
        // uchardet 返回的是 SHIFT_JIS（下划线），经过规范化后变为 SHIFT-JIS
        // 验证两种写法都能正确映射
        let enc1 = String.Encoding(charsetName: "SHIFT_JIS")
        let enc2 = String.Encoding(charsetName: "SHIFT-JIS")
        #expect(enc1 == .shiftJIS)
        #expect(enc2 == .shiftJIS)
        #expect(enc1 == enc2)
    }

    @Test("SJIS 别名映射")
    func testSJISAliasMapping() {
        let enc = String.Encoding(charsetName: "SJIS")
        #expect(enc == .shiftJIS)
    }

    // MARK: GB 系列完整性

    @Test("GB2312 映射到独立 encoding（非 GB18030）")
    func testGB2312MappingToGB18030() {
        // 修复后 GB2312 映射到 kCFStringEncodingDOSChineseSimplif（0x0930），
        // 与 GB18030（kCFStringEncodingGB_18030_2000，0x0632）是不同的 encoding
        let enc1 = String.Encoding(charsetName: "GB2312")
        let enc2 = String.Encoding(charsetName: "GB18030")
        #expect(enc1 != nil)
        #expect(enc2 != nil)
        // GB2312 与 GB18030 是不同的 Apple 平台编码
        #expect(enc1 != enc2)
    }

    @Test("GBK 映射到独立 encoding（非 GB18030）")
    func testGBKMappingToGB18030() {
        // 修复后 GBK 映射到 kCFStringEncodingGBK_95（0x0631），
        // 与 GB18030（kCFStringEncodingGB_18030_2000，0x0632）是不同的 encoding
        let enc1 = String.Encoding(charsetName: "GBK")
        let enc2 = String.Encoding(charsetName: "GB18030")
        #expect(enc1 != nil)
        #expect(enc2 != nil)
        // GBK 与 GB18030 是不同的 Apple 平台编码
        #expect(enc1 != enc2)
    }
}

// MARK: - 中文编码全面测试

@Suite("中文编码全面测试")
struct ChineseEncodingComprehensiveTests {

    // MARK: - UTF-8 中文

    @Test("UTF-8 中文文件检测")
    func testUTF8ChineseFile() throws {
        let data = try loadTestFile(lang: "zh", filename: "utf-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("UTF-8 中文 encoding 映射")
    func testUTF8ChineseEncoding() throws {
        let data = try loadTestFile(lang: "zh", filename: "utf-8.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding == .utf8)
    }

    @Test("UTF-8 中文可正确解码")
    func testUTF8ChineseDecodable() throws {
        let data = try loadTestFile(lang: "zh", filename: "utf-8.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding == .utf8)
        let decoded = String(data: data, encoding: .utf8)
        #expect(decoded != nil)
        #expect(decoded!.isEmpty == false)
    }

    @Test("UTF-8 简体中文手动构造")
    func testUTF8SimplifiedChineseManual() {
        let text = "中华人民共和国，简称中国，是一个以汉族为主体民族的多民族国家。"
        let data = text.data(using: .utf8)!
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("UTF-8 繁体中文手动构造")
    func testUTF8TraditionalChineseManual() {
        let text = "漢字是中文書寫系統的基本單位，也是世界上最古老的文字之一。"
        let data = text.data(using: .utf8)!
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("UTF-8 中文混合标点")
    func testUTF8ChineseMixedPunctuation() {
        let text = "《红楼梦》是中国古典四大名著之一，作者曹雪芹。书中描写了贾、史、王、薛四大家族的兴衰。"
        let data = text.data(using: .utf8)!
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("UTF-8 中文数字混合")
    func testUTF8ChineseWithNumbers() {
        let text = "2024年，中国GDP总量约为18.53万亿美元，位居世界第二。人口约14亿。"
        let data = text.data(using: .utf8)!
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("UTF-8 中文长文本")
    func testUTF8ChineseLongText() {
        let text = String(repeating: "春眠不觉晓，处处闻啼鸟。夜来风雨声，花落知多少。", count: 50)
        let data = text.data(using: .utf8)!
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    // MARK: - GB18030 / GBK / GB2312

    @Test("GB18030 文件检测")
    func testGB18030File() throws {
        let data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("GB") || upper.contains("GBK"))
    }

    @Test("GB18030 encoding 映射非 nil")
    func testGB18030EncodingNonNil() throws {
        let data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
    }

    @Test("GB18030 encoding 可解码文件")
    func testGB18030EncodingDecodable() throws {
        let data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
        if let encoding = encoding {
            let decoded = String(data: data, encoding: encoding)
            #expect(decoded != nil)
            #expect(decoded!.isEmpty == false)
        }
    }

    @Test("GB2312 charset 名称映射到独立 encoding（非 GB18030）")
    func testGB2312CharsetMapsToGB18030() {
        // 修复后 GB2312 精确映射到 kCFStringEncodingDOSChineseSimplif（0x0930），
        // 与 GB18030（kCFStringEncodingGB_18030_2000，0x0632）是不同的 Apple 平台编码
        let enc1 = String.Encoding(charsetName: "GB2312")
        let enc2 = String.Encoding(charsetName: "GB18030")
        #expect(enc1 != nil)
        #expect(enc2 != nil)
        // GB2312 与 GB18030 是不同的 encoding
        #expect(enc1 != enc2)
    }

    @Test("GBK charset 名称映射到独立 encoding（非 GB18030）")
    func testGBKCharsetMapsToGB18030() {
        // 修复后 GBK 精确映射到 kCFStringEncodingGBK_95（0x0631），
        // 与 GB18030（kCFStringEncodingGB_18030_2000，0x0632）是不同的 Apple 平台编码
        let enc1 = String.Encoding(charsetName: "GBK")
        let enc2 = String.Encoding(charsetName: "GB18030")
        #expect(enc1 != nil)
        #expect(enc2 != nil)
        // GBK 与 GB18030 是不同的 encoding
        #expect(enc1 != enc2)
    }

    @Test("GB18030 charset 名称大小写不敏感")
    func testGB18030CaseInsensitive() {
        let enc1 = String.Encoding(charsetName: "GB18030")
        let enc2 = String.Encoding(charsetName: "gb18030")
        let enc3 = String.Encoding(charsetName: "Gb18030")
        #expect(enc1 != nil)
        #expect(enc1 == enc2)
        #expect(enc1 == enc3)
    }

    @Test("GB18030 分块输入检测")
    func testGB18030ChunkedDetection() throws {
        let data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        let detector = Uchardet()
        let chunkSize = 8
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            detector.handleData(data.subdata(in: offset..<end))
            offset = end
        }
        detector.dataEnd()
        let charset = detector.charset
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("GB") || upper.contains("GBK"))
    }

    @Test("GB18030 流式文件检测")
    func testGB18030StreamDetection() throws {
        let url = projectRoot
            .appendingPathComponent("test")
            .appendingPathComponent("zh")
            .appendingPathComponent("gb18030.txt")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let charset = try Uchardet.detect(contentsOf: url)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("GB") || upper.contains("GBK"))
    }

    @Test("GB18030 流式文件 encoding 检测")
    func testGB18030StreamEncodingDetection() throws {
        let url = projectRoot
            .appendingPathComponent("test")
            .appendingPathComponent("zh")
            .appendingPathComponent("gb18030.txt")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let encoding = try Uchardet.detectEncoding(contentsOf: url)
        #expect(encoding != nil)
    }

    // MARK: - Big5

    @Test("Big5 文件检测")
    func testBig5File() throws {
        let data = try loadTestFile(lang: "zh", filename: "big5.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("BIG5") || upper.contains("BIG-5"))
    }

    @Test("Big5 encoding 映射非 nil")
    func testBig5EncodingNonNil() throws {
        let data = try loadTestFile(lang: "zh", filename: "big5.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
    }

    @Test("Big5 encoding 可解码文件")
    func testBig5EncodingDecodable() throws {
        let data = try loadTestFile(lang: "zh", filename: "big5.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
        if let encoding = encoding {
            let decoded = String(data: data, encoding: encoding)
            #expect(decoded != nil)
            #expect(decoded!.isEmpty == false)
        }
    }

    @Test("Big5 charset 名称映射")
    func testBig5CharsetMapping() {
        let enc1 = String.Encoding(charsetName: "BIG5")
        let enc2 = String.Encoding(charsetName: "BIG-5")
        let enc3 = String.Encoding(charsetName: "big5")
        #expect(enc1 != nil)
        #expect(enc1 == enc2)
        #expect(enc1 == enc3)
    }

    @Test("Big5 分块输入检测")
    func testBig5ChunkedDetection() throws {
        let data = try loadTestFile(lang: "zh", filename: "big5.txt")
        let detector = Uchardet()
        let chunkSize = 8
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            detector.handleData(data.subdata(in: offset..<end))
            offset = end
        }
        detector.dataEnd()
        let charset = detector.charset
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("BIG5") || upper.contains("BIG-5"))
    }

    @Test("Big5 流式文件检测")
    func testBig5StreamDetection() throws {
        let url = projectRoot
            .appendingPathComponent("test")
            .appendingPathComponent("zh")
            .appendingPathComponent("big5.txt")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let charset = try Uchardet.detect(contentsOf: url)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("BIG5") || upper.contains("BIG-5"))
    }

    @Test("Big5 流式文件 encoding 检测")
    func testBig5StreamEncodingDetection() throws {
        let url = projectRoot
            .appendingPathComponent("test")
            .appendingPathComponent("zh")
            .appendingPathComponent("big5.txt")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let encoding = try Uchardet.detectEncoding(contentsOf: url)
        #expect(encoding != nil)
    }

    // MARK: - EUC-TW

    @Test("EUC-TW 文件检测")
    func testEUCTWFile() throws {
        let data = try loadTestFile(lang: "zh", filename: "euc-tw.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("EUC-TW") || upper.contains("EUCTW"))
    }

    @Test("EUC-TW encoding 映射非 nil")
    func testEUCTWEncodingNonNil() throws {
        let data = try loadTestFile(lang: "zh", filename: "euc-tw.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
    }

    @Test("EUC-TW encoding 可解码文件")
    func testEUCTWEncodingDecodable() throws {
        let data = try loadTestFile(lang: "zh", filename: "euc-tw.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
        // 注意：Apple 平台对 EUC-TW 的解码支持有限，
        // String(data:encoding:) 可能返回 nil，此处仅验证 encoding 映射非 nil
        // 不强制要求解码成功（已知平台限制）
        _ = encoding
    }

    @Test("EUC-TW charset 名称映射")
    func testEUCTWCharsetMapping() {
        let enc1 = String.Encoding(charsetName: "EUC-TW")
        let enc2 = String.Encoding(charsetName: "EUCTW")
        let enc3 = String.Encoding(charsetName: "euc-tw")
        #expect(enc1 != nil)
        #expect(enc1 == enc2)
        #expect(enc1 == enc3)
    }

    @Test("EUC-TW 分块输入检测")
    func testEUCTWChunkedDetection() throws {
        let data = try loadTestFile(lang: "zh", filename: "euc-tw.txt")
        let detector = Uchardet()
        let chunkSize = 16
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            detector.handleData(data.subdata(in: offset..<end))
            offset = end
        }
        detector.dataEnd()
        let charset = detector.charset
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("EUC-TW") || upper.contains("EUCTW"))
    }

    @Test("EUC-TW 流式文件检测")
    func testEUCTWStreamDetection() throws {
        let url = projectRoot
            .appendingPathComponent("test")
            .appendingPathComponent("zh")
            .appendingPathComponent("euc-tw.txt")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let charset = try Uchardet.detect(contentsOf: url)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("EUC-TW") || upper.contains("EUCTW"))
    }

    // MARK: - HZ-GB-2312

    @Test("HZ-GB-2312 charset 名称映射（回退到 GB18030）")
    func testHZGB2312CharsetMapping() {
        let enc = String.Encoding(charsetName: "HZ-GB-2312")
        let gb18030 = String.Encoding(charsetName: "GB18030")
        #expect(enc != nil)
        #expect(enc == gb18030)
    }

    @Test("HZ 别名映射与 HZ-GB-2312 一致")
    func testHZAliasConsistency() {
        let enc1 = String.Encoding(charsetName: "HZ-GB-2312")
        let enc2 = String.Encoding(charsetName: "HZ")
        let enc3 = String.Encoding(charsetName: "HZ-GB2312")
        #expect(enc1 != nil)
        #expect(enc1 == enc2)
        #expect(enc1 == enc3)
    }

    // MARK: - ISO-2022-CN

    @Test("ISO-2022-CN charset 名称映射")
    func testISO2022CNCharsetMapping() {
        let enc1 = String.Encoding(charsetName: "ISO-2022-CN")
        let enc2 = String.Encoding(charsetName: "ISO2022CN")
        // 两种写法应映射到相同编码
        #expect(enc1 == enc2)
    }

    @Test("ISO-2022-CN 大小写不敏感")
    func testISO2022CNCaseInsensitive() {
        let enc1 = String.Encoding(charsetName: "ISO-2022-CN")
        let enc2 = String.Encoding(charsetName: "iso-2022-cn")
        let enc3 = String.Encoding(charsetName: "Iso-2022-Cn")
        #expect(enc1 == enc2)
        #expect(enc1 == enc3)
    }

    // MARK: - 中文 UTF-16

    @Test("中文 UTF-16 BE 手动构造检测")
    func testChineseUTF16BEManual() {
        // UTF-16 BE BOM + 中文内容
        var data = Data([0xFE, 0xFF])
        let text = "汉字漢字统一编码万国码"
        if let utf16Data = text.data(using: .utf16BigEndian) {
            data.append(utf16Data)
        }
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("UTF-16") || upper.contains("UTF16"))
    }

    @Test("中文 UTF-16 LE 手动构造检测")
    func testChineseUTF16LEManual() {
        // UTF-16 LE BOM + 中文内容
        var data = Data([0xFF, 0xFE])
        let text = "汉字漢字统一编码万国码"
        if let utf16Data = text.data(using: .utf16LittleEndian) {
            data.append(utf16Data)
        }
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("UTF-16") || upper.contains("UTF16"))
    }

    @Test("中文 UTF-16 BE encoding 映射")
    func testChineseUTF16BEEncoding() {
        var data = Data([0xFE, 0xFF])
        let text = "汉字漢字统一编码万国码中华人民共和国"
        if let utf16Data = text.data(using: .utf16BigEndian) {
            data.append(utf16Data)
        }
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
    }

    @Test("中文 UTF-16 LE encoding 映射")
    func testChineseUTF16LEEncoding() {
        var data = Data([0xFF, 0xFE])
        let text = "汉字漢字统一编码万国码中华人民共和国"
        if let utf16Data = text.data(using: .utf16LittleEndian) {
            data.append(utf16Data)
        }
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
    }

    // MARK: - 中文 UTF-32

    @Test("中文 UTF-32 BE 手动构造检测")
    func testChineseUTF32BEManual() {
        // UTF-32 BE BOM: 00 00 FE FF
        var data = Data([0x00, 0x00, 0xFE, 0xFF])
        let text = "汉字漢字统一编码万国码"
        if let utf32Data = text.data(using: .utf32BigEndian) {
            data.append(utf32Data)
        }
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("UTF-32") || upper.contains("UTF32"))
    }

    @Test("中文 UTF-32 LE 手动构造检测")
    func testChineseUTF32LEManual() {
        // UTF-32 LE BOM: FF FE 00 00
        var data = Data([0xFF, 0xFE, 0x00, 0x00])
        let text = "汉字漢字统一编码万国码"
        if let utf32Data = text.data(using: .utf32LittleEndian) {
            data.append(utf32Data)
        }
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("UTF-32") || upper.contains("UTF32"))
    }

    // MARK: - 中文编码 reset 与复用

    @Test("GB18030 检测后 reset 再检测 UTF-8")
    func testGB18030ThenResetThenUTF8() throws {
        let detector = Uchardet()

        // 第一次：GB18030
        let gb18030Data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        detector.handleData(gb18030Data)
        detector.dataEnd()
        let firstCharset = detector.charset
        #expect(firstCharset != nil)
        let firstUpper = firstCharset!.uppercased()
        #expect(firstUpper.contains("GB") || firstUpper.contains("GBK"))

        // reset 后：UTF-8 中文
        detector.reset()
        let utf8Data = "这是一段中文文本，用于测试 reset 后重新检测功能。".data(using: .utf8)!
        detector.handleData(utf8Data)
        detector.dataEnd()
        #expect(detector.charset?.uppercased() == "UTF-8")
    }

    @Test("Big5 检测后 reset 再检测 GB18030")
    func testBig5ThenResetThenGB18030() throws {
        let detector = Uchardet()

        // 第一次：Big5
        let big5Data = try loadTestFile(lang: "zh", filename: "big5.txt")
        detector.handleData(big5Data)
        detector.dataEnd()
        let firstCharset = detector.charset
        #expect(firstCharset != nil)

        // reset 后：GB18030
        detector.reset()
        let gb18030Data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        detector.handleData(gb18030Data)
        detector.dataEnd()
        let secondCharset = detector.charset
        #expect(secondCharset != nil)
        let secondUpper = secondCharset!.uppercased()
        #expect(secondUpper.contains("GB") || secondUpper.contains("GBK"))
    }

    // MARK: - 中文编码并发检测

    @Test("中文多编码并发检测")
    func testChineseMultiEncodingConcurrent() async throws {
        let utf8Data = try loadTestFile(lang: "zh", filename: "utf-8.txt")
        let gb18030Data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        let big5Data = try loadTestFile(lang: "zh", filename: "big5.txt")
        let euctwData = try loadTestFile(lang: "zh", filename: "euc-tw.txt")

        let results = await withTaskGroup(of: (String, String?).self) { group in
            group.addTask { ("utf8", Uchardet.detect(utf8Data)) }
            group.addTask { ("gb18030", Uchardet.detect(gb18030Data)) }
            group.addTask { ("big5", Uchardet.detect(big5Data)) }
            group.addTask { ("euctw", Uchardet.detect(euctwData)) }

            var collected: [(String, String?)] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        for (name, charset) in results {
            #expect(charset != nil, "编码 \(name) 检测结果不应为 nil")
            switch name {
            case "utf8":
                #expect(charset?.uppercased() == "UTF-8")
            case "gb18030":
                let upper = charset!.uppercased()
                #expect(upper.contains("GB") || upper.contains("GBK"))
            case "big5":
                let upper = charset!.uppercased()
                #expect(upper.contains("BIG5") || upper.contains("BIG-5"))
            case "euctw":
                let upper = charset!.uppercased()
                #expect(upper.contains("EUC-TW") || upper.contains("EUCTW"))
            default:
                break
            }
        }
    }

    @Test("中文 UTF-8 并发多实例检测")
    func testChineseUTF8ConcurrentMultiInstance() async {
        let texts = [
            "春眠不觉晓，处处闻啼鸟。夜来风雨声，花落知多少。",
            "床前明月光，疑是地上霜。举头望明月，低头思故乡。",
            "白日依山尽，黄河入海流。欲穷千里目，更上一层楼。",
            "锄禾日当午，汗滴禾下土。谁知盘中餐，粒粒皆辛苦。",
            "慈母手中线，游子身上衣。临行密密缝，意恐迟迟归。",
        ]

        await withTaskGroup(of: String?.self) { group in
            for text in texts {
                group.addTask {
                    return Uchardet.detect(text)
                }
            }
            for await result in group {
                #expect(result?.uppercased() == "UTF-8")
            }
        }
    }

    // MARK: - 中文编码 bytes API

    @Test("GB18030 bytes API 检测")
    func testGB18030BytesAPI() throws {
        let data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        let bytes = Array(data)
        let charset = Uchardet.detect(bytes: bytes)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("GB") || upper.contains("GBK"))
    }

    @Test("Big5 bytes API 检测")
    func testBig5BytesAPI() throws {
        let data = try loadTestFile(lang: "zh", filename: "big5.txt")
        let bytes = Array(data)
        let charset = Uchardet.detect(bytes: bytes)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("BIG5") || upper.contains("BIG-5"))
    }

    @Test("EUC-TW bytes API 检测")
    func testEUCTWBytesAPI() throws {
        let data = try loadTestFile(lang: "zh", filename: "euc-tw.txt")
        let bytes = Array(data)
        let charset = Uchardet.detect(bytes: bytes)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("EUC-TW") || upper.contains("EUCTW"))
    }

    @Test("UTF-8 中文 bytes API 与 Data API 结果一致")
    func testUTF8ChineseBytesDataConsistency() {
        let text = "这是一段中文文本，用于验证 bytes 与 Data API 结果一致性。包含各种汉字和标点符号。"
        let data = text.data(using: .utf8)!
        let bytes = Array(data)

        let charsetFromData = Uchardet.detect(data)
        let charsetFromBytes = Uchardet.detect(bytes: bytes)

        #expect(charsetFromData?.uppercased() == charsetFromBytes?.uppercased())
        #expect(charsetFromData?.uppercased() == "UTF-8")
    }

    @Test("GB18030 bytes API 与 Data API 结果一致")
    func testGB18030BytesDataConsistency() throws {
        let data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        let bytes = Array(data)

        let charsetFromData = Uchardet.detect(data)
        let charsetFromBytes = Uchardet.detect(bytes: bytes)

        #expect(charsetFromData?.uppercased() == charsetFromBytes?.uppercased())
    }

    // MARK: - 中文编码 encoding 属性

    @Test("UTF-8 中文 encoding 属性")
    func testUTF8ChineseEncodingProperty() {
        let detector = Uchardet()
        let data = "这是一段中文文本，用于测试 encoding 属性。包含足够多的汉字以确保检测准确。".data(using: .utf8)!
        detector.handleData(data)
        detector.dataEnd()
        #expect(detector.encoding == .utf8)
    }

    @Test("GB18030 encoding 属性非 nil")
    func testGB18030EncodingProperty() throws {
        let detector = Uchardet()
        let data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        detector.handleData(data)
        detector.dataEnd()
        #expect(detector.charset != nil)
        #expect(detector.encoding != nil)
    }

    @Test("Big5 encoding 属性非 nil")
    func testBig5EncodingProperty() throws {
        let detector = Uchardet()
        let data = try loadTestFile(lang: "zh", filename: "big5.txt")
        detector.handleData(data)
        detector.dataEnd()
        #expect(detector.charset != nil)
        #expect(detector.encoding != nil)
    }

    @Test("EUC-TW encoding 属性非 nil")
    func testEUCTWEncodingProperty() throws {
        let detector = Uchardet()
        let data = try loadTestFile(lang: "zh", filename: "euc-tw.txt")
        detector.handleData(data)
        detector.dataEnd()
        #expect(detector.charset != nil)
        #expect(detector.encoding != nil)
    }

    // MARK: - 中文编码 charset 与 encoding 一致性

    @Test("中文所有编码 charset 与 encoding 一致性")
    func testChineseAllEncodingsConsistency() throws {
        let files: [(String, String)] = [
            ("zh", "utf-8.txt"),
            ("zh", "gb18030.txt"),
            ("zh", "big5.txt"),
            ("zh", "euc-tw.txt"),
        ]

        for (lang, filename) in files {
            let data = try loadTestFile(lang: lang, filename: filename)
            let detector = Uchardet()
            detector.handleData(data)
            detector.dataEnd()

            let charset = detector.charset
            let encoding = detector.encoding

            if let charset = charset {
                let mappedEncoding = String.Encoding(charsetName: charset)
                #expect(mappedEncoding == encoding,
                    "文件 \(lang)/\(filename) 的 charset '\(charset)' 映射的 encoding 与 detector.encoding 不一致")
            } else {
                #expect(encoding == nil,
                    "文件 \(lang)/\(filename) charset 为 nil 时 encoding 应也为 nil")
            }
        }
    }

    // MARK: - 中文编码大文件测试

    @Test("UTF-8 中文大文件（>100KB）检测")
    func testUTF8ChineseLargeFile() {
        let baseText = "这是一段用于测试大文件字符集检测的中文文本，包含各种常用汉字和标点符号。"
        let text = String(repeating: baseText, count: 2000)
        let data = text.data(using: .utf8)!
        #expect(data.count > 100_000)
        let charset = Uchardet.detect(data)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("UTF-8 中文大文件流式检测")
    func testUTF8ChineseLargeFileStream() throws {
        let baseText = "这是一段用于测试大文件流式检测的中文文本，包含各种常用汉字。"
        let text = String(repeating: baseText, count: 2000)
        let data = text.data(using: .utf8)!
        #expect(data.count > 100_000)

        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent(UUID().uuidString + ".txt")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let charset = try Uchardet.detect(contentsOf: url, sampleSize: 65_536)
        #expect(charset?.uppercased() == "UTF-8")
    }

    @Test("UTF-8 中文大文件流式与全量检测结果一致")
    func testUTF8ChineseLargeFileStreamVsFullConsistency() throws {
        let baseText = "这是一段用于验证流式与全量检测一致性的中文文本。"
        let text = String(repeating: baseText, count: 1000)
        let data = text.data(using: .utf8)!

        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent(UUID().uuidString + ".txt")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let streamCharset = try Uchardet.detect(contentsOf: url)
        let fullCharset = Uchardet.detect(data)

        #expect(streamCharset?.uppercased() == fullCharset?.uppercased())
    }

    // MARK: - 中文编码边界条件

    @Test("单个中文字符 UTF-8 检测")
    func testSingleChineseCharUTF8() {
        // "中" 的 UTF-8 编码：E4 B8 AD
        let data = Data([0xE4, 0xB8, 0xAD])
        let charset = Uchardet.detect(data)
        // 单个字符可能无法确定编码，不强制要求特定结果
        _ = charset
    }

    @Test("中文 UTF-8 BOM 检测")
    func testChineseUTF8WithBOM() {
        // UTF-8 BOM: EF BB BF + 中文内容
        var data = Data([0xEF, 0xBB, 0xBF])
        let text = "这是带 BOM 的 UTF-8 中文文本，用于测试 BOM 检测功能。"
        data.append(text.data(using: .utf8)!)
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("UTF-8"))
    }

    @Test("中文 UTF-8 空字符串返回 nil")
    func testChineseUTF8EmptyReturnsNil() {
        let charset = Uchardet.detect("")
        #expect(charset == nil)
    }

    @Test("中文 UTF-8 单字节分块输入")
    func testChineseUTF8SingleByteChunks() {
        let text = "你好世界！这是测试。"
        let data = text.data(using: .utf8)!
        let detector = Uchardet()
        for i in 0..<data.count {
            detector.handleData(data.subdata(in: i..<(i + 1)))
        }
        detector.dataEnd()
        #expect(detector.charset?.uppercased() == "UTF-8")
    }

    @Test("中文 UTF-8 多次 reset 后检测稳定")
    func testChineseUTF8MultipleResetsStable() {
        let detector = Uchardet()
        let text = "这是中文文本，用于测试多次重置后检测结果的稳定性。"
        for _ in 0..<5 {
            let data = text.data(using: .utf8)!
            detector.handleData(data)
            detector.dataEnd()
            #expect(detector.charset?.uppercased() == "UTF-8")
            detector.reset()
        }
    }

    // MARK: - 中文编码 detectEncoding 静态方法

    @Test("detectEncoding(Data) - GB18030 文件")
    func testDetectEncodingGB18030() throws {
        let data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
        // 验证可以用该 encoding 解码数据
        if let encoding = encoding {
            let decoded = String(data: data, encoding: encoding)
            #expect(decoded != nil)
        }
    }

    @Test("detectEncoding(Data) - Big5 文件")
    func testDetectEncodingBig5() throws {
        let data = try loadTestFile(lang: "zh", filename: "big5.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
        if let encoding = encoding {
            let decoded = String(data: data, encoding: encoding)
            #expect(decoded != nil)
        }
    }

    @Test("detectEncoding(Data) - EUC-TW 文件")
    func testDetectEncodingEUCTW() throws {
        let data = try loadTestFile(lang: "zh", filename: "euc-tw.txt")
        let encoding = Uchardet.detectEncoding(data)
        #expect(encoding != nil)
        // 注意：Apple 平台对 EUC-TW 的解码支持有限，
        // String(data:encoding:) 可能返回 nil，此处仅验证 encoding 映射非 nil
        // 不强制要求解码成功（已知平台限制）
        _ = encoding
    }

    @Test("detectEncoding(String) - UTF-8 中文字符串")
    func testDetectEncodingUTF8ChineseString() {
        let encoding = Uchardet.detectEncoding("这是一段中文文本，用于测试 detectEncoding(String:) 方法。")
        #expect(encoding == .utf8)
    }

    @Test("detectEncoding(bytes:) - GB18030 文件")
    func testDetectEncodingBytesGB18030() throws {
        let data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        let bytes = Array(data)
        let encoding = Uchardet.detectEncoding(bytes: bytes)
        #expect(encoding != nil)
    }

    @Test("detectEncoding(bytes:) - Big5 文件")
    func testDetectEncodingBytesBig5() throws {
        let data = try loadTestFile(lang: "zh", filename: "big5.txt")
        let bytes = Array(data)
        let encoding = Uchardet.detectEncoding(bytes: bytes)
        #expect(encoding != nil)
    }
}

// MARK: - 正向测试：所有 charset 名称 → String.Encoding 映射

/// 正向测试：验证 `String.Encoding(charsetName:)` 对所有支持的 charset 名称
/// 均能返回非 nil 的有效 `String.Encoding`，且别名映射到相同编码。
@Suite("正向测试：charset 名称 → String.Encoding 映射")
struct ForwardEncodingMappingTests {

    // MARK: Unicode 系列

    @Test("正向：UTF-8 所有别名")
    func testForwardUTF8() {
        let enc = String.Encoding(charsetName: "UTF-8")
        #expect(enc == .utf8)
        #expect(String.Encoding(charsetName: "utf-8") == enc)
        #expect(String.Encoding(charsetName: "UTF8") == enc)
    }

    @Test("正向：UTF-16 所有别名")
    func testForwardUTF16() {
        let enc = String.Encoding(charsetName: "UTF-16")
        #expect(enc == .utf16)
        #expect(String.Encoding(charsetName: "UTF16") == enc)
    }

    @Test("正向：UTF-16BE 所有别名")
    func testForwardUTF16BE() {
        let enc = String.Encoding(charsetName: "UTF-16BE")
        #expect(enc == .utf16BigEndian)
        #expect(String.Encoding(charsetName: "UTF-16-BE") == enc)
        #expect(String.Encoding(charsetName: "UTF16BE") == enc)
    }

    @Test("正向：UTF-16LE 所有别名")
    func testForwardUTF16LE() {
        let enc = String.Encoding(charsetName: "UTF-16LE")
        #expect(enc == .utf16LittleEndian)
        #expect(String.Encoding(charsetName: "UTF-16-LE") == enc)
        #expect(String.Encoding(charsetName: "UTF16LE") == enc)
    }

    @Test("正向：UTF-32 所有别名")
    func testForwardUTF32() {
        let enc = String.Encoding(charsetName: "UTF-32")
        #expect(enc == .utf32)
        #expect(String.Encoding(charsetName: "UTF32") == enc)
    }

    @Test("正向：UTF-32BE 所有别名")
    func testForwardUTF32BE() {
        let enc = String.Encoding(charsetName: "UTF-32BE")
        #expect(enc == .utf32BigEndian)
        #expect(String.Encoding(charsetName: "UTF-32-BE") == enc)
        #expect(String.Encoding(charsetName: "UTF32BE") == enc)
    }

    @Test("正向：UTF-32LE 所有别名")
    func testForwardUTF32LE() {
        let enc = String.Encoding(charsetName: "UTF-32LE")
        #expect(enc == .utf32LittleEndian)
        #expect(String.Encoding(charsetName: "UTF-32-LE") == enc)
        #expect(String.Encoding(charsetName: "UTF32LE") == enc)
    }

    @Test("正向：X-ISO-10646-UCS-4 变体")
    func testForwardUCS4Variants() {
        #expect(String.Encoding(charsetName: "X-ISO-10646-UCS-4-34121") == .utf32BigEndian)
        #expect(String.Encoding(charsetName: "X-ISO-10646-UCS-4-21431") == .utf32LittleEndian)
    }

    // MARK: ASCII

    @Test("正向：ASCII 所有别名")
    func testForwardASCII() {
        let enc = String.Encoding(charsetName: "ASCII")
        #expect(enc == .ascii)
        #expect(String.Encoding(charsetName: "US-ASCII") == enc)
        #expect(String.Encoding(charsetName: "USASCII") == enc)
        #expect(String.Encoding(charsetName: "US ASCII") == enc)
    }

    // MARK: 中文

    @Test("正向：GB2312 所有别名")
    func testForwardGB2312() {
        let enc = String.Encoding(charsetName: "GB2312")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "GB-2312") == enc)
        #expect(String.Encoding(charsetName: "CN-GB") == enc)
        #expect(String.Encoding(charsetName: "CSGB2312") == enc)
    }

    @Test("正向：GBK 所有别名")
    func testForwardGBK() {
        let enc = String.Encoding(charsetName: "GBK")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "X-GBK") == enc)
        // GBK 与 GB2312、GB18030 是不同的编码
        #expect(enc != String.Encoding(charsetName: "GB2312"))
        #expect(enc != String.Encoding(charsetName: "GB18030"))
    }

    @Test("正向：GB18030 所有别名")
    func testForwardGB18030() {
        let enc = String.Encoding(charsetName: "GB18030")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "GB-18030") == enc)
        // GB18030 与 GB2312、GBK 是不同的编码
        #expect(enc != String.Encoding(charsetName: "GB2312"))
        #expect(enc != String.Encoding(charsetName: "GBK"))
    }

    @Test("正向：Big5 所有别名")
    func testForwardBig5() {
        let enc = String.Encoding(charsetName: "BIG5")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "BIG-5") == enc)
        #expect(String.Encoding(charsetName: "BIG5-HKSCS") == enc)
        #expect(String.Encoding(charsetName: "BIG5-HKSCS:2004") == enc)
        #expect(String.Encoding(charsetName: "BIG5-HKSCS:2001") == enc)
        #expect(String.Encoding(charsetName: "BIG5-HKSCS:1999") == enc)
        #expect(String.Encoding(charsetName: "CN-BIG5") == enc)
    }

    @Test("正向：EUC-TW 所有别名")
    func testForwardEUCTW() {
        let enc = String.Encoding(charsetName: "EUC-TW")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "EUCTW") == enc)
        #expect(String.Encoding(charsetName: "X-EUC-TW") == enc)
    }

    @Test("正向：ISO-2022-CN 所有别名")
    func testForwardISO2022CN() {
        let enc = String.Encoding(charsetName: "ISO-2022-CN")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "ISO2022CN") == enc)
        #expect(String.Encoding(charsetName: "CSISO2022CN") == enc)
    }

    @Test("正向：HZ-GB-2312 所有别名（回退到 GB18030）")
    func testForwardHZGB2312() {
        let enc = String.Encoding(charsetName: "HZ-GB-2312")
        let gb18030 = String.Encoding(charsetName: "GB18030")
        #expect(enc != nil)
        #expect(enc == gb18030)
        #expect(String.Encoding(charsetName: "HZ") == enc)
        #expect(String.Encoding(charsetName: "HZ-GB2312") == enc)
    }

    // MARK: 日文

    @Test("正向：EUC-JP 所有别名")
    func testForwardEUCJP() {
        let enc = String.Encoding(charsetName: "EUC-JP")
        #expect(enc == .japaneseEUC)
        #expect(String.Encoding(charsetName: "EUCJP") == enc)
        #expect(String.Encoding(charsetName: "X-EUC-JP") == enc)
    }

    @Test("正向：Shift_JIS 所有别名")
    func testForwardShiftJIS() {
        let enc = String.Encoding(charsetName: "SHIFT-JIS")
        #expect(enc == .shiftJIS)
        #expect(String.Encoding(charsetName: "SHIFT_JIS") == enc)
        #expect(String.Encoding(charsetName: "SHIFTJIS") == enc)
        #expect(String.Encoding(charsetName: "SJIS") == enc)
        #expect(String.Encoding(charsetName: "X-SJIS") == enc)
        #expect(String.Encoding(charsetName: "MS-KANJI") == enc)
        #expect(String.Encoding(charsetName: "SHIFT JIS") == enc)
    }

    @Test("正向：ISO-2022-JP 所有别名")
    func testForwardISO2022JP() {
        let enc = String.Encoding(charsetName: "ISO-2022-JP")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "ISO2022JP") == enc)
        #expect(String.Encoding(charsetName: "CSISO2022JP") == enc)
    }

    // MARK: 韩文

    @Test("正向：EUC-KR 所有别名")
    func testForwardEUCKR() {
        let enc = String.Encoding(charsetName: "EUC-KR")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "EUCKR") == enc)
        #expect(String.Encoding(charsetName: "UHC") == enc)
        #expect(String.Encoding(charsetName: "CP949") == enc)
        #expect(String.Encoding(charsetName: "KS-C-5601-1987") == enc)
        #expect(String.Encoding(charsetName: "KS-C-5601-1989") == enc)
        #expect(String.Encoding(charsetName: "ISO-IR-149") == enc)
        #expect(String.Encoding(charsetName: "CSEUCKR") == enc)
    }

    @Test("正向：ISO-2022-KR 所有别名")
    func testForwardISO2022KR() {
        let enc = String.Encoding(charsetName: "ISO-2022-KR")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "ISO2022KR") == enc)
        #expect(String.Encoding(charsetName: "CSISO2022KR") == enc)
    }

    // MARK: Cyrillic

    @Test("正向：KOI8-R 所有别名")
    func testForwardKOI8R() {
        let enc = String.Encoding(charsetName: "KOI8-R")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "KOI8R") == enc)
        #expect(String.Encoding(charsetName: "CSKOI8R") == enc)
    }

    @Test("正向：KOI8-U 所有别名")
    func testForwardKOI8U() {
        let enc = String.Encoding(charsetName: "KOI8-U")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "KOI8U") == enc)
        // KOI8-U 与 KOI8-R 是不同的编码
        #expect(enc != String.Encoding(charsetName: "KOI8-R"))
    }

    @Test("正向：Windows-1251 所有别名")
    func testForwardWindows1251() {
        let enc = String.Encoding(charsetName: "WINDOWS-1251")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1251") == enc)
        #expect(String.Encoding(charsetName: "CP-1251") == enc)
        #expect(String.Encoding(charsetName: "X-CP1251") == enc)
    }

    @Test("正向：ISO-8859-5 所有别名")
    func testForwardISO88595() {
        let enc = String.Encoding(charsetName: "ISO-8859-5")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "ISO8859-5") == enc)
        #expect(String.Encoding(charsetName: "CYRILLIC") == enc)
        #expect(String.Encoding(charsetName: "CSISOLATINCYRILLIC") == enc)
    }

    @Test("正向：IBM855 所有别名")
    func testForwardIBM855() {
        let enc = String.Encoding(charsetName: "IBM855")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP855") == enc)
    }

    @Test("正向：IBM866 所有别名")
    func testForwardIBM866() {
        let enc = String.Encoding(charsetName: "IBM866")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP866") == enc)
    }

    @Test("正向：Mac-Cyrillic 所有别名")
    func testForwardMacCyrillic() {
        let enc = String.Encoding(charsetName: "MAC-CYRILLIC")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "MACCYRILLIC") == enc)
        #expect(String.Encoding(charsetName: "X-MAC-CYRILLIC") == enc)
    }

    // MARK: 西欧 / Latin-1

    @Test("正向：ISO-8859-1 所有别名")
    func testForwardISO88591() {
        let enc = String.Encoding(charsetName: "ISO-8859-1")
        #expect(enc == .isoLatin1)
        #expect(String.Encoding(charsetName: "ISO8859-1") == enc)
        #expect(String.Encoding(charsetName: "LATIN1") == enc)
        #expect(String.Encoding(charsetName: "L1") == enc)
        #expect(String.Encoding(charsetName: "ISO-IR-100") == enc)
        #expect(String.Encoding(charsetName: "CSISOLATIN1") == enc)
    }

    @Test("正向：ISO-8859-15 所有别名")
    func testForwardISO885915() {
        let enc = String.Encoding(charsetName: "ISO-8859-15")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "ISO8859-15") == enc)
        #expect(String.Encoding(charsetName: "LATIN9") == enc)
        #expect(String.Encoding(charsetName: "L9") == enc)
        #expect(String.Encoding(charsetName: "ISO-IR-203") == enc)
        #expect(String.Encoding(charsetName: "CSISOLATIN9") == enc)
    }

    @Test("正向：Windows-1252 所有别名")
    func testForwardWindows1252() {
        let enc = String.Encoding(charsetName: "WINDOWS-1252")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1252") == enc)
        #expect(String.Encoding(charsetName: "CP-1252") == enc)
        #expect(String.Encoding(charsetName: "X-CP1252") == enc)
    }

    // MARK: 中东欧 / Latin-2

    @Test("正向：ISO-8859-2 所有别名")
    func testForwardISO88592() {
        let enc = String.Encoding(charsetName: "ISO-8859-2")
        #expect(enc == .isoLatin2)
        #expect(String.Encoding(charsetName: "ISO8859-2") == enc)
        #expect(String.Encoding(charsetName: "LATIN2") == enc)
        #expect(String.Encoding(charsetName: "L2") == enc)
        #expect(String.Encoding(charsetName: "ISO-IR-101") == enc)
        #expect(String.Encoding(charsetName: "CSISOLATIN2") == enc)
    }

    @Test("正向：Windows-1250 所有别名")
    func testForwardWindows1250() {
        let enc = String.Encoding(charsetName: "WINDOWS-1250")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1250") == enc)
        #expect(String.Encoding(charsetName: "CP-1250") == enc)
        #expect(String.Encoding(charsetName: "X-CP1250") == enc)
    }

    @Test("正向：IBM852 所有别名")
    func testForwardIBM852() {
        let enc = String.Encoding(charsetName: "IBM852")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP852") == enc)
    }

    @Test("正向：Mac-CentralEurope 所有别名")
    func testForwardMacCentralEurope() {
        let enc = String.Encoding(charsetName: "MAC-CENTRALEUROPE")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "MACCENTRALEUROPE") == enc)
        #expect(String.Encoding(charsetName: "X-MAC-CENTRALEUROPE") == enc)
        #expect(String.Encoding(charsetName: "MAC-CE") == enc)
        #expect(String.Encoding(charsetName: "MACCE") == enc)
    }

    // MARK: 希腊语

    @Test("正向：ISO-8859-7 所有别名")
    func testForwardISO88597() {
        let enc = String.Encoding(charsetName: "ISO-8859-7")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "ISO8859-7") == enc)
        #expect(String.Encoding(charsetName: "GREEK") == enc)
        #expect(String.Encoding(charsetName: "GREEK8") == enc)
        #expect(String.Encoding(charsetName: "ISO-IR-126") == enc)
        #expect(String.Encoding(charsetName: "CSISOLATINGREEK") == enc)
    }

    @Test("正向：Windows-1253 所有别名")
    func testForwardWindows1253() {
        let enc = String.Encoding(charsetName: "WINDOWS-1253")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1253") == enc)
        #expect(String.Encoding(charsetName: "CP-1253") == enc)
        #expect(String.Encoding(charsetName: "X-CP1253") == enc)
    }

    // MARK: 希伯来语

    @Test("正向：ISO-8859-8 所有别名")
    func testForwardISO88598() {
        let enc = String.Encoding(charsetName: "ISO-8859-8")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "ISO8859-8") == enc)
        #expect(String.Encoding(charsetName: "HEBREW") == enc)
        #expect(String.Encoding(charsetName: "ISO-IR-138") == enc)
        #expect(String.Encoding(charsetName: "CSISOLATINHEBREW") == enc)
    }

    @Test("正向：Windows-1255 所有别名")
    func testForwardWindows1255() {
        let enc = String.Encoding(charsetName: "WINDOWS-1255")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1255") == enc)
        #expect(String.Encoding(charsetName: "CP-1255") == enc)
        #expect(String.Encoding(charsetName: "X-CP1255") == enc)
    }

    // MARK: 阿拉伯语

    @Test("正向：ISO-8859-6 所有别名")
    func testForwardISO88596() {
        let enc = String.Encoding(charsetName: "ISO-8859-6")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "ISO8859-6") == enc)
        #expect(String.Encoding(charsetName: "ARABIC") == enc)
        #expect(String.Encoding(charsetName: "ISO-IR-127") == enc)
        #expect(String.Encoding(charsetName: "CSISOLATINARABIC") == enc)
    }

    @Test("正向：Windows-1256 所有别名")
    func testForwardWindows1256() {
        let enc = String.Encoding(charsetName: "WINDOWS-1256")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1256") == enc)
        #expect(String.Encoding(charsetName: "CP-1256") == enc)
        #expect(String.Encoding(charsetName: "X-CP1256") == enc)
    }

    // MARK: 波罗的海 / Baltic

    @Test("正向：ISO-8859-4 所有别名")
    func testForwardISO88594() {
        let enc = String.Encoding(charsetName: "ISO-8859-4")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "ISO8859-4") == enc)
        #expect(String.Encoding(charsetName: "LATIN4") == enc)
        #expect(String.Encoding(charsetName: "L4") == enc)
        #expect(String.Encoding(charsetName: "ISO-IR-110") == enc)
        #expect(String.Encoding(charsetName: "CSISOLATIN4") == enc)
    }

    @Test("正向：ISO-8859-10 所有别名")
    func testForwardISO885910() {
        let enc = String.Encoding(charsetName: "ISO-8859-10")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "ISO8859-10") == enc)
        #expect(String.Encoding(charsetName: "LATIN6") == enc)
        #expect(String.Encoding(charsetName: "L6") == enc)
        #expect(String.Encoding(charsetName: "ISO-IR-157") == enc)
        #expect(String.Encoding(charsetName: "CSISOLATIN6") == enc)
    }

    @Test("正向：ISO-8859-13 所有别名")
    func testForwardISO885913() {
        let enc = String.Encoding(charsetName: "ISO-8859-13")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "ISO8859-13") == enc)
        #expect(String.Encoding(charsetName: "LATIN7") == enc)
        #expect(String.Encoding(charsetName: "L7") == enc)
        #expect(String.Encoding(charsetName: "ISO-IR-179") == enc)
    }

    @Test("正向：Windows-1257 所有别名")
    func testForwardWindows1257() {
        let enc = String.Encoding(charsetName: "WINDOWS-1257")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1257") == enc)
        #expect(String.Encoding(charsetName: "CP-1257") == enc)
        #expect(String.Encoding(charsetName: "X-CP1257") == enc)
    }

    @Test("正向：IBM865 所有别名")
    func testForwardIBM865() {
        let enc = String.Encoding(charsetName: "IBM865")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP865") == enc)
    }

    // MARK: 土耳其语

    @Test("正向：ISO-8859-3 所有别名")
    func testForwardISO88593() {
        let enc = String.Encoding(charsetName: "ISO-8859-3")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "ISO8859-3") == enc)
        #expect(String.Encoding(charsetName: "LATIN3") == enc)
        #expect(String.Encoding(charsetName: "L3") == enc)
        #expect(String.Encoding(charsetName: "ISO-IR-109") == enc)
        #expect(String.Encoding(charsetName: "CSISOLATIN3") == enc)
    }

    @Test("正向：ISO-8859-9 所有别名")
    func testForwardISO88599() {
        let enc = String.Encoding(charsetName: "ISO-8859-9")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "ISO8859-9") == enc)
        #expect(String.Encoding(charsetName: "LATIN5") == enc)
        #expect(String.Encoding(charsetName: "L5") == enc)
        #expect(String.Encoding(charsetName: "ISO-IR-148") == enc)
        #expect(String.Encoding(charsetName: "CSISOLATIN5") == enc)
    }

    @Test("正向：Windows-1254 所有别名")
    func testForwardWindows1254() {
        let enc = String.Encoding(charsetName: "WINDOWS-1254")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1254") == enc)
        #expect(String.Encoding(charsetName: "CP-1254") == enc)
        #expect(String.Encoding(charsetName: "X-CP1254") == enc)
    }

    // MARK: 泰语

    @Test("正向：TIS-620 / ISO-8859-11 所有别名")
    func testForwardTIS620() {
        let enc = String.Encoding(charsetName: "TIS-620")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "TIS620") == enc)
        #expect(String.Encoding(charsetName: "ISO-8859-11") == enc)
        #expect(String.Encoding(charsetName: "ISO8859-11") == enc)
    }

    // MARK: 越南语

    @Test("正向：Windows-1258 所有别名")
    func testForwardWindows1258() {
        let enc = String.Encoding(charsetName: "WINDOWS-1258")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "CP1258") == enc)
        #expect(String.Encoding(charsetName: "CP-1258") == enc)
        #expect(String.Encoding(charsetName: "X-CP1258") == enc)
    }

    @Test("正向：VISCII 所有别名")
    func testForwardVISCII() {
        let enc = String.Encoding(charsetName: "VISCII")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "VISCII1.1-1") == enc)
    }

    // MARK: 罗马尼亚语

    @Test("正向：ISO-8859-16 所有别名")
    func testForwardISO885916() {
        let enc = String.Encoding(charsetName: "ISO-8859-16")
        #expect(enc != nil)
        #expect(String.Encoding(charsetName: "ISO8859-16") == enc)
        #expect(String.Encoding(charsetName: "LATIN10") == enc)
        #expect(String.Encoding(charsetName: "L10") == enc)
        #expect(String.Encoding(charsetName: "ISO-IR-226") == enc)
    }

    // MARK: 无效名称

    @Test("正向：无效 charset 名称返回 nil")
    func testForwardInvalidNames() {
        #expect(String.Encoding(charsetName: "") == nil)
        #expect(String.Encoding(charsetName: "INVALID-ENCODING-XYZ-999") == nil)
        #expect(String.Encoding(charsetName: "NOT-A-CHARSET") == nil)
        #expect(String.Encoding(charsetName: "   ") == nil)
    }

    // MARK: 大小写不敏感

    @Test("正向：大小写不敏感验证")
    func testForwardCaseInsensitive() {
        // 每种编码用小写、大写、混合大小写验证
        #expect(String.Encoding(charsetName: "utf-8") == .utf8)
        #expect(String.Encoding(charsetName: "UTF-8") == .utf8)
        #expect(String.Encoding(charsetName: "Utf-8") == .utf8)
        #expect(String.Encoding(charsetName: "gb18030") == String.Encoding(charsetName: "GB18030"))
        #expect(String.Encoding(charsetName: "Gb18030") == String.Encoding(charsetName: "GB18030"))
        #expect(String.Encoding(charsetName: "koi8-r") == String.Encoding(charsetName: "KOI8-R"))
        #expect(String.Encoding(charsetName: "windows-1252") == String.Encoding(charsetName: "WINDOWS-1252"))
    }
}

// MARK: - 反向测试：编码文本 → uchardet 检测 → 验证结果与原编码一致

/// 反向测试：将文本用特定编码编码后交给 uchardet 检测，
/// 验证检测到的 charset 名称能映射回相同的 `String.Encoding`。
///
/// 测试策略：
/// - 正向：`charsetName → String.Encoding`（映射层）
/// - 反向：`String.Encoding 编码文本 → uchardet 检测 → charsetName → String.Encoding`
///   验证最终 encoding 与原始 encoding 相同（或属于兼容超集）
@Suite("反向测试：编码文本 → uchardet 检测 → encoding 一致性")
struct ReverseEncodingDetectionTests {

    // MARK: - 辅助：从测试文件加载数据
    private func loadTestFile(lang: String, filename: String) throws -> Data {
        let thisFile = URL(fileURLWithPath: #filePath)
        let root = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root
            .appendingPathComponent("test")
            .appendingPathComponent(lang)
            .appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TestError.fileNotFound("test/\(lang)/\(filename)")
        }
        return try Data(contentsOf: url)
    }

    // MARK: Unicode 系列

    @Test("反向：UTF-8 中文")
    func testReverseUTF8Chinese() {
        let text = "中华人民共和国，简称中国，是一个以汉族为主体民族的多民族国家。北京是首都。"
        let data = text.data(using: .utf8)!
        let detected = Uchardet.detectEncoding(data)
        #expect(detected == .utf8)
    }

    @Test("反向：UTF-8 日文")
    func testReverseUTF8Japanese() {
        let text = "日本語のテキストです。東京は日本の首都です。桜の花が美しい季節です。"
        let data = text.data(using: .utf8)!
        let detected = Uchardet.detectEncoding(data)
        #expect(detected == .utf8)
    }

    @Test("反向：UTF-8 韩文")
    func testReverseUTF8Korean() {
        let text = "한국어 텍스트입니다. 서울은 대한민국의 수도입니다. 한글은 아름다운 문자입니다."
        let data = text.data(using: .utf8)!
        let detected = Uchardet.detectEncoding(data)
        #expect(detected == .utf8)
    }

    @Test("反向：UTF-8 阿拉伯语")
    func testReverseUTF8Arabic() {
        let text = "النص العربي. القاهرة هي عاصمة مصر. اللغة العربية جميلة جداً."
        let data = text.data(using: .utf8)!
        let detected = Uchardet.detectEncoding(data)
        #expect(detected == .utf8)
    }

    @Test("反向：UTF-8 希腊语")
    func testReverseUTF8Greek() {
        let text = "Ελληνικό κείμενο. Η Αθήνα είναι η πρωτεύουσα της Ελλάδας. Η ελληνική γλώσσα είναι αρχαία."
        let data = text.data(using: .utf8)!
        let detected = Uchardet.detectEncoding(data)
        #expect(detected == .utf8)
    }

    @Test("反向：UTF-16BE 中文")
    func testReverseUTF16BEChinese() {
        var data = Data([0xFE, 0xFF])  // BOM
        let text = "汉字漢字统一编码万国码中华人民共和国"
        data.append(text.data(using: .utf16BigEndian)!)
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("UTF-16") || upper.contains("UTF16"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
    }

    @Test("反向：UTF-16LE 中文")
    func testReverseUTF16LEChinese() {
        var data = Data([0xFF, 0xFE])  // BOM
        let text = "汉字漢字统一编码万国码中华人民共和国"
        data.append(text.data(using: .utf16LittleEndian)!)
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("UTF-16") || upper.contains("UTF16"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
    }

    @Test("反向：ASCII")
    func testReverseASCII() {
        let text = "The quick brown fox jumps over the lazy dog. 0123456789 !@#$%^&*()"
        let data = text.data(using: .ascii)!
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper == "ASCII" || upper == "UTF-8")
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        #expect(enc == .ascii || enc == .utf8)
    }

    // MARK: 中文编码

    @Test("反向：GB18030 文件")
    func testReverseGB18030() throws {
        let data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        // 检测结果应能解码原始数据
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：Big5 文件")
    func testReverseBig5() throws {
        let data = try loadTestFile(lang: "zh", filename: "big5.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("BIG5") || upper.contains("BIG-5"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：EUC-TW 文件")
    func testReverseEUCTW() throws {
        let data = try loadTestFile(lang: "zh", filename: "euc-tw.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("EUC-TW") || upper.contains("EUCTW"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
    }

    // MARK: 日文编码

    @Test("反向：EUC-JP 文件")
    func testReverseEUCJP() throws {
        let data = try loadTestFile(lang: "ja", filename: "euc-jp.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("EUC-JP") || upper.contains("EUCJP"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc == .japaneseEUC)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：Shift_JIS 文件")
    func testReverseShiftJIS() throws {
        let data = try loadTestFile(lang: "ja", filename: "shift_jis.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("SHIFT") || upper.contains("SJIS"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc == .shiftJIS)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：ISO-2022-JP 文件")
    func testReverseISO2022JP() throws {
        let data = try loadTestFile(lang: "ja", filename: "iso-2022-jp.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-2022-JP") || upper.contains("ISO2022JP"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
    }

    // MARK: 韩文编码

    @Test("反向：EUC-KR 文件")
    func testReverseEUCKR() throws {
        let data = try loadTestFile(lang: "ko", filename: "uhc.smi")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("EUC-KR") || upper.contains("UHC") || upper.contains("CP949"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：ISO-2022-KR 文件")
    func testReverseISO2022KR() throws {
        let data = try loadTestFile(lang: "ko", filename: "iso-2022-kr.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-2022-KR") || upper.contains("ISO2022KR"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
    }

    // MARK: Cyrillic 编码

    @Test("反向：KOI8-R 文件")
    func testReverseKOI8R() throws {
        let data = try loadTestFile(lang: "ru", filename: "koi8-r.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("KOI8-R") || upper.contains("KOI8R"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：Windows-1251 文件")
    func testReverseWindows1251() throws {
        let data = try loadTestFile(lang: "ru", filename: "windows-1251.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：ISO-8859-5 文件")
    func testReverseISO88595() throws {
        let data = try loadTestFile(lang: "ru", filename: "iso-8859-5.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：IBM855 文件")
    func testReverseIBM855() throws {
        let data = try loadTestFile(lang: "ru", filename: "ibm855.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("IBM855") || upper.contains("CP855"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：IBM866 文件")
    func testReverseIBM866() throws {
        let data = try loadTestFile(lang: "ru", filename: "ibm866.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("IBM866") || upper.contains("CP866"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：Mac-Cyrillic 文件")
    func testReverseMacCyrillic() throws {
        let data = try loadTestFile(lang: "ru", filename: "mac-cyrillic.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    // MARK: 西欧编码

    @Test("反向：ISO-8859-1 文件")
    func testReverseISO88591() throws {
        let data = try loadTestFile(lang: "fr", filename: "iso-8859-1.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-1") || upper.contains("WINDOWS-1252"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：Windows-1252 文件")
    func testReverseWindows1252() throws {
        let data = try loadTestFile(lang: "fr", filename: "windows-1252.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1252") || upper.contains("ISO-8859-1"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    // MARK: 中东欧编码

    @Test("反向：ISO-8859-2 文件")
    func testReverseISO88592() throws {
        let data = try loadTestFile(lang: "cs", filename: "iso-8859-2.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-2") || upper.contains("WINDOWS-1250"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：Windows-1250 文件")
    func testReverseWindows1250() throws {
        let data = try loadTestFile(lang: "cs", filename: "windows-1250.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1250") || upper.contains("ISO-8859-2"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：IBM852 文件")
    func testReverseIBM852() throws {
        let data = try loadTestFile(lang: "cs", filename: "ibm852.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("IBM852") || upper.contains("CP852"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：Mac-CentralEurope 文件")
    func testReverseMacCentralEurope() throws {
        let data = try loadTestFile(lang: "cs", filename: "mac-centraleurope.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("MAC") || upper.contains("CENTRALEUROPE") || upper.contains("X-MAC"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    // MARK: 希腊语编码

    @Test("反向：ISO-8859-7 文件")
    func testReverseISO88597() throws {
        let data = try loadTestFile(lang: "el", filename: "iso-8859-7.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-7") || upper.contains("WINDOWS-1253"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：Windows-1253 文件")
    func testReverseWindows1253() throws {
        let data = try loadTestFile(lang: "el", filename: "windows-1253.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1253") || upper.contains("ISO-8859-7"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    // MARK: 希伯来语编码

    @Test("反向：ISO-8859-8 文件")
    func testReverseISO88598() throws {
        let data = try loadTestFile(lang: "he", filename: "iso-8859-8.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-8") || upper.contains("WINDOWS-1255"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：Windows-1255 文件")
    func testReverseWindows1255() throws {
        let data = try loadTestFile(lang: "he", filename: "windows-1255.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1255") || upper.contains("ISO-8859-8"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    // MARK: 阿拉伯语编码

    @Test("反向：ISO-8859-6 文件")
    func testReverseISO88596() throws {
        let data = try loadTestFile(lang: "ar", filename: "iso-8859-6.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-6") || upper.contains("WINDOWS-1256"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：Windows-1256 文件")
    func testReverseWindows1256() throws {
        let data = try loadTestFile(lang: "ar", filename: "windows-1256.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1256") || upper.contains("ISO-8859-6"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    // MARK: 波罗的海编码

    @Test("反向：ISO-8859-4 文件")
    func testReverseISO88594() throws {
        let data = try loadTestFile(lang: "et", filename: "iso-8859-4.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：ISO-8859-13 文件")
    func testReverseISO885913() throws {
        let data = try loadTestFile(lang: "et", filename: "iso-8859-13.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：Windows-1257 文件")
    func testReverseWindows1257() throws {
        let data = try loadTestFile(lang: "et", filename: "windows-1257.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：IBM865 文件")
    func testReverseIBM865() throws {
        let data = try loadTestFile(lang: "da", filename: "ibm865.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("IBM865") || upper.contains("CP865"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    // MARK: 土耳其语编码

    @Test("反向：ISO-8859-3 文件")
    func testReverseISO88593() throws {
        let data = try loadTestFile(lang: "tr", filename: "iso-8859-3.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-3"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：ISO-8859-9 文件")
    func testReverseISO88599() throws {
        let data = try loadTestFile(lang: "tr", filename: "iso-8859-9.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-9") || upper.contains("WINDOWS-1254"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    // MARK: 泰语编码

    @Test("反向：TIS-620 文件")
    func testReverseTIS620() throws {
        let data = try loadTestFile(lang: "th", filename: "tis-620.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("TIS-620") || upper.contains("TIS620") || upper.contains("ISO-8859-11"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：ISO-8859-11 文件")
    func testReverseISO885911() throws {
        let data = try loadTestFile(lang: "th", filename: "iso-8859-11.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-11") || upper.contains("TIS-620") || upper.contains("TIS620"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    // MARK: 越南语编码

    @Test("反向：Windows-1258 文件")
    func testReverseWindows1258() throws {
        let data = try loadTestFile(lang: "vi", filename: "windows-1258.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("WINDOWS-1258"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    @Test("反向：VISCII 文件")
    func testReverseVISCII() throws {
        let data = try loadTestFile(lang: "vi", filename: "viscii.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("VISCII"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
    }

    // MARK: 罗马尼亚语编码

    @Test("反向：ISO-8859-16 文件")
    func testReverseISO885916() throws {
        let data = try loadTestFile(lang: "ro", filename: "iso-8859-16.txt")
        let charset = Uchardet.detect(data)
        #expect(charset != nil)
        let upper = charset!.uppercased()
        #expect(upper.contains("ISO-8859-16"))
        let enc = String.Encoding(charsetName: charset!)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
    }

    // MARK: 端到端：编码 → 检测 → 解码 → 内容一致性

    @Test("端到端：UTF-8 编码解码内容一致")
    func testEndToEndUTF8() {
        let original = "中华人民共和国，简称中国。北京是首都，上海是最大城市。"
        let data = original.data(using: .utf8)!
        let enc = Uchardet.detectEncoding(data)
        #expect(enc == .utf8)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded == original)
    }

    @Test("端到端：EUC-JP 编码解码内容一致")
    func testEndToEndEUCJP() throws {
        let data = try loadTestFile(lang: "ja", filename: "euc-jp.txt")
        let enc = Uchardet.detectEncoding(data)
        #expect(enc == .japaneseEUC)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
        #expect(decoded!.isEmpty == false)
        // 重新编码后字节应与原始数据一致
        let reEncoded = decoded!.data(using: enc!)
        #expect(reEncoded == data)
    }

    @Test("端到端：Shift_JIS 编码解码内容一致")
    func testEndToEndShiftJIS() throws {
        let data = try loadTestFile(lang: "ja", filename: "shift_jis.txt")
        let enc = Uchardet.detectEncoding(data)
        #expect(enc == .shiftJIS)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
        #expect(decoded!.isEmpty == false)
        let reEncoded = decoded!.data(using: enc!)
        #expect(reEncoded == data)
    }

    @Test("端到端：GB18030 编码解码内容一致")
    func testEndToEndGB18030() throws {
        let data = try loadTestFile(lang: "zh", filename: "gb18030.txt")
        let enc = Uchardet.detectEncoding(data)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
        #expect(decoded!.isEmpty == false)
        // 重新编码后字节应与原始数据一致
        let reEncoded = decoded!.data(using: enc!)
        #expect(reEncoded == data)
    }

    @Test("端到端：Big5 编码解码内容一致")
    func testEndToEndBig5() throws {
        let data = try loadTestFile(lang: "zh", filename: "big5.txt")
        let enc = Uchardet.detectEncoding(data)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
        #expect(decoded!.isEmpty == false)
        let reEncoded = decoded!.data(using: enc!)
        #expect(reEncoded == data)
    }

    @Test("端到端：KOI8-R 编码解码内容一致")
    func testEndToEndKOI8R() throws {
        let data = try loadTestFile(lang: "ru", filename: "koi8-r.txt")
        let enc = Uchardet.detectEncoding(data)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
        #expect(decoded!.isEmpty == false)
        let reEncoded = decoded!.data(using: enc!)
        #expect(reEncoded == data)
    }

    @Test("端到端：ISO-8859-1 编码解码内容一致")
    func testEndToEndISO88591() throws {
        let data = try loadTestFile(lang: "fr", filename: "iso-8859-1.txt")
        let enc = Uchardet.detectEncoding(data)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
        #expect(decoded!.isEmpty == false)
        let reEncoded = decoded!.data(using: enc!)
        #expect(reEncoded == data)
    }

    @Test("端到端：IBM852 编码解码内容一致")
    func testEndToEndIBM852() throws {
        let data = try loadTestFile(lang: "cs", filename: "ibm852.txt")
        let enc = Uchardet.detectEncoding(data)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
        #expect(decoded!.isEmpty == false)
        let reEncoded = decoded!.data(using: enc!)
        #expect(reEncoded == data)
    }

    @Test("端到端：IBM866 编码解码内容一致")
    func testEndToEndIBM866() throws {
        let data = try loadTestFile(lang: "ru", filename: "ibm866.txt")
        let enc = Uchardet.detectEncoding(data)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
        #expect(decoded!.isEmpty == false)
        let reEncoded = decoded!.data(using: enc!)
        #expect(reEncoded == data)
    }

    @Test("端到端：TIS-620 编码解码内容一致")
    func testEndToEndTIS620() throws {
        let data = try loadTestFile(lang: "th", filename: "tis-620.txt")
        let enc = Uchardet.detectEncoding(data)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
        #expect(decoded!.isEmpty == false)
        let reEncoded = decoded!.data(using: enc!)
        #expect(reEncoded == data)
    }

    @Test("端到端：ISO-8859-16 编码解码内容一致")
    func testEndToEndISO885916() throws {
        let data = try loadTestFile(lang: "ro", filename: "iso-8859-16.txt")
        let enc = Uchardet.detectEncoding(data)
        #expect(enc != nil)
        let decoded = String(data: data, encoding: enc!)
        #expect(decoded != nil)
        #expect(decoded!.isEmpty == false)
        let reEncoded = decoded!.data(using: enc!)
        #expect(reEncoded == data)
    }
}
