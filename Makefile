PROJECT_DIR := $(abspath .)
COMPILER ?= ablac
BUILD_DIR ?= $(PROJECT_DIR)/build
.PHONY: check test test-in-shell clean
check:
	mkdir -p $(BUILD_DIR)
	$(COMPILER) build tests/encoder_test.ab -o $(BUILD_DIR)/encoder-test --fast --no-cache
	$(COMPILER) build tests/tcp_test.ab -o $(BUILD_DIR)/tcp-test --fast --no-cache
	$(COMPILER) build examples/receipt.ab -o $(BUILD_DIR)/receipt --fast --no-cache
test: test-in-shell
test-in-shell: check
	$(BUILD_DIR)/encoder-test
	$(BUILD_DIR)/tcp-test
	$(BUILD_DIR)/receipt > $(BUILD_DIR)/receipt.bin
clean:
	rm -rf -- $(BUILD_DIR)
