CC ?= cc
CXX ?= c++
OBJCXX ?= c++
AR ?= ar
PREFIX ?= /usr/local
VERSION := 1.0.0
ABI := 1
BUILD := build
UNAME_S := $(shell uname -s)

ifneq ($(UNAME_S),Darwin)
$(error unsupported host OS: $(UNAME_S); lwmgl v$(VERSION) supports macOS only)
endif

STATIC_LIBNAME := liblwmgl-$(VERSION).a
SHARED_LIBNAME := liblwmgl-$(VERSION).dylib
STATIC_ALIAS := liblwmgl.a
SHARED_ALIAS := liblwmgl.dylib
STATIC_LIB := $(BUILD)/$(STATIC_LIBNAME)
SHARED_LIB := $(BUILD)/$(SHARED_LIBNAME)
SHARED_LDFLAGS := -dynamiclib -Wl,-install_name,@rpath/$(SHARED_LIBNAME)
PUBLIC_HEADERS := $(wildcard include/lwmgl/*.h)
C_SRC := $(wildcard src/*.c)
MM_SRC := $(wildcard src/*.mm)
C_OBJ := $(patsubst src/%.c,$(BUILD)/%.o,$(C_SRC))
MM_OBJ := $(patsubst src/%.mm,$(BUILD)/%.o,$(MM_SRC))
OBJ := $(C_OBJ) $(MM_OBJ)
PKGCONFIG := $(BUILD)/lwmgl-$(VERSION).pc
TEST_DIR := $(BUILD)/tests

CPPFLAGS += -Iinclude
CFLAGS ?= -O2
CFLAGS += -std=c11 -Wall -Wextra -Wpedantic -fPIC
CXXFLAGS ?= -O2
CXXFLAGS += -std=c++17 -Wall -Wextra -Wpedantic
OBJCXXFLAGS ?= -O2
OBJCXXFLAGS += -std=c++17 -Wall -Wextra -Wpedantic -fPIC -fobjc-arc
LDFLAGS ?=

GLFW_CFLAGS := $(shell pkg-config --cflags glfw3 2>/dev/null)
GLFW_LIBS := $(shell pkg-config --libs glfw3 2>/dev/null)
CPPFLAGS += $(GLFW_CFLAGS)
PLATFORM_LIBS := -framework Metal -framework QuartzCore -framework AppKit -framework Foundation
PRIVATE_LIBS_PC := -framework Metal -framework QuartzCore -framework AppKit -framework Foundation $(GLFW_LIBS)
LIBS := $(GLFW_LIBS) $(PLATFORM_LIBS)

TEST_BINS := $(TEST_DIR)/api-contract-c $(TEST_DIR)/api-contract-cpp $(TEST_DIR)/header-contract-c $(TEST_DIR)/header-contract-cpp

.PHONY: all clean check test install uninstall stage-check check-deps
all: check-deps $(STATIC_LIB) $(SHARED_LIB)
test: check

check-deps:
	@command -v pkg-config >/dev/null 2>&1 || { echo "error: pkg-config is required"; exit 1; }
	@pkg-config --atleast-version=3.3 glfw3 || { echo "error: GLFW >= 3.3 development files are required"; exit 1; }

$(BUILD) $(TEST_DIR):
	mkdir -p $@

$(BUILD)/%.o: src/%.c $(PUBLIC_HEADERS) | $(BUILD)
	$(CC) $(CPPFLAGS) $(CFLAGS) -Werror -c $< -o $@

$(BUILD)/%.o: src/%.mm $(PUBLIC_HEADERS) | $(BUILD)
	$(OBJCXX) $(CPPFLAGS) $(OBJCXXFLAGS) -Werror -c $< -o $@

$(STATIC_LIB): $(OBJ)
	rm -f $@
	$(AR) rcs $@ $^

$(SHARED_LIB): $(OBJ)
	rm -f $@
	$(OBJCXX) $(SHARED_LDFLAGS) -o $@ $^ $(LDFLAGS) $(LIBS)

$(PKGCONFIG): lwmgl-1.0.0.pc.in | $(BUILD)
	sed -e 's|@PREFIX@|$(PREFIX)|g' -e 's|@PRIVATE_LIBS@|$(PRIVATE_LIBS_PC)|g' $< > $@

$(TEST_DIR)/api-contract-c: tests/api_contract.c $(STATIC_LIB) | $(TEST_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -Werror $< $(STATIC_LIB) $(LDFLAGS) $(LIBS) -o $@

$(TEST_DIR)/api-contract-cpp: tests/api_contract.cpp $(STATIC_LIB) | $(TEST_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -Werror $< $(STATIC_LIB) $(LDFLAGS) $(LIBS) -o $@

$(TEST_DIR)/header-contract-c: tests/header_contract.c | $(TEST_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -Werror $< -o $@

$(TEST_DIR)/header-contract-cpp: tests/header_contract.cpp | $(TEST_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -Werror $< -o $@

stage-check: check-deps $(STATIC_LIB) $(SHARED_LIB) $(PKGCONFIG)
	rm -rf $(BUILD)/stage-prefix
	$(MAKE) install PREFIX=$(abspath $(BUILD)/stage-prefix)
	PKG_CONFIG_PATH=$(abspath $(BUILD)/stage-prefix)/lib/pkgconfig $(CC) $(CFLAGS) tests/stage_consumer.c $$(PKG_CONFIG_PATH=$(abspath $(BUILD)/stage-prefix)/lib/pkgconfig pkg-config --cflags --libs --static lwmgl-$(VERSION)) -o $(TEST_DIR)/stage-consumer-c
	PKG_CONFIG_PATH=$(abspath $(BUILD)/stage-prefix)/lib/pkgconfig $(CXX) $(CXXFLAGS) tests/stage_consumer.cpp $$(PKG_CONFIG_PATH=$(abspath $(BUILD)/stage-prefix)/lib/pkgconfig pkg-config --cflags --libs --static lwmgl-$(VERSION)) -o $(TEST_DIR)/stage-consumer-cpp
	$(TEST_DIR)/stage-consumer-c
	$(TEST_DIR)/stage-consumer-cpp

check: check-deps $(TEST_BINS) stage-check
	$(TEST_DIR)/api-contract-c
	$(TEST_DIR)/api-contract-cpp
	$(TEST_DIR)/header-contract-c
	$(TEST_DIR)/header-contract-cpp

install: check-deps $(STATIC_LIB) $(SHARED_LIB)
	install -d $(DESTDIR)$(PREFIX)/include/lwmgl-$(VERSION)/lwmgl
	install -m 0644 $(PUBLIC_HEADERS) $(DESTDIR)$(PREFIX)/include/lwmgl-$(VERSION)/lwmgl/
	install -d $(DESTDIR)$(PREFIX)/lib/pkgconfig
	install -m 0644 $(STATIC_LIB) $(DESTDIR)$(PREFIX)/lib/$(STATIC_LIBNAME)
	install -m 0755 $(SHARED_LIB) $(DESTDIR)$(PREFIX)/lib/$(SHARED_LIBNAME)
	cd $(DESTDIR)$(PREFIX)/lib && ln -sfn $(STATIC_LIBNAME) $(STATIC_ALIAS)
	cd $(DESTDIR)$(PREFIX)/lib && ln -sfn $(SHARED_LIBNAME) $(SHARED_ALIAS)
	@sed -e 's|@PREFIX@|$(PREFIX)|g' -e 's|@PRIVATE_LIBS@|$(PRIVATE_LIBS_PC)|g' lwmgl-1.0.0.pc.in > $(DESTDIR)$(PREFIX)/lib/pkgconfig/lwmgl-$(VERSION).pc

uninstall:
	rm -rf $(DESTDIR)$(PREFIX)/include/lwmgl-$(VERSION)
	rm -f $(DESTDIR)$(PREFIX)/lib/$(STATIC_LIBNAME) $(DESTDIR)$(PREFIX)/lib/$(SHARED_LIBNAME) $(DESTDIR)$(PREFIX)/lib/$(STATIC_ALIAS) $(DESTDIR)$(PREFIX)/lib/$(SHARED_ALIAS) $(DESTDIR)$(PREFIX)/lib/pkgconfig/lwmgl-$(VERSION).pc

clean:
	rm -rf $(BUILD)
