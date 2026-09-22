.PHONY: project build install test clean-test-prefs icon clean

APP := build/Build/Products/Release/BTAudioSwitch.app
DEST := /Applications/BTAudioSwitch.app

project:
	xcodegen generate

build: project
	xcodebuild -project BTAudioSwitch.xcodeproj -scheme BTAudioSwitch -configuration Release -derivedDataPath build build

install: build
	rm -rf "$(DEST)"
	cp -R "$(APP)" "$(DEST)"
	@echo "$(DEST) にインストールしました。"

# 設定を司る常駐が検証の後に設定のファイルを書き戻すため、それを待ってから消す
test:
	swift test
	sleep 10 && $(MAKE) clean-test-prefs

# 接頭辞は検証が作る保存領域の名前と揃える。変数にすると、空のとき利用者の設定すべてに広がる
clean-test-prefs:
	rm -f "$(HOME)/Library/Preferences/BTAudioSwitchTests-"*.plist

# 使い捨ての実行ファイルは tmp/ でなく build/ に置く。tmp/ は他の作業の証跡を持つ共有の作業場のため
icon:
	mkdir -p build
	swiftc Scripts/makeicon.swift -o build/makeicon
	build/makeicon Resources/Assets.xcassets/AppIcon.appiconset

clean: clean-test-prefs
	rm -rf build BTAudioSwitch.xcodeproj
