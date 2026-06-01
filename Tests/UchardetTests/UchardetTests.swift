import XCTest
@testable import Uchardet

// MARK: - 辅助工具

/// 将十六进制字符串转换为 Data（用于构造特定编码的原始字节）
private func data(hex: String) -> Data {
    let hex = hex.replacingOccurrences(of: " ", with: "")
    var result = Data()
    var index = hex.startIndex
    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        if let byte = UInt8(hex[index..<next], radix: 16) {
            result.append(byte)
        }
        index = next
    }
    return result
}

// MARK: - DetectionResult 测试

final class DetectionResultTests: XCTestCase {

    // MARK: 正向：description

    func test_description_withEncoding() {
        let r = DetectionResult(charset: "UTF-8", encoding: .utf8)
        XCTAssertTrue(r.description.contains("UTF-8"), "description 应包含 charset 名称")
    }

    func test_description_withoutEncoding() {
        let r = DetectionResult(charset: "X-EXOTIC", encoding: nil)
        XCTAssertTrue(r.description.contains("X-EXOTIC"))
        XCTAssertTrue(r.description.contains("unsupported"), "不支持的编码应标注 unsupported")
    }

    // MARK: 正向：decode(_:)

    func test_decode_utf8_roundtrip() {
        let original = "Hello, 世界！Swift 封装测试。"
        let data = original.data(using: .utf8)!
        let r = DetectionResult(charset: "UTF-8", encoding: .utf8)
        XCTAssertEqual(r.decode(data), original, "UTF-8 解码应还原原始字符串")
    }

    func test_decode_ascii_roundtrip() {
        let original = "Hello, World! 0123456789"
        let data = original.data(using: .ascii)!
        let r = DetectionResult(charset: "ASCII", encoding: .ascii)
        XCTAssertEqual(r.decode(data), original)
    }

    func test_decode_shiftJIS_roundtrip() throws {
        // "日本語テスト" in Shift-JIS
        let original = "日本語テスト"
        guard let data = original.data(using: .shiftJIS) else {
            throw XCTSkip("当前平台无法编码 Shift-JIS")
        }
        let r = DetectionResult(charset: "SHIFT-JIS", encoding: .shiftJIS)
        XCTAssertEqual(r.decode(data), original, "Shift-JIS 解码应还原日文")
    }

    func test_decode_eucJP_roundtrip() throws {
        let original = "日本語テスト"
        guard let data = original.data(using: .japaneseEUC) else {
            throw XCTSkip("当前平台无法编码 EUC-JP")
        }
        let r = DetectionResult(charset: "EUC-JP", encoding: .japaneseEUC)
        XCTAssertEqual(r.decode(data), original, "EUC-JP 解码应还原日文")
    }

    func test_decode_isoLatin1_roundtrip() throws {
        let original = "Héllo Wörld"
        guard let data = original.data(using: .isoLatin1) else {
            throw XCTSkip("当前平台无法编码 ISO-8859-1")
        }
        let r = DetectionResult(charset: "ISO-8859-1", encoding: .isoLatin1)
        XCTAssertEqual(r.decode(data), original)
    }

    // MARK: 反向：decode(_:) 返回 nil

    func test_decode_returnsNil_whenEncodingIsNil() {
        let data = "test".data(using: .utf8)!
        let r = DetectionResult(charset: "X-UNSUPPORTED", encoding: nil)
        XCTAssertNil(r.decode(data), "encoding 为 nil 时 decode 应返回 nil")
    }

    func test_decode_returnsNil_whenDataIsIncompatible() {
        // 用 UTF-8 编码的中文字节，用 ASCII 解码应失败（返回 nil）
        let data = "你好世界".data(using: .utf8)!
        let r = DetectionResult(charset: "ASCII", encoding: .ascii)
        // ASCII 无法解码多字节 UTF-8，String(data:encoding:) 返回 nil
        XCTAssertNil(r.decode(data), "ASCII 无法解码 UTF-8 多字节序列，应返回 nil")
    }

    // MARK: 正向：decode(_:fallbackEncoding:)

    func test_decodeFallback_usesDetectedEncoding_whenAvailable() {
        let original = "fallback 测试"
        let data = original.data(using: .utf8)!
        let r = DetectionResult(charset: "UTF-8", encoding: .utf8)
        let result = r.decode(data, fallbackEncoding: .isoLatin1)
        XCTAssertEqual(result, original, "有有效编码时应使用检测到的编码，不使用 fallback")
    }

    func test_decodeFallback_usesFallback_whenEncodingIsNil() {
        let original = "fallback only"
        let data = original.data(using: .utf8)!
        let r = DetectionResult(charset: "X-UNSUPPORTED", encoding: nil)
        let result = r.decode(data, fallbackEncoding: .utf8)
        XCTAssertNotNil(result, "encoding 为 nil 时应使用 fallback 编码，不应返回 nil")
        XCTAssertEqual(result, original, "encoding 为 nil 时应使用 fallback 编码")
    }

    func test_decodeFallback_usesFallback_whenDecodeFails() {
        // UTF-8 多字节字节用 ASCII 解码失败，应回退到 UTF-8
        let original = "你好"
        let data = original.data(using: .utf8)!
        let r = DetectionResult(charset: "ASCII", encoding: .ascii)
        let result = r.decode(data, fallbackEncoding: .utf8)
        XCTAssertNotNil(result, "主编码解码失败时应使用 fallback，不应返回 nil")
        XCTAssertEqual(result, original, "主编码解码失败时应使用 fallback")
    }

    func test_decodeFallback_returnsNil_whenBothFail() {
        // 主编码（ASCII）和 fallback（ASCII）均无法解码 UTF-8 多字节序列
        let data = "你好".data(using: .utf8)!
        let r = DetectionResult(charset: "ASCII", encoding: .ascii)
        let result = r.decode(data, fallbackEncoding: .ascii)
        XCTAssertNil(result, "主编码与 fallback 均失败时应返回 nil，而非空字符串")
    }

    // MARK: Equatable

    func test_equatable_sameValues() {
        let r1 = DetectionResult(charset: "UTF-8", encoding: .utf8)
        let r2 = DetectionResult(charset: "UTF-8", encoding: .utf8)
        XCTAssertEqual(r1, r2)
    }

    func test_equatable_differentCharset() {
        let r1 = DetectionResult(charset: "UTF-8", encoding: .utf8)
        let r2 = DetectionResult(charset: "ASCII", encoding: .ascii)
        XCTAssertNotEqual(r1, r2)
    }
}

// MARK: - Uchardet 流式 API 测试

final class UchardetStreamTests: XCTestCase {

    // MARK: 正向：feed + finalize

