THIRD_PARTY_DIR = $(RIME_ROOT)/thirdparty
SRC_DIR = $(THIRD_PARTY_DIR)/src

BUILD_DIR ?= $(THIRD_PARTY_DIR)/build
INSTALL_DIR ?= $(THIRD_PARTY_DIR)/output

THIRD_PARTY_LIBS = capnproto glog gtest leveldb marisa opencc yaml-cpp

XC_FLAGS = CFLAGS="-fembed-bitcode" CXXFLAGS="-stdlib=libc++ -fembed-bitcode" LDFLAGS="-stdlib=libc++ -fembed-bitcode"

.PHONY: all clean $(THIRD_PARTY_LIBS)

all: $(THIRD_PARTY_LIBS)

# note: this won't clean output files under include/, lib/ and bin/.
clean:
	rm -r $(RIME_ROOT)/thirdparty/build || true
	rm -r $(RIME_ROOT)/thirdparty/output || true

capnproto:
	echo $(BUILD_DIR)
	cd $(SRC_DIR)/capnproto; \
	$(XC_FLAGS) cmake . -B$(BUILD_DIR)/capnproto \
	-DCMAKE_OSX_SYSROOT=$(SDKROOT) \
	-DBUILD_SHARED_LIBS:BOOL=OFF \
	-DBUILD_TESTING:BOOL=OFF \
	-DCMAKE_BUILD_TYPE:STRING="Release" \
	-DCMAKE_INSTALL_PREFIX:PATH="$(INSTALL_DIR)" \
	&& cmake --build $(BUILD_DIR)/capnproto --target install

glog:
	cd $(SRC_DIR)/glog; \
	$(XC_FLAGS) cmake . -B$(BUILD_DIR)/glog \
	-DCMAKE_OSX_SYSROOT=$(SDKROOT) \
	-DBUILD_TESTING:BOOL=OFF \
	-DWITH_GFLAGS:BOOL=OFF \
	-DCMAKE_BUILD_TYPE:STRING="Release" \
	-DCMAKE_INSTALL_PREFIX:PATH="$(INSTALL_DIR)" \
	&& cmake --build $(BUILD_DIR)/glog --target install

gtest:
	cd $(SRC_DIR)/googletest; \
	$(XC_FLAGS) cmake . -B$(BUILD_DIR)/googletest \
	-DCMAKE_OSX_SYSROOT=$(SDKROOT) \
	-DBUILD_GMOCK:BOOL=OFF \
	-DCMAKE_BUILD_TYPE:STRING="Release" \
	-DCMAKE_INSTALL_PREFIX:PATH="$(INSTALL_DIR)" \
	&& cmake --build $(BUILD_DIR)/googletest --target install

leveldb:
	cd $(SRC_DIR)/leveldb; \
	$(XC_FLAGS) cmake . -B$(BUILD_DIR)/leveldb \
	-DCMAKE_OSX_SYSROOT=$(SDKROOT) \
	-DLEVELDB_BUILD_BENCHMARKS:BOOL=OFF \
	-DLEVELDB_BUILD_TESTS:BOOL=OFF \
	-DCMAKE_BUILD_TYPE:STRING="Release" \
	-DCMAKE_INSTALL_PREFIX:PATH="$(INSTALL_DIR)" \
	&& cmake --build $(BUILD_DIR)/leveldb --target install

marisa:
	cd $(SRC_DIR)/marisa-trie; \
	$(XC_FLAGS) cmake $(SRC_DIR) -B$(BUILD_DIR)/marisa-trie \
	-DCMAKE_OSX_SYSROOT=$(SDKROOT) \
	-DCMAKE_BUILD_TYPE:STRING="Release" \
	-DCMAKE_INSTALL_PREFIX:PATH="$(INSTALL_DIR)" \
	&& cmake --build $(BUILD_DIR)/marisa-trie --target install

opencc:
	echo UFO $(OPENCC_DICT_BIN)
	cd $(SRC_DIR)/opencc; \
	$(XC_FLAGS) cmake . -B$(BUILD_DIR)/opencc \
	-DCMAKE_OSX_SYSROOT=$(SDKROOT) \
	-DBUILD_SHARED_LIBS:BOOL=OFF \
	-DCMAKE_BUILD_TYPE:STRING="Release" \
	-DCMAKE_INSTALL_PREFIX:PATH="$(INSTALL_DIR)" \
	&& cmake --build $(BUILD_DIR)/opencc --target install

yaml-cpp:
	cd $(SRC_DIR)/yaml-cpp; \
	$(XC_FLAGS) cmake . -B$(BUILD_DIR)/yaml-cpp \
	-DCMAKE_OSX_SYSROOT=$(SDKROOT) \
	-DYAML_CPP_BUILD_CONTRIB:BOOL=OFF \
	-DYAML_CPP_BUILD_TESTS:BOOL=OFF \
	-DYAML_CPP_BUILD_TOOLS:BOOL=OFF \
	-DCMAKE_BUILD_TYPE:STRING="Release" \
	-DCMAKE_INSTALL_PREFIX:PATH="$(INSTALL_DIR)" \
	&& cmake --build $(BUILD_DIR)/yaml-cpp --target install
