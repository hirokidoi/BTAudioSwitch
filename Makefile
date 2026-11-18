.PHONY: project build install uninstall uninstall-all test icon clean

APP_NAME := BTAudioSwitch
BUNDLE_ID := com.hirokidoi.btaudioswitch
APP := build/Build/Products/Release/$(APP_NAME).app
DEST := /Applications/$(APP_NAME).app
SAVED_STATE := $(HOME)/Library/Saved Application State/$(BUNDLE_ID).savedState

project:
	xcodegen generate

build: project
	xcodebuild -project BTAudioSwitch.xcodeproj -scheme BTAudioSwitch -configuration Release -derivedDataPath build build

install: build
	rm -rf "$(DEST)"
	cp -R "$(APP)" "$(DEST)"
	@echo "$(DEST) にインストールしました。"

uninstall:
	@if [ -e "$(DEST)" ]; then \
	    rm -rf "$(DEST)" && echo "$(DEST) を削除しました。"; \
	else \
	    echo "$(DEST) はインストールされていません。"; \
	fi

# 設定は cfprefsd が持っているため、plist を直接消さず defaults で消す。
uninstall-all:
	@if pgrep -x "$(APP_NAME)" >/dev/null; then \
	    echo "$(APP_NAME) が動いています。終了してからやり直してください。"; exit 1; \
	fi; \
	targets=""; \
	for path in "$(DEST)" "$(SAVED_STATE)"; do \
	    if [ -e "$$path" ]; then targets="$$targets  $$path\n"; fi; \
	done; \
	has_defaults=0; \
	if defaults read "$(BUNDLE_ID)" >/dev/null 2>&1; then \
	    has_defaults=1; targets="$$targets  設定 (defaults のドメイン $(BUNDLE_ID))\n"; \
	fi; \
	if [ -z "$$targets" ]; then echo "削除するものはありません。"; exit 0; fi; \
	echo "次のものを削除します:"; printf "%b" "$$targets"; \
	printf "よろしいですか？ [y/N] "; read -r answer; \
	if [ "$$answer" != y ]; then echo "中止しました。"; exit 0; fi; \
	rm -rf "$(DEST)" "$(SAVED_STATE)"; \
	if [ $$has_defaults -eq 1 ]; then defaults delete "$(BUNDLE_ID)"; fi; \
	echo "削除しました。"

test:
	swift test

# 使い捨ての実行ファイルは tmp/ でなく build/ に置く。tmp/ は他の作業の証跡を持つ共有の作業場のため
icon:
	mkdir -p build
	swiftc Scripts/makeicon.swift -o build/makeicon
	build/makeicon Resources/Assets.xcassets/AppIcon.appiconset

clean:
	rm -rf build BTAudioSwitch.xcodeproj