    func test_feed_data_utf8() {
        let data = "这是 UTF-8 中文文本，足够长以供 uchardet 检测。这是 UTF-8 中文文本，足够长以供 uchardet 检测。".data(using: .utf8)!
        let result = Uchardet().feed(data).finalize()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.charset.uppercased(), "UTF-8")
        XCTAssertEqual(result?.encoding, .utf8)
    }

    func test_feed_bytes_ascii() {
        // 足够长的纯 ASCII 文本
        let text = String(repeating: "Hello World! This is ASCII text. ", count: 10)
        let bytes = Array(text.utf8)
        let result = Uchardet().feed(bytes).finalize()
        XCTAssertNotNil(result)
        // uchardet 对纯 ASCII 可能返回 ASCII 或 UTF-8，两者均可接受
        let charset = result?.charset.uppercased() ?? ""
        XCTAssertTrue(charset == "ASCII" || charset == "UTF-8",
                      "纯 ASCII 文本应检测为 ASCII 或 UTF-8，实际: \(charset)")
    }

    func test_feed_chaining_multipleChunks() {
        // 分块喂入，结果应与一次性喂入相同
        let text = "分块喂入测试：这段文字将被分成多个数据块依次喂入检测器，最终结果应与一次性喂入相同。"
        let data = text.data(using: .utf8)!
        let mid = data.count / 2

        let chunked = Uchardet()
            .feed(data[..<mid])
            .feed(data[mid...])
            .finalize()

        let single = Uchardet().feed(data).finalize()

        XCTAssertEqual(chunked?.charset, single?.charset, "分块喂入与一次性喂入结果应一致")
    }

    func test_feed_shiftJIS_detection() throws {
        let text = String(repeating: "日本語テキストのエンコーディング検出テスト。", count: 5)
        guard let data = text.data(using: .shiftJIS) else { throw XCTSkip("无法编码 Shift-JIS") }
        let result = Uchardet().feed(data).finalize()
        XCTAssertNotNil(result)
        let charset = result?.charset.uppercased() ?? ""
        XCTAssertTrue(charset.contains("SHIFT") || charset.contains("SJIS"),
                      "应检测为 Shift-JIS，实际: \(charset)")
        XCTAssertEqual(result?.encoding, .shiftJIS)
    }

    func test_feed_eucJP_detection() throws {
        let text = String(repeating: "日本語テキストのエンコーディング検出テスト。", count: 5)
        guard let data = text.data(using: .japaneseEUC) else { throw XCTSkip("无法编码 EUC-JP") }
        let result = Uchardet().feed(data).finalize()
        XCTAssertNotNil(result)
        let charset = result?.charset.uppercased() ?? ""
        XCTAssertTrue(charset.contains("EUC-JP") || charset.contains("EUCJP"),
                      "应检测为 EUC-JP，实际: \(charset)")
        XCTAssertEqual(result?.encoding, .japaneseEUC)
    }

    func test_feed_utf16BE_detection() throws {
        // uchardet 对无 BOM 的 UTF-16BE 数据检测结果不可靠：
        // 字节流可能被误判为 GB18030、EUC-JP 等其他编码。
        // 此测试仅验证：喂入足够数据后 uchardet 能返回某个检测结果（不为 nil）。
        let text = String(repeating: "日本語テキスト UTF-16 Big Endian 検出テスト。", count: 10)
        guard let data = text.data(using: .utf16BigEndian) else { throw XCTSkip("无法编码 UTF-16BE") }
        let result = Uchardet().feed(data).finalize()
        // 只要 uchardet 返回了某个结果即可（charset 不为空）
        XCTAssertNotNil(result, "喂入足够数据后应返回检测结果")
        XCTAssertFalse(result?.charset.isEmpty ?? true, "charset 不应为空字符串")
    }

    // MARK: 正向：finalize 幂等性

    func test_finalize_idempotent() {
        let data = "幂等性测试文本，UTF-8 编码。".data(using: .utf8)!
        let detector = Uchardet()
        detector.feed(data)
        let r1 = detector.finalize()
        let r2 = detector.finalize()
        let r3 = detector.finalize()
        XCTAssertEqual(r1?.charset, r2?.charset, "多次 finalize 结果应一致")
        XCTAssertEqual(r2?.charset, r3?.charset)
    }

    // MARK: 正向：reset 后可重新检测

    func test_reset_allowsReuse() {
        let data = "重置后重新检测，UTF-8 文本。".data(using: .utf8)!
        let detector = Uchardet()

        detector.feed(data)
        let r1 = detector.finalize()
        XCTAssertEqual(r1?.charset.uppercased(), "UTF-8")

        detector.reset()
        detector.feed(data)
        let r2 = detector.finalize()
        XCTAssertEqual(r2?.charset.uppercased(), "UTF-8", "reset 后重新检测应得到相同结果")
    }

    func test_reset_clearsPreviousState() {
        let utf8Data = "UTF-8 中文文本测试内容，足够长。UTF-8 中文文本测试内容，足够长。".data(using: .utf8)!
        let detector = Uchardet()
        detector.feed(utf8Data)
        _ = detector.finalize()

        // reset 后喂入不同数据
        detector.reset()
        let asciiText = String(repeating: "ASCII only text for detection. ", count: 10)
        let asciiData = asciiText.data(using: .ascii)!
        detector.feed(asciiData)
        let r2 = detector.finalize()
        XCTAssertNotNil(r2, "reset 后应能正常检测新数据")
    }

    // MARK: 反向：空数据返回 nil

    func test_finalize_emptyData_returnsNil() {
        XCTAssertNil(Uchardet().feed(Data()).finalize(), "空 Data 应返回 nil")
    }

    func test_finalize_emptyBytes_returnsNil() {
        XCTAssertNil(Uchardet().feed([UInt8]()).finalize(), "空字节数组应返回 nil")
    }

    func test_finalize_withoutFeed_returnsNil() {
        XCTAssertNil(Uchardet().finalize(), "未喂入任何数据应返回 nil")
    }

    // MARK: 反向：finalize 后 feed 被忽略

    func test_feed_afterFinalize_isIgnored() {
        let data = "UTF-8 文本".data(using: .utf8)!
        let detector = Uchardet()
        detector.feed(data)
        let r1 = detector.finalize()

        // finalize 后继续 feed 不应改变结果
        detector.feed("完全不同的内容 completely different".data(using: .utf8)!)
        let r2 = detector.finalize()

        XCTAssertEqual(r1?.charset, r2?.charset, "finalize 后 feed 应被忽略")
    }
}

// MARK: - 静态便捷方法测试

final class UchardetStaticTests: XCTestCase {

    // MARK: 正向：detect(_: Data)

    func test_static_detect_data_utf8() {
        let data = "静态方法检测 UTF-8 文本，内容足够长以确保检测准确。".data(using: .utf8)!
        let result = Uchardet.detect(data)
        XCTAssertEqual(result?.encoding, .utf8)
    }

    func test_static_detect_data_shiftJIS() throws {
        let text = String(repeating: "日本語テキスト検出テスト。", count: 5)
        guard let data = text.data(using: .shiftJIS) else { throw XCTSkip("无法编码 Shift-JIS") }
        let result = Uchardet.detect(data)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.encoding, .shiftJIS)
    }

    func test_static_detect_data_eucJP() throws {
        let text = String(repeating: "日本語テキスト検出テスト。", count: 5)
        guard let data = text.data(using: .japaneseEUC) else { throw XCTSkip("无法编码 EUC-JP") }
        let result = Uchardet.detect(data)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.encoding, .japaneseEUC)
    }

    // MARK: 反向：detect(_: Data) 空数据

    func test_static_detect_emptyData_returnsNil() {
        XCTAssertNil(Uchardet.detect(Data()))
    }

    // MARK: 正向：detect(bytes:)

    func test_static_detect_bytes_utf8() {
        let bytes = Array("字节数组检测测试，UTF-8 编码，内容足够长。字节数组检测测试，UTF-8 编码，内容足够长。".utf8)
        let result = Uchardet.detect(bytes: bytes)
        XCTAssertEqual(result?.encoding, .utf8)
    }

    // MARK: 反向：detect(bytes:) 空数组

    func test_static_detect_emptyBytes_returnsNil() {
        XCTAssertNil(Uchardet.detect(bytes: []))
    }

    // MARK: 正向：detect(_: URL)

    func test_static_detect_url_utf8() throws {
        let url = makeTempFile("文件检测测试，UTF-8 内容，足够长以确保准确检测。文件检测测试，UTF-8 内容，足够长以确保准确检测。", encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let result = try Uchardet.detect(url)
        XCTAssertEqual(result.encoding, .utf8)
    }

    func test_static_detect_url_shiftJIS() throws {
        let text = String(repeating: "日本語テキスト検出テスト。", count: 10)
        guard let data = text.data(using: .shiftJIS) else { throw XCTSkip("无法编码 Shift-JIS") }
        let url = makeTempFileFromData(data)
        defer { try? FileManager.default.removeItem(at: url) }
        let result = try Uchardet.detect(url)
        XCTAssertEqual(result.encoding, .shiftJIS)
    }

    func test_static_detect_url_andDecode() throws {
        let original = "文件自动解码验证：UTF-8 编码内容，解码后应与原始字符串完全一致。"
        let url = makeTempFile(original, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try Uchardet.detect(url)
        let data = try Data(contentsOf: url)
        XCTAssertEqual(result.decode(data), original, "检测后解码应还原原始内容")
    }

    // MARK: 反向：detect(_: URL) 文件不存在

    func test_static_detect_url_nonexistent_throws() {
        let url = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).txt")
        XCTAssertThrowsError(try Uchardet.detect(url), "不存在的文件应抛出错误")
    }

    // MARK: 辅助

    private func makeTempFile(_ content: String, encoding: String.Encoding) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("uchardet_\(UUID().uuidString).txt")
        try? content.data(using: encoding)?.write(to: url)
        return url
    }

    private func makeTempFileFromData(_ data: Data) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("uchardet_\(UUID().uuidString).bin")
        try? data.write(to: url)
        return url
    }
}

// MARK: - String.Encoding 扩展正向测试

final class StringEncodingPositiveTests: XCTestCase {

