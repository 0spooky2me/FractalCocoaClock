XCODEBUILD:= xcodebuild

all: build

build: clean
	$(XCODEBUILD) build

.PHONY: clean
clean:
	$(XCODEBUILD) clean
