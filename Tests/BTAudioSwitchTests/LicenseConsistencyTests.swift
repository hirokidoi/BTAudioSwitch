import Foundation
import Testing
@testable import BTAudioSwitch

@Suite("ライセンス表示")
struct LicenseConsistencyTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    // LICENSE は名前・著作権表示・許諾本文の順に空行区切りで並ぶ前提で読む
    @Test("About に出す名前と著作権表示がリポジトリの LICENSE の先頭と一致する")
    func displayedLicenseMatchesRepositoryLicense() throws {
        let contents = try String(contentsOf: Self.root.appendingPathComponent("LICENSE"), encoding: .utf8)
        let paragraphs = contents
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        #expect(AppLicense.nameAndCopyright == paragraphs.prefix(2).joined(separator: "\n"))
    }

    @Test("アプリのビルド設定が LICENSE をリソースに取り込む")
    func appBundlesLicense() throws {
        let definition = try String(contentsOf: Self.root.appendingPathComponent("project.yml"), encoding: .utf8)
        let lines = definition.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        let licenseLine = try #require(lines.firstIndex(of: "- path: LICENSE"))
        let nextLine = try #require(lines.indices.contains(licenseLine + 1) ? lines[licenseLine + 1] : nil)
        #expect(nextLine == "buildPhase: resources")
    }
}