    // 辅助：验证 charsetName 映射到正确的 encoding，并能正确解码对应编码的字节
    private func assertRoundtrip(
        _ text: String,
        nativeEncoding: String.Encoding,
        charsetName: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let data = text.data(using: nativeEncoding) else {
            XCTFail("无法将文本编码为 \(charsetName)", file: file, line: line)
            return
        }
        guard let enc = String.Encoding(charsetName: charsetName) else {
            XCTFail("charsetName '\(charsetName)' 无法映射到 String.Encoding", file: file, line: line)
            return
        }
        XCTAssertEqual(enc, nativeEncoding,
                       "'\(charsetName)' 应映射到 \(nativeEncoding)，实际: \(enc)",
                       file: file, line: line)
        let decoded = String(data: data, encoding: enc)
        XCTAssertEqual(decoded, text,
                       "用 '\(charsetName)' 解码应还原原始文本",
                       file: file, line: line)
    }

    // MARK: Unicode

    func test_utf8()              { assertRoundtrip("Hello, 世界！", nativeEncoding: .utf8, charsetName: "UTF-8") }
    func test_utf8_lowercase()    { assertRoundtrip("Hello, 世界！", nativeEncoding: .utf8, charsetName: "utf-8") }
    func test_utf8_noHyphen()     { assertRoundtrip("Hello, 世界！", nativeEncoding: .utf8, charsetName: "UTF8") }
    func test_utf16()             { assertRoundtrip("UTF-16 test", nativeEncoding: .utf16, charsetName: "UTF-16") }
    func test_utf16BE()           { assertRoundtrip("UTF-16BE test", nativeEncoding: .utf16BigEndian, charsetName: "UTF-16BE") }
    func test_utf16LE()           { assertRoundtrip("UTF-16LE test", nativeEncoding: .utf16LittleEndian, charsetName: "UTF-16LE") }
    func test_utf32()             { assertRoundtrip("UTF-32 test", nativeEncoding: .utf32, charsetName: "UTF-32") }
    func test_utf32BE()           { assertRoundtrip("UTF-32BE test", nativeEncoding: .utf32BigEndian, charsetName: "UTF-32BE") }
    func test_utf32LE()           { assertRoundtrip("UTF-32LE test", nativeEncoding: .utf32LittleEndian, charsetName: "UTF-32LE") }

    // MARK: ASCII

    func test_ascii()             { assertRoundtrip("Hello World 123", nativeEncoding: .ascii, charsetName: "ASCII") }
    func test_usAscii()           { assertRoundtrip("Hello World 123", nativeEncoding: .ascii, charsetName: "US-ASCII") }

    // MARK: 西欧 / Latin

    func test_isoLatin1()         { assertRoundtrip("Héllo Wörld", nativeEncoding: .isoLatin1, charsetName: "ISO-8859-1") }
    func test_isoLatin1_alias()   { assertRoundtrip("Héllo Wörld", nativeEncoding: .isoLatin1, charsetName: "LATIN1") }
    func test_isoLatin2()         { assertRoundtrip("Cześć świat", nativeEncoding: .isoLatin2, charsetName: "ISO-8859-2") }
    func test_isoLatin2_alias()   { assertRoundtrip("Cześć świat", nativeEncoding: .isoLatin2, charsetName: "LATIN2") }

    // MARK: 日文

    func test_shiftJIS()          { assertRoundtrip("日本語テスト", nativeEncoding: .shiftJIS, charsetName: "SHIFT-JIS") }
    func test_shiftJIS_sjis()     { assertRoundtrip("日本語テスト", nativeEncoding: .shiftJIS, charsetName: "SJIS") }
    func test_shiftJIS_msKanji()  { assertRoundtrip("日本語テスト", nativeEncoding: .shiftJIS, charsetName: "MS-KANJI") }
    func test_eucJP()             { assertRoundtrip("日本語テスト", nativeEncoding: .japaneseEUC, charsetName: "EUC-JP") }
    func test_eucJP_xEucJP()      { assertRoundtrip("日本語テスト", nativeEncoding: .japaneseEUC, charsetName: "X-EUC-JP") }

    // MARK: 中文（需要 CFString 支持）

    func test_gb2312_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "GB2312"), "GB2312 应能映射")
    }
    func test_gbk_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "GBK"), "GBK 应能映射")
    }
    func test_gb18030_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "GB18030"), "GB18030 应能映射")
    }
    func test_gb18030_hyphen_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "GB-18030"))
    }
    func test_big5_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "BIG5"), "BIG5 应能映射")
    }
    func test_big5_hkscs_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "BIG5-HKSCS"))
    }

    func test_gb18030_roundtrip() {
        guard let enc = String.Encoding(charsetName: "GB18030") else {
            XCTFail("GB18030 映射失败"); return
        }
        let text = "简体中文 GB18030 编码测试"
        guard let data = text.data(using: enc) else {
            XCTFail("无法用 GB18030 编码"); return
        }
        XCTAssertEqual(String(data: data, encoding: enc), text, "GB18030 解码应还原原始中文")
    }

    func test_gbk_roundtrip() {
        guard let enc = String.Encoding(charsetName: "GBK") else {
            XCTFail("GBK 映射失败"); return
        }
        let text = "简体中文 GBK 编码测试"
        guard let data = text.data(using: enc) else {
            XCTFail("无法用 GBK 编码"); return
        }
        XCTAssertEqual(String(data: data, encoding: enc), text, "GBK 解码应还原原始中文")
    }

    func test_big5_roundtrip() {
        guard let enc = String.Encoding(charsetName: "BIG5") else {
            XCTFail("BIG5 映射失败"); return
        }
        let text = "繁體中文 Big5 編碼測試"
        guard let data = text.data(using: enc) else {
            XCTFail("无法用 BIG5 编码"); return
        }
        XCTAssertEqual(String(data: data, encoding: enc), text, "BIG5 解码应还原原始繁体中文")
    }

    // MARK: 韩文

    func test_eucKR_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "EUC-KR"))
    }
    func test_eucKR_uhc() {
        XCTAssertNotNil(String.Encoding(charsetName: "UHC"))
    }
    func test_eucKR_cp949() {
        XCTAssertNotNil(String.Encoding(charsetName: "CP949"))
    }

    func test_eucKR_roundtrip() {
        guard let enc = String.Encoding(charsetName: "EUC-KR") else {
            XCTFail("EUC-KR 映射失败"); return
        }
        let text = "한국어 테스트"
        guard let data = text.data(using: enc) else {
            XCTFail("无法用 EUC-KR 编码"); return
        }
        XCTAssertEqual(String(data: data, encoding: enc), text, "EUC-KR 解码应还原韩文")
    }

    // MARK: Cyrillic

    func test_windows1251_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "WINDOWS-1251"))
    }
    func test_windows1251_cp1251() {
        XCTAssertNotNil(String.Encoding(charsetName: "CP1251"))
    }
    func test_koi8R_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "KOI8-R"))
    }
    func test_koi8U_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "KOI8-U"))
    }
    func test_iso8859_5_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "ISO-8859-5"))
    }

    func test_windows1251_roundtrip() {
        guard let enc = String.Encoding(charsetName: "WINDOWS-1251") else {
            XCTFail("WINDOWS-1251 映射失败"); return
        }
        let text = "Привет мир"
        guard let data = text.data(using: enc) else {
            XCTFail("无法用 WINDOWS-1251 编码"); return
        }
        XCTAssertEqual(String(data: data, encoding: enc), text, "WINDOWS-1251 解码应还原俄文")
    }

    // MARK: 其他 Windows 编码

    func test_windows1252_notNil() { XCTAssertNotNil(String.Encoding(charsetName: "WINDOWS-1252")) }
    func test_windows1250_notNil() { XCTAssertNotNil(String.Encoding(charsetName: "WINDOWS-1250")) }
    func test_windows1253_notNil() { XCTAssertNotNil(String.Encoding(charsetName: "WINDOWS-1253")) }
    func test_windows1254_notNil() { XCTAssertNotNil(String.Encoding(charsetName: "WINDOWS-1254")) }
    func test_windows1255_notNil() { XCTAssertNotNil(String.Encoding(charsetName: "WINDOWS-1255")) }
    func test_windows1256_notNil() { XCTAssertNotNil(String.Encoding(charsetName: "WINDOWS-1256")) }
    func test_windows1257_notNil() { XCTAssertNotNil(String.Encoding(charsetName: "WINDOWS-1257")) }
    func test_windows1258_notNil() { XCTAssertNotNil(String.Encoding(charsetName: "WINDOWS-1258")) }

    // MARK: ISO-8859 系列

    func test_iso8859_3_notNil()  { XCTAssertNotNil(String.Encoding(charsetName: "ISO-8859-3")) }
    func test_iso8859_4_notNil()  { XCTAssertNotNil(String.Encoding(charsetName: "ISO-8859-4")) }
    func test_iso8859_6_notNil()  { XCTAssertNotNil(String.Encoding(charsetName: "ISO-8859-6")) }
    func test_iso8859_7_notNil()  { XCTAssertNotNil(String.Encoding(charsetName: "ISO-8859-7")) }
    func test_iso8859_8_notNil()  { XCTAssertNotNil(String.Encoding(charsetName: "ISO-8859-8")) }
    func test_iso8859_9_notNil()  { XCTAssertNotNil(String.Encoding(charsetName: "ISO-8859-9")) }
    func test_iso8859_10_notNil() { XCTAssertNotNil(String.Encoding(charsetName: "ISO-8859-10")) }
    func test_iso8859_13_notNil() { XCTAssertNotNil(String.Encoding(charsetName: "ISO-8859-13")) }
    func test_iso8859_15_notNil() { XCTAssertNotNil(String.Encoding(charsetName: "ISO-8859-15")) }
    func test_iso8859_16_notNil() { XCTAssertNotNil(String.Encoding(charsetName: "ISO-8859-16")) }

    // MARK: 泰语

    func test_tis620_notNil()     { XCTAssertNotNil(String.Encoding(charsetName: "TIS-620")) }
    func test_iso8859_11_notNil() { XCTAssertNotNil(String.Encoding(charsetName: "ISO-8859-11")) }

    // MARK: 别名一致性（同一编码的不同名称应映射到相同 encoding）

    func test_utf8_aliases_consistent() {
        let names = ["UTF-8", "utf-8", "UTF8", "utf8"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count, "所有 UTF-8 别名都应能映射")
        XCTAssertTrue(encodings.allSatisfy { $0 == .utf8 }, "所有 UTF-8 别名应映射到相同 encoding")
    }

    func test_shiftJIS_aliases_consistent() {
        let names = ["SHIFT-JIS", "SHIFTJIS", "SJIS", "X-SJIS", "MS-KANJI"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count, "所有 Shift-JIS 别名都应能映射")
        XCTAssertTrue(encodings.allSatisfy { $0 == .shiftJIS }, "所有 Shift-JIS 别名应映射到相同 encoding")
    }

    func test_eucJP_aliases_consistent() {
        let names = ["EUC-JP", "EUCJP", "X-EUC-JP"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count)
        XCTAssertTrue(encodings.allSatisfy { $0 == .japaneseEUC })
    }

    func test_ascii_aliases_consistent() {
        let names = ["ASCII", "US-ASCII", "USASCII"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count)
        XCTAssertTrue(encodings.allSatisfy { $0 == .ascii })
    }

    func test_isoLatin1_aliases_consistent() {
        let names = ["ISO-8859-1", "ISO8859-1", "LATIN1", "L1", "CSISOLATIN1"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count)
        XCTAssertTrue(encodings.allSatisfy { $0 == .isoLatin1 })
    }

    func test_windows1251_aliases_consistent() {
        let names = ["WINDOWS-1251", "CP1251", "CP-1251", "X-CP1251"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count)
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first }, "所有 Windows-1251 别名应映射到相同 encoding")
    }
}

