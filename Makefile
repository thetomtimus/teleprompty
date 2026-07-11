.PHONY: generate build test static verify-macos clean-generated

generate:
	./Scripts/bootstrap-macos.sh

build: generate
	xcodebuild -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build

test: generate
	swift test --package-path Packages/TeleprompterCore
	xcodebuild test -project PrivatePresenter.xcodeproj -scheme PrivatePresenter -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO

static:
	./Scripts/verify-wsl.sh

verify-macos:
	./Scripts/verify-macos.sh

clean-generated:
	rm -rf PrivatePresenter.xcodeproj .build/DerivedData
