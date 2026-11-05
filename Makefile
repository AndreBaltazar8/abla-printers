PROJECT_DIR := $(abspath .)
COMPILER ?= ablac
BUILD_DIR ?= $(PROJECT_DIR)/build
.PHONY: check test test-in-shell clean
check:
	mkdir -p $(BUILD_DIR)
	$(COMPILER) build tests/encoder_test.ab -o $(BUILD_DIR)/encoder-test --fast --no-cache
	$(COMPILER) build tests/device_result_test.ab -o $(BUILD_DIR)/device-result-test --fast --no-cache
	$(COMPILER) build tests/tcp_test.ab -o $(BUILD_DIR)/tcp-test --fast --no-cache
	$(COMPILER) build tests/epos_simulator_test.ab -o $(BUILD_DIR)/epos-simulator-test --fast --no-cache
	$(COMPILER) build examples/receipt.ab -o $(BUILD_DIR)/receipt --fast --no-cache
	$(COMPILER) build examples/epos.ab -o $(BUILD_DIR)/epos --fast --no-cache
test: test-in-shell
test-in-shell: check
	$(BUILD_DIR)/encoder-test
	$(BUILD_DIR)/device-result-test
	$(BUILD_DIR)/tcp-test
	$(BUILD_DIR)/epos-simulator-test
	$(BUILD_DIR)/receipt > $(BUILD_DIR)/receipt.bin
	$(BUILD_DIR)/epos > $(BUILD_DIR)/receipt.xml
clean:
	rm -rf -- $(BUILD_DIR)

.PHONY: test-native
test-native:
	mkdir -p $(BUILD_DIR)
	$(COMPILER) build tests/native_test.ab -o $(BUILD_DIR)/native-test --fast --no-cache
	$(COMPILER) build tests/native_pty_test.ab -o $(BUILD_DIR)/native-pty-test --fast --no-cache
	$(BUILD_DIR)/native-test
	$(BUILD_DIR)/native-pty-test