// MARK: - String.Encoding 扩展反向测试

final class StringEncodingNegativeTests: XCTestCase {

    // MARK: 反向：无效名称返回 nil

    func test_empty_returnsNil() {
        XCTAssertNil(String.Encoding(charsetName: ""), "空字符串应返回 nil")
    }

    func test_whitespaceOnly_returnsNil() {
        XCTAssertNil(String.Encoding(charsetName: "   "), "纯空白字符串应返回 nil")
    }

    func test_unknownName_returnsNil() {
        XCTAssertNil(String.Encoding(charsetName: "INVALID-ENCODING-XYZ-999"))
    }

    func test_partialName_returnsNil() {
        XCTAssertNil(String.Encoding(charsetName: "UTF"))
    }

    func test_randomString_returnsNil() {
        XCTAssertNil(String.Encoding(charsetName: "NOT-AN-ENCODING"))
    }

    // MARK: 反向：非标准 UCS-4 字节序返回 nil

    func test_ucs4_34121_returnsNil() {
        XCTAssertNil(String.Encoding(charsetName: "X-ISO-10646-UCS-4-34121"),
                     "非标准字节序 UCS-4 应返回 nil")
    }

    func test_ucs4_21431_returnsNil() {
        XCTAssertNil(String.Encoding(charsetName: "X-ISO-10646-UCS-4-21431"),
                     "非标准字节序 UCS-4 应返回 nil")
    }

    // MARK: 反向：错误编码解码产生乱码或 nil

    func test_wrongEncoding_utf8AsASCII_returnsNil() {
        // UTF-8 多字节中文字节用 ASCII 解码应失败
        let data = "你好世界".data(using: .utf8)!
        let decoded = String(data: data, encoding: .ascii)
        XCTAssertNil(decoded, "UTF-8 多字节序列用 ASCII 解码应返回 nil")
    }

    func test_wrongEncoding_shiftJISAsUTF8_returnsNilOrGarbled() throws {
        // Shift-JIS 字节用 UTF-8 解码通常失败
        let text = String(repeating: "日本語テスト", count: 3)
        guard let sjisData = text.data(using: .shiftJIS) else { throw XCTSkip("无法编码 Shift-JIS") }
        let decoded = String(data: sjisData, encoding: .utf8)
        // Shift-JIS 字节序列通常不是合法 UTF-8，应返回 nil
        // （极少数情况下可能恰好合法，此处仅验证不等于原始文本）
        if let decoded = decoded {
            XCTAssertNotEqual(decoded, text, "Shift-JIS 字节用 UTF-8 解码不应还原原始日文")
        }
        // decoded == nil 也是正确的反向结果
    }

    func test_wrongEncoding_eucJPAsShiftJIS_notEqual() throws {
        let text = String(repeating: "日本語テスト", count: 3)
        guard let eucData = text.data(using: .japaneseEUC) else { throw XCTSkip("无法编码 EUC-JP") }
        let decoded = String(data: eucData, encoding: .shiftJIS)
        if let decoded = decoded {
            XCTAssertNotEqual(decoded, text, "EUC-JP 字节用 Shift-JIS 解码不应还原原始文本")
        }
    }

    func test_wrongEncoding_gb18030AsUTF8_returnsNilOrGarbled() throws {
        guard let enc = String.Encoding(charsetName: "GB18030") else { throw XCTSkip("GB18030 不可用") }
        let text = "简体中文测试内容"
        guard let gbData = text.data(using: enc) else { throw XCTSkip("无法用 GB18030 编码") }
        let decoded = String(data: gbData, encoding: .utf8)
        if let decoded = decoded {
            XCTAssertNotEqual(decoded, text, "GB18030 字节用 UTF-8 解码不应还原原始中文")
        }
    }

    // MARK: 反向：DetectionResult 用错误编码解码

    func test_detectionResult_wrongEncoding_notEqual() throws {
        let original = "日本語テスト"
        guard let sjisData = original.data(using: .shiftJIS) else { throw XCTSkip("无法编码 Shift-JIS") }
        // 故意用 EUC-JP 的 DetectionResult 解码 Shift-JIS 字节
        let r = DetectionResult(charset: "EUC-JP", encoding: .japaneseEUC)
        let decoded = r.decode(sjisData)
        if let decoded = decoded {
            XCTAssertNotEqual(decoded, original, "用错误编码解码不应还原原始文本")
        }
        // decoded == nil 也是正确的反向结果
    }
}

// MARK: - 端到端检测+解码验证

final class UchardetEndToEndTests: XCTestCase {

    /// 端到端验证：将文本编码为指定编码 → 用 uchardet 检测 → 用检测结果解码 → 与原始文本比较
    private func assertDetectAndDecode(
        _ text: String,
        encoding: String.Encoding,
        expectedCharsetContains keyword: String,
        alternativeKeyword: String? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let data = text.data(using: encoding) else {
            XCTFail("无法将文本编码为 \(encoding)", file: file, line: line)
            return
        }
        guard let result = Uchardet.detect(data) else {
            XCTFail("uchardet 未能检测到编码", file: file, line: line)
            return
        }
        let charsetUpper = result.charset.uppercased()
        let matches = charsetUpper.contains(keyword.uppercased()) ||
                      (alternativeKeyword.map { charsetUpper.contains($0.uppercased()) } ?? false)
        let altMsg = alternativeKeyword.map { " 或 '\($0)'" } ?? ""
        XCTAssertTrue(matches,
                      "检测到的 charset '\(result.charset)' 应包含 '\(keyword)'\(altMsg)",
                      file: file, line: line)
        guard let decoded = result.decode(data) else {
            XCTFail("无法用检测到的编码 '\(result.charset)' 解码数据", file: file, line: line)
            return
        }
        XCTAssertEqual(decoded, text,
                       "端到端解码应还原原始文本（编码: \(result.charset)）",
                       file: file, line: line)
    }

