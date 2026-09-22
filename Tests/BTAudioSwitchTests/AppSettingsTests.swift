import Testing
@testable import BTAudioSwitch

@Suite("アイコンの表示可否")
struct AppSettingsTests {
    @Test("常時表示なら接続状態・設定画面の状態によらず表示する")
    func alwaysShowsRegardlessOfConnection() {
        #expect(IconVisibility.always.showsIcon(isConnected: true, isSettingsOpen: false, isWithinStartupGrace: false))
        #expect(IconVisibility.always.showsIcon(isConnected: false, isSettingsOpen: false, isWithinStartupGrace: false))
    }

    @Test("接続時のみ表示は接続状態に従う")
    func whileConnectedFollowsConnectionState() {
        #expect(IconVisibility.whileConnected.showsIcon(isConnected: true, isSettingsOpen: false, isWithinStartupGrace: false))
        #expect(!IconVisibility.whileConnected.showsIcon(isConnected: false, isSettingsOpen: false, isWithinStartupGrace: false))
    }

    @Test("接続時のみ表示でも設定画面が開いていれば表示する")
    func whileConnectedShowsWhenSettingsOpen() {
        #expect(IconVisibility.whileConnected.showsIcon(isConnected: false, isSettingsOpen: true, isWithinStartupGrace: false))
    }

    @Test("接続時のみ表示でも起動直後の猶予中は表示する")
    func whileConnectedShowsWithinStartupGrace() {
        #expect(IconVisibility.whileConnected.showsIcon(isConnected: false, isSettingsOpen: false, isWithinStartupGrace: true))
    }
}