    func test_e2e_utf8_chinese() {
        let text = String(repeating: "这是一段用于端到端测试的中文文本，编码为 UTF-8。", count: 5)
        assertDetectAndDecode(text, encoding: .utf8, expectedCharsetContains: "UTF-8")
    }

    func test_e2e_shiftJIS_japanese() {
        let text = String(repeating: "日本語テキストのエンコーディング検出テスト。", count: 5)
        assertDetectAndDecode(text, encoding: .shiftJIS, expectedCharsetContains: "SHIFT")
    }

    func test_e2e_eucJP_japanese() {
        let text = String(repeating: "日本語テキストのエンコーディング検出テスト。", count: 5)
        assertDetectAndDecode(text, encoding: .japaneseEUC, expectedCharsetContains: "EUC-JP")
    }

    func test_e2e_gb18030_chinese() throws {
        guard let enc = String.Encoding(charsetName: "GB18030") else { throw XCTSkip("GB18030 不可用") }
        let text = String(repeating: "简体中文 GB18030 编码端到端测试内容。", count: 5)
        assertDetectAndDecode(text, encoding: enc, expectedCharsetContains: "GB")
    }

    func test_e2e_big5_traditional_chinese() throws {
        guard let enc = String.Encoding(charsetName: "BIG5") else { throw XCTSkip("BIG5 不可用") }
        let text = String(repeating: "繁體中文 Big5 編碼端到端測試內容。", count: 5)
        assertDetectAndDecode(text, encoding: enc, expectedCharsetContains: "BIG5")
    }

    func test_e2e_eucKR_korean() throws {
        guard let enc = String.Encoding(charsetName: "EUC-KR") else { throw XCTSkip("EUC-KR 不可用") }
        let text = String(repeating: "한국어 텍스트 인코딩 감지 테스트 내용입니다.", count: 5)
        // uchardet 对 EUC-KR 编码的韩文可能返回 "UHC"（UHC 是 EUC-KR 的超集，兼容）
        // 或 "EUC-KR"，两者均为正确结果
        assertDetectAndDecode(text, encoding: enc, expectedCharsetContains: "UHC",
                              alternativeKeyword: "EUC-KR")
    }

    func test_e2e_windows1251_russian() throws {
        guard let enc = String.Encoding(charsetName: "WINDOWS-1251") else { throw XCTSkip("WINDOWS-1251 不可用") }
        let text = String(repeating: "Это тестовый текст на русском языке для проверки кодировки.", count: 5)
        assertDetectAndDecode(text, encoding: enc, expectedCharsetContains: "1251")
    }
}

// MARK: - 补充覆盖盲区测试

// MARK: DetectionResult 补充测试

final class DetectionResultSupplementTests: XCTestCase {

    // MARK: description 包含 encoding 信息

    func test_description_withEncoding_containsEncodingInfo() {
        let r = DetectionResult(charset: "UTF-8", encoding: .utf8)
        // description 应同时包含 charset 名称和 encoding 信息（不仅仅是 charset）
        XCTAssertFalse(r.description.contains("unsupported"),
                       "有有效 encoding 时 description 不应包含 'unsupported'")
        XCTAssertTrue(r.description.contains("UTF-8"),
                      "description 应包含 charset 名称")
    }

    // MARK: Equatable：charset 相同但 encoding 不同

    func test_equatable_sameCharset_differentEncoding_notEqual() {
        // charset 相同但 encoding 不同（一个有效一个 nil）
        let r1 = DetectionResult(charset: "UTF-8", encoding: .utf8)
        let r2 = DetectionResult(charset: "UTF-8", encoding: nil)
        XCTAssertNotEqual(r1, r2, "charset 相同但 encoding 不同时应不相等")
    }

    func test_equatable_bothEncodingNil_sameCharset() {
        let r1 = DetectionResult(charset: "X-EXOTIC", encoding: nil)
        let r2 = DetectionResult(charset: "X-EXOTIC", encoding: nil)
        XCTAssertEqual(r1, r2, "charset 和 encoding 均相同时应相等")
    }

    func test_equatable_differentCharset_sameEncoding() {
        // charset 不同但 encoding 相同（如 UTF-8 和 utf8 都映射到 .utf8）
        let r1 = DetectionResult(charset: "UTF-8", encoding: .utf8)
        let r2 = DetectionResult(charset: "utf8", encoding: .utf8)
        XCTAssertNotEqual(r1, r2, "charset 字符串不同时应不相等（大小写敏感）")
    }

    // MARK: decode 空 Data

    func test_decode_emptyData_utf8() {
        let r = DetectionResult(charset: "UTF-8", encoding: .utf8)
        // 空 Data 用 UTF-8 解码应返回空字符串（不是 nil）
        let result = r.decode(Data())
        XCTAssertNotNil(result, "空 Data 用 UTF-8 解码应返回空字符串而非 nil")
        XCTAssertEqual(result, "", "空 Data 解码应得到空字符串")
    }

    func test_decodeFallback_emptyData() {
        let r = DetectionResult(charset: "UTF-8", encoding: .utf8)
        let result = r.decode(Data(), fallbackEncoding: .ascii)
        XCTAssertNotNil(result, "空 Data 用 fallback 解码应返回空字符串")
        XCTAssertEqual(result, "")
    }
}

// MARK: - Uchardet 补充测试

final class UchardetSupplementTests: XCTestCase {

    // MARK: detect(_:URL) 空文件返回 nil

    func test_detect_url_emptyFile_throws() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("uchardet_empty_\(UUID().uuidString).txt")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        // detect(url:) 对空文件无法识别编码，应抛出 UchardetError.unrecognizedEncoding
        XCTAssertThrowsError(try Uchardet.detect(url), "空文件应抛出错误") { error in
            if let uchardetError = error as? UchardetError {
                XCTAssertEqual(uchardetError, .unrecognizedEncoding,
                               "空文件应抛出 unrecognizedEncoding 错误")
            }
        }
    }

    // MARK: detect(_:URL) 自定义 sampleSize

    func test_detect_url_customSampleSize() throws {
        // 写入足够大的 UTF-8 文件，用极小的 sampleSize 仍能检测
        let text = String(repeating: "UTF-8 中文内容用于采样检测。", count: 100)
        let data = text.data(using: .utf8)!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("uchardet_sample_\(UUID().uuidString).txt")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        // 只采样前 512 字节
        let result = try Uchardet.detect(url, sampleSize: 512)
        XCTAssertEqual(result.encoding, .utf8, "采样 512 字节应能检测为 UTF-8")
    }

    func test_detect_url_customChunkSize() throws {
        let text = String(repeating: "UTF-8 文本内容，用于测试自定义 chunkSize。", count: 50)
        let data = text.data(using: .utf8)!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("uchardet_chunk_\(UUID().uuidString).txt")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        // 使用极小的 chunkSize（16 字节），结果应与默认一致
        let resultSmallChunk = try Uchardet.detect(url, chunkSize: 16)
        let resultDefault = try Uchardet.detect(url)
        XCTAssertEqual(resultSmallChunk.charset, resultDefault.charset,
                       "自定义 chunkSize 不应影响检测结果")
    }

    // MARK: 多实例独立性

    func test_multipleInstances_independent() {
        let utf8Text = String(repeating: "UTF-8 中文文本检测。", count: 10)
        let utf8Data = utf8Text.data(using: .utf8)!

        let d1 = Uchardet()
        let d2 = Uchardet()

        d1.feed(utf8Data)
        // d2 未喂入任何数据

        let r1 = d1.finalize()
        let r2 = d2.finalize()

        XCTAssertNotNil(r1, "d1 应有检测结果")
        XCTAssertNil(r2, "d2 未喂入数据，应返回 nil")
        XCTAssertEqual(r1?.charset.uppercased(), "UTF-8")
    }

    func test_multipleInstances_differentEncodings() throws {
        let utf8Text = String(repeating: "UTF-8 中文文本。", count: 10)
        let utf8Data = utf8Text.data(using: .utf8)!

        let sjisText = String(repeating: "日本語テキスト。", count: 10)
        guard let sjisData = sjisText.data(using: .shiftJIS) else { throw XCTSkip("无法编码 Shift-JIS") }

        let d1 = Uchardet()
        let d2 = Uchardet()

        d1.feed(utf8Data)
        d2.feed(sjisData)

        let r1 = d1.finalize()
        let r2 = d2.finalize()

        XCTAssertEqual(r1?.charset.uppercased(), "UTF-8", "d1 应检测为 UTF-8")
        XCTAssertEqual(r2?.encoding, .shiftJIS, "d2 应检测为 Shift-JIS")
        // 两个实例互不干扰
        XCTAssertNotEqual(r1?.charset, r2?.charset, "两个实例检测结果应不同")
    }

    // MARK: reset 后 finalize 不崩溃

    func test_reset_thenFinalize_withoutFeed_returnsNil() {
        let detector = Uchardet()
        let data = "UTF-8 文本".data(using: .utf8)!
        detector.feed(data)
        _ = detector.finalize()

        detector.reset()
        // reset 后不 feed，直接 finalize
        let result = detector.finalize()
        XCTAssertNil(result, "reset 后不 feed 直接 finalize 应返回 nil")
    }

    // MARK: 大数据量检测

    func test_largeData_utf8() {
        // 1MB UTF-8 数据
        let text = String(repeating: "大数据量 UTF-8 检测测试内容，确保性能和正确性。", count: 3000)
        let data = text.data(using: .utf8)!
        XCTAssertGreaterThan(data.count, 100_000, "测试数据应超过 100KB")
        let result = Uchardet.detect(data)
        XCTAssertEqual(result?.encoding, .utf8, "大数据量 UTF-8 应正确检测")
    }
}

// MARK: - String.Encoding 补充测试

final class StringEncodingSupplementTests: XCTestCase {

    // MARK: 下划线转连字符

    func test_underscoreToHyphen_utf8() {
        // "UTF_8" 中的下划线应被转换为连字符后匹配 "UTF-8"
        XCTAssertEqual(String.Encoding(charsetName: "UTF_8"), .utf8,
                       "UTF_8（下划线）应映射到 UTF-8")
    }

    func test_underscoreToHyphen_iso8859() {
        // "ISO_8859_1" 应映射到 ISO-8859-1
        XCTAssertEqual(String.Encoding(charsetName: "ISO_8859_1"), .isoLatin1,
                       "ISO_8859_1（下划线）应映射到 ISO-8859-1")
    }

    func test_underscoreToHyphen_windows1251() {
        let enc1 = String.Encoding(charsetName: "WINDOWS_1251")
        let enc2 = String.Encoding(charsetName: "WINDOWS-1251")
        XCTAssertEqual(enc1, enc2, "WINDOWS_1251 和 WINDOWS-1251 应映射到相同编码")
    }

    // MARK: 大小写不敏感

    func test_caseInsensitive_mixedCase() {
        let variants = ["Utf-8", "UTF-8", "utf-8", "uTf-8", "UTF8", "utf8"]
        let encodings = variants.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, variants.count, "所有大小写变体都应能映射")
        XCTAssertTrue(encodings.allSatisfy { $0 == .utf8 }, "所有变体应映射到 .utf8")
    }

    func test_caseInsensitive_shiftJIS() {
        let variants = ["shift-jis", "Shift-JIS", "SHIFT-JIS", "shift_jis"]
        let encodings = variants.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, variants.count)
        XCTAssertTrue(encodings.allSatisfy { $0 == .shiftJIS })
    }

    // MARK: 前后空白被忽略

    func test_leadingTrailingWhitespace_utf8() {
        // 前后有空白的 charset 名称应能正确映射
        XCTAssertEqual(String.Encoding(charsetName: "  UTF-8  "), .utf8,
                       "前后空白应被忽略")
    }

    func test_leadingWhitespace_ascii() {
        XCTAssertEqual(String.Encoding(charsetName: "\tASCII\n"), .ascii,
                       "制表符和换行符应被忽略")
    }

    // MARK: EUC-KR 别名一致性

    func test_eucKR_aliases_consistent() {
        let names = ["EUC-KR", "EUCKR", "UHC", "CP949"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count, "所有 EUC-KR 别名都应能映射")
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first }, "所有 EUC-KR 别名应映射到相同 encoding")
    }

    // MARK: GB 系列别名一致性

    func test_gb18030_aliases_consistent() {
        let names = ["GB18030", "GB-18030"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count)
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first })
    }

    // MARK: ISO-2022 系列可映射

    func test_iso2022JP_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "ISO-2022-JP"), "ISO-2022-JP 应能映射")
    }

    func test_iso2022JP_aliases_consistent() {
        let names = ["ISO-2022-JP", "ISO2022JP", "CSISO2022JP"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count)
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first })
    }

    // MARK: KOI8 系列

    func test_koi8R_aliases_consistent() {
        let names = ["KOI8-R", "KOI8R", "CSKOI8R"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count)
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first })
    }

    // MARK: 反向：仅含空白字符（各种空白）

    func test_tabOnly_returnsNil() {
        XCTAssertNil(String.Encoding(charsetName: "\t"), "仅含制表符应返回 nil")
    }

    func test_newlineOnly_returnsNil() {
        XCTAssertNil(String.Encoding(charsetName: "\n"), "仅含换行符应返回 nil")
    }

    func test_mixedWhitespace_returnsNil() {
        XCTAssertNil(String.Encoding(charsetName: " \t \n "), "混合空白应返回 nil")
    }
}

// MARK: - String.Encoding 深度盲区补充测试

final class StringEncodingDeepCoverageTests: XCTestCase {

    // MARK: DOS / IBM 编码

    func test_ibm852_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "IBM852"), "IBM852 应能映射")
    }

    func test_cp852_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "CP852"), "CP852 应能映射")
    }

    func test_ibm852_cp852_consistent() {
        let e1 = String.Encoding(charsetName: "IBM852")
        let e2 = String.Encoding(charsetName: "CP852")
        XCTAssertEqual(e1, e2, "IBM852 和 CP852 应映射到相同编码")
    }

    func test_ibm855_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "IBM855"), "IBM855 应能映射")
    }

    func test_cp855_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "CP855"), "CP855 应能映射")
    }

    func test_ibm855_cp855_consistent() {
        let e1 = String.Encoding(charsetName: "IBM855")
        let e2 = String.Encoding(charsetName: "CP855")
        XCTAssertEqual(e1, e2, "IBM855 和 CP855 应映射到相同编码")
    }

    func test_ibm866_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "IBM866"), "IBM866 应能映射")
    }

    func test_cp866_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "CP866"), "CP866 应能映射")
    }

    func test_ibm866_cp866_consistent() {
        let e1 = String.Encoding(charsetName: "IBM866")
        let e2 = String.Encoding(charsetName: "CP866")
        XCTAssertEqual(e1, e2, "IBM866 和 CP866 应映射到相同编码")
    }

    func test_ibm865_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "IBM865"), "IBM865 应能映射")
    }

    func test_cp865_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "CP865"), "CP865 应能映射")
    }

    func test_ibm865_cp865_consistent() {
        let e1 = String.Encoding(charsetName: "IBM865")
        let e2 = String.Encoding(charsetName: "CP865")
        XCTAssertEqual(e1, e2, "IBM865 和 CP865 应映射到相同编码")
    }

    // MARK: Mac 编码

    func test_macCyrillic_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "MAC-CYRILLIC"), "MAC-CYRILLIC 应能映射")
    }

    func test_macCyrillic_aliases_consistent() {
        let names = ["MAC-CYRILLIC", "MACCYRILLIC", "X-MAC-CYRILLIC"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count, "所有 MAC-CYRILLIC 别名都应能映射")
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first }, "所有 MAC-CYRILLIC 别名应映射到相同编码")
    }

    func test_macCentralEurope_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "MAC-CENTRALEUROPE"), "MAC-CENTRALEUROPE 应能映射")
    }

    func test_macCentralEurope_aliases_consistent() {
        let names = ["MAC-CENTRALEUROPE", "MACCENTRALEUROPE", "X-MAC-CENTRALEUROPE", "MAC-CE", "MACCE"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count, "所有 MAC-CENTRALEUROPE 别名都应能映射")
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first }, "所有 MAC-CENTRALEUROPE 别名应映射到相同编码")
    }

    // MARK: CJK 扩展编码

    func test_eucTW_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "EUC-TW"), "EUC-TW 应能映射")
    }

    func test_eucTW_aliases_consistent() {
        let names = ["EUC-TW", "EUCTW", "X-EUC-TW"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count, "所有 EUC-TW 别名都应能映射")
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first }, "所有 EUC-TW 别名应映射到相同编码")
    }

    func test_iso2022KR_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "ISO-2022-KR"), "ISO-2022-KR 应能映射")
    }

    func test_iso2022KR_aliases_consistent() {
        let names = ["ISO-2022-KR", "ISO2022KR", "CSISO2022KR"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count)
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first })
    }

    func test_iso2022CN_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "ISO-2022-CN"), "ISO-2022-CN 应能映射")
    }

    func test_iso2022CN_aliases_consistent() {
        let names = ["ISO-2022-CN", "ISO2022CN", "CSISO2022CN"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count)
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first })
    }

    // MARK: BIG5 扩展别名

    func test_big5_hkscs_2004_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "BIG5-HKSCS:2004"), "BIG5-HKSCS:2004 应能映射")
    }

    func test_big5_hkscs_2001_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "BIG5-HKSCS:2001"), "BIG5-HKSCS:2001 应能映射")
    }

    func test_big5_hkscs_1999_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "BIG5-HKSCS:1999"), "BIG5-HKSCS:1999 应能映射")
    }

    func test_cnBig5_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "CN-BIG5"), "CN-BIG5 应能映射")
    }

    func test_cnGB_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "CN-GB"), "CN-GB 应能映射")
    }

    func test_big5_variants_consistent() {
        let names = ["BIG5", "BIG-5", "BIG5-HKSCS", "BIG5-HKSCS:2004", "CN-BIG5"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count, "所有 BIG5 变体都应能映射")
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first }, "所有 BIG5 变体应映射到相同编码")
    }

    // MARK: 含空格的别名

    func test_shiftJIS_withSpace_notNil() {
        // "SHIFT JIS"（含空格）在 switch 中有明确处理
        XCTAssertNotNil(String.Encoding(charsetName: "SHIFT JIS"), "SHIFT JIS（含空格）应能映射")
    }

    func test_shiftJIS_withSpace_equalsShiftJIS() {
        XCTAssertEqual(String.Encoding(charsetName: "SHIFT JIS"), .shiftJIS,
                       "SHIFT JIS（含空格）应映射到 .shiftJIS")
    }

    func test_usAscii_withSpace_notNil() {
        // "US ASCII"（含空格）在 switch 中有明确处理
        XCTAssertNotNil(String.Encoding(charsetName: "US ASCII"), "US ASCII（含空格）应能映射")
    }

    func test_usAscii_withSpace_equalsAscii() {
        XCTAssertEqual(String.Encoding(charsetName: "US ASCII"), .ascii,
                       "US ASCII（含空格）应映射到 .ascii")
    }

    // MARK: HZ 编码（回退到 GB2312）

    func test_hzGB2312_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "HZ-GB-2312"), "HZ-GB-2312 应能映射（回退到 GB2312）")
    }

    func test_hz_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "HZ"), "HZ 应能映射（回退到 GB2312）")
    }

    func test_hzGB2312_aliases_consistent() {
        let names = ["HZ-GB-2312", "HZ", "HZ-GB2312"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count, "所有 HZ 别名都应能映射")
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first }, "所有 HZ 别名应映射到相同编码（GB2312）")
    }

    func test_hzGB2312_equalsGB2312() {
        let hz = String.Encoding(charsetName: "HZ-GB-2312")
        let gb = String.Encoding(charsetName: "GB2312")
        XCTAssertEqual(hz, gb, "HZ-GB-2312 应回退到与 GB2312 相同的编码")
    }

    // MARK: CS 前缀别名

    func test_csgb2312_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "CSGB2312"), "CSGB2312 应能映射")
    }

    func test_csgb2312_equalsGB2312() {
        let e1 = String.Encoding(charsetName: "CSGB2312")
        let e2 = String.Encoding(charsetName: "GB2312")
        XCTAssertEqual(e1, e2, "CSGB2312 应与 GB2312 映射到相同编码")
    }

    func test_csisolatin1_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "CSISOLATIN1"), "CSISOLATIN1 应能映射")
    }

    func test_csisolatin1_equalsIsoLatin1() {
        XCTAssertEqual(String.Encoding(charsetName: "CSISOLATIN1"), .isoLatin1,
                       "CSISOLATIN1 应映射到 .isoLatin1")
    }

    func test_cskoi8r_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "CSKOI8R"), "CSKOI8R 应能映射")
    }

    // MARK: 韩文 ISO 别名

    func test_ksC5601_1987_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "KS-C-5601-1987"), "KS-C-5601-1987 应能映射")
    }

    func test_ksC5601_1989_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "KS-C-5601-1989"), "KS-C-5601-1989 应能映射")
    }

    func test_ksC5601_equalsEucKR() {
        let e1 = String.Encoding(charsetName: "KS-C-5601-1987")
        let e2 = String.Encoding(charsetName: "EUC-KR")
        XCTAssertEqual(e1, e2, "KS-C-5601-1987 应与 EUC-KR 映射到相同编码")
    }

    // MARK: 希伯来语

    func test_iso8859_8_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "ISO-8859-8"), "ISO-8859-8 应能映射")
    }

    func test_hebrew_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "HEBREW"), "HEBREW 应能映射")
    }

    func test_iso8859_8_aliases_consistent() {
        let names = ["ISO-8859-8", "ISO8859-8", "HEBREW", "ISO-IR-138", "CSISOLATINHEBREW"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count, "所有 ISO-8859-8 别名都应能映射")
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first }, "所有 ISO-8859-8 别名应映射到相同编码")
    }

    // MARK: 阿拉伯语

    func test_iso8859_6_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "ISO-8859-6"), "ISO-8859-6 应能映射")
    }

    func test_arabic_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "ARABIC"), "ARABIC 应能映射")
    }

    func test_iso8859_6_aliases_consistent() {
        let names = ["ISO-8859-6", "ISO8859-6", "ARABIC", "ISO-IR-127", "CSISOLATINARABIC"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count, "所有 ISO-8859-6 别名都应能映射")
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first }, "所有 ISO-8859-6 别名应映射到相同编码")
    }

    // MARK: 罗马尼亚语

    func test_iso8859_16_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "ISO-8859-16"), "ISO-8859-16 应能映射")
    }

    func test_latin10_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "LATIN10"), "LATIN10 应能映射")
    }

    func test_iso8859_16_aliases_consistent() {
        let names = ["ISO-8859-16", "ISO8859-16", "LATIN10", "L10", "ISO-IR-226"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count, "所有 ISO-8859-16 别名都应能映射")
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first }, "所有 ISO-8859-16 别名应映射到相同编码")
    }

    // MARK: 越南语

    func test_viscii_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "VISCII"), "VISCII 应能映射")
    }

    func test_viscii_alias_consistent() {
        let e1 = String.Encoding(charsetName: "VISCII")
        let e2 = String.Encoding(charsetName: "VISCII1.1-1")
        XCTAssertEqual(e1, e2, "VISCII 和 VISCII1.1-1 应映射到相同编码")
    }

    func test_windows1258_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "WINDOWS-1258"), "WINDOWS-1258 应能映射")
    }

    func test_windows1258_aliases_consistent() {
        let names = ["WINDOWS-1258", "CP1258", "CP-1258", "X-CP1258"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count, "所有 WINDOWS-1258 别名都应能映射")
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first }, "所有 WINDOWS-1258 别名应映射到相同编码")
    }

    // MARK: 希腊语

    func test_greek_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "GREEK"), "GREEK 应能映射")
    }

    func test_greek8_notNil() {
        XCTAssertNotNil(String.Encoding(charsetName: "GREEK8"), "GREEK8 应能映射")
    }

    func test_iso8859_7_aliases_consistent() {
        let names = ["ISO-8859-7", "ISO8859-7", "GREEK", "GREEK8", "ISO-IR-126", "CSISOLATINGREEK"]
        let encodings = names.compactMap { String.Encoding(charsetName: $0) }
        XCTAssertEqual(encodings.count, names.count, "所有 ISO-8859-7 别名都应能映射")
        let first = encodings[0]
        XCTAssertTrue(encodings.allSatisfy { $0 == first }, "所有 ISO-8859-7 别名应映射到相同编码")
    }

    // MARK: description 格式精确验证

    func test_description_format_withEncoding() {
        let r = DetectionResult(charset: "UTF-8", encoding: .utf8)
        // 格式应为 "UTF-8 (StringEncoding)"，包含括号
        XCTAssertTrue(r.description.hasPrefix("UTF-8 ("),
                      "description 应以 'charset (' 开头，实际: \(r.description)")
        XCTAssertTrue(r.description.hasSuffix(")"),
                      "description 应以 ')' 结尾，实际: \(r.description)")
    }

    func test_description_format_withoutEncoding() {
        let r = DetectionResult(charset: "X-EXOTIC", encoding: nil)
        XCTAssertEqual(r.description, "X-EXOTIC (unsupported)",
                       "无 encoding 时 description 应为 'charset (unsupported)'")
    }
}

// MARK: - Uchardet 深度盲区补充测试

final class UchardetDeepCoverageTests: XCTestCase {

    // MARK: sampleSize 边界值

    func test_detect_url_sampleSize_1() throws {
        // sampleSize=1 极小采样，只读 1 字节，uchardet 无法识别编码会抛出错误
        // 此测试验证：不会崩溃（抛出错误是可接受的行为）
        let text = String(repeating: "UTF-8 中文内容。", count: 100)
        let data = text.data(using: .utf8)!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("uchardet_s1_\(UUID().uuidString).txt")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        // sampleSize=1 只读 1 字节，可能抛出 unrecognizedEncoding，也可能成功（取决于 uchardet 实现）
        // 关键是不应崩溃（不抛出 fatalError 或 EXC_BAD_ACCESS）
        do {
            _ = try Uchardet.detect(url, sampleSize: 1)
            // 成功也是可接受的
        } catch let error as UchardetError {
            // 抛出 UchardetError 是预期行为
            XCTAssertTrue(
                error == .unrecognizedEncoding || error == .insufficientData,
                "sampleSize=1 应抛出 unrecognizedEncoding 或 insufficientData，实际: \(error)"
            )
        } catch {
            XCTFail("sampleSize=1 不应抛出非 UchardetError 类型的错误: \(error)")
        }
    }

    func test_detect_url_chunkSizeLargerThanSampleSize() throws {
        // chunkSize > sampleSize 时，effectiveChunk = min(chunkSize, sampleSize) = sampleSize
        let text = String(repeating: "UTF-8 中文内容用于测试。", count: 50)
        let data = text.data(using: .utf8)!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("uchardet_cs_\(UUID().uuidString).txt")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        // chunkSize(65536) > sampleSize(512)，应正常工作
        let result = try Uchardet.detect(url, sampleSize: 512, chunkSize: 65_536)
        XCTAssertEqual(result.encoding, .utf8, "chunkSize > sampleSize 时应能正常检测")
    }

    // MARK: 连续 reset

    func test_consecutiveReset_nocrash() {
        let detector = Uchardet()
        let data = "UTF-8 文本".data(using: .utf8)!
        detector.feed(data)
        _ = detector.finalize()

        // 连续两次 reset 不应崩溃
        detector.reset()
        detector.reset()

        // reset 后正常使用
        detector.feed(data)
        let result = detector.finalize()
        XCTAssertNotNil(result, "连续 reset 后应能正常检测")
    }

    func test_reset_withoutFeed_nocrash() {
        // 未喂入数据直接 reset 不应崩溃
        let detector = Uchardet()
        XCTAssertNoThrow(detector.reset(), "未喂入数据直接 reset 不应崩溃")
    }

    // MARK: detect(bytes:) 端到端

    func test_e2e_detectBytes_utf8() {
        let text = String(repeating: "字节数组端到端检测测试，UTF-8 编码。", count: 5)
        let bytes = Array(text.utf8)
        guard let result = Uchardet.detect(bytes: bytes) else {
            XCTFail("detect(bytes:) 应返回检测结果")
            return
        }
        XCTAssertEqual(result.charset.uppercased(), "UTF-8", "应检测为 UTF-8")
        let data = Data(bytes)
        let decoded = result.decode(data)
        XCTAssertEqual(decoded, text, "detect(bytes:) 端到端解码应还原原始文本")
    }

    func test_e2e_detectBytes_shiftJIS() throws {
        let text = String(repeating: "日本語テキスト検出テスト。", count: 5)
        guard let sjisData = text.data(using: .shiftJIS) else { throw XCTSkip("无法编码 Shift-JIS") }
        let bytes = Array(sjisData)
        guard let result = Uchardet.detect(bytes: bytes) else {
            XCTFail("detect(bytes:) 应返回检测结果")
            return
        }
        XCTAssertEqual(result.encoding, .shiftJIS, "应检测为 Shift-JIS")
        let decoded = result.decode(sjisData)
        XCTAssertEqual(decoded, text, "detect(bytes:) Shift-JIS 端到端解码应还原原始文本")
    }

    // MARK: 链式 detect + decode

    func test_chainedDetectAndDecode_utf8() {
        let text = String(repeating: "链式调用测试，UTF-8 编码内容。", count: 5)
        let data = text.data(using: .utf8)!
        // 链式：detect → decode
        let decoded = Uchardet.detect(data)?.decode(data)
        XCTAssertEqual(decoded, text, "链式 detect + decode 应还原原始文本")
    }

    func test_chainedDetectAndDecode_withFallback() {
        let text = String(repeating: "链式 fallback 测试，UTF-8 编码。", count: 5)
        let data = text.data(using: .utf8)!
        // 链式：detect → decode(fallbackEncoding:)
        let decoded = Uchardet.detect(data)?.decode(data, fallbackEncoding: .isoLatin1)
        XCTAssertEqual(decoded, text, "链式 detect + decode(fallbackEncoding:) 应还原原始文本")
    }

    // MARK: 端到端：更多编码

    func test_e2e_iso8859_7_greek() throws {
        guard let enc = String.Encoding(charsetName: "ISO-8859-7") else {
            throw XCTSkip("ISO-8859-7 不可用")
        }
        let text = String(repeating: "Ελληνικό κείμενο για δοκιμή κωδικοποίησης.", count: 5)
        guard let data = text.data(using: enc) else {
            throw XCTSkip("无法将希腊语文本编码为 ISO-8859-7")
        }
        guard let result = Uchardet.detect(data) else {
            XCTFail("uchardet 未能检测到编码")
            return
        }
        let charsetUpper = result.charset.uppercased()
        XCTAssertTrue(charsetUpper.contains("8859-7") || charsetUpper.contains("GREEK") || charsetUpper.contains("1253"),
                      "应检测为 ISO-8859-7 或 GREEK 或 Windows-1253，实际: \(result.charset)")
        // 验证能解码（不要求与原文完全一致，因为 uchardet 可能返回兼容编码）
        XCTAssertNotNil(result.decode(data), "应能用检测到的编码解码")
    }

    func test_e2e_koi8r_russian() throws {
        guard let enc = String.Encoding(charsetName: "KOI8-R") else {
            throw XCTSkip("KOI8-R 不可用")
        }
        let text = String(repeating: "Русский текст для проверки кодировки KOI8-R.", count: 5)
        guard let data = text.data(using: enc) else {
            throw XCTSkip("无法将俄语文本编码为 KOI8-R")
        }
        guard let result = Uchardet.detect(data) else {
            XCTFail("uchardet 未能检测到编码")
            return
        }
        let charsetUpper = result.charset.uppercased()
        XCTAssertTrue(charsetUpper.contains("KOI8") || charsetUpper.contains("1251") || charsetUpper.contains("8859-5"),
                      "应检测为 KOI8-R 或兼容 Cyrillic 编码，实际: \(result.charset)")
        XCTAssertNotNil(result.decode(data), "应能用检测到的编码解码")
    }

    func test_e2e_iso8859_1_western() throws {
        // ISO-8859-1 西欧语言端到端
        let text = String(repeating: "Héllo Wörld, café résumé naïve.", count: 10)
        guard let data = text.data(using: .isoLatin1) else {
            throw XCTSkip("无法将文本编码为 ISO-8859-1")
        }
        guard let result = Uchardet.detect(data) else {
            XCTFail("uchardet 未能检测到编码")
            return
        }
        // uchardet 对 ISO-8859-1 可能返回 ISO-8859-1 或 WINDOWS-1252（兼容超集）
        let charsetUpper = result.charset.uppercased()
        XCTAssertTrue(charsetUpper.contains("8859-1") || charsetUpper.contains("1252") || charsetUpper.contains("LATIN"),
                      "应检测为 ISO-8859-1 或 WINDOWS-1252，实际: \(result.charset)")
        XCTAssertNotNil(result.decode(data), "应能用检测到的编码解码")
    }

    // MARK: 大 Data 解码性能

    func test_decode_largeData() {
        // 验证 decode 对大数据量不崩溃且结果正确
        let text = String(repeating: "大数据量解码测试内容，UTF-8 编码。", count: 5000)
        let data = text.data(using: .utf8)!
        XCTAssertGreaterThan(data.count, 200_000, "测试数据应超过 200KB")
        let r = DetectionResult(charset: "UTF-8", encoding: .utf8)
        let decoded = r.decode(data)
        XCTAssertEqual(decoded, text, "大数据量 decode 应正确还原原始文本")
    }
}
