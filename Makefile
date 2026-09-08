CC ?= cc
CXX ?= c++
OBJC ?= cc
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
M_SRC := $(wildcard src/*.m)
C_OBJ := $(patsubst src/%.c,$(BUILD)/%.o,$(C_SRC))
M_OBJ := $(patsubst src/%.m,$(BUILD)/%.o,$(M_SRC))
OBJ := $(C_OBJ) $(M_OBJ)
PKGCONFIG := $(BUILD)/lwmgl-$(VERSION).pc
TEST_DIR := $(BUILD)/tests
EXAMPLE_DIR := $(BUILD)/examples
STAGE_PREFIX := $(abspath $(BUILD)/stage-prefix)
PACKAGE_PREFIX := $(abspath $(BUILD)/install-test)
CONTRACT_C_SRC := $(filter-out tests/api_contract.c tests/header_contract.c,$(wildcard tests/*_contract.c))
CONTRACT_C_BINS := $(patsubst tests/%_contract.c,$(TEST_DIR)/%-contract,$(CONTRACT_C_SRC))
RUNTIME_BINS := $(TEST_DIR)/runtime-smoke-c $(TEST_DIR)/runtime-smoke-cpp
EXAMPLE_BINS := $(EXAMPLE_DIR)/clear-c $(EXAMPLE_DIR)/clear-cpp

CPPFLAGS += -Iinclude
CFLAGS ?= -O2
CFLAGS += -std=c11 -Wall -Wextra -Wpedantic -fPIC
CXXFLAGS ?= -O2
CXXFLAGS += -std=c++17 -Wall -Wextra -Wpedantic
OBJCFLAGS ?= -O2
OBJCFLAGS += -std=c11 -Wall -Wextra -Wpedantic -fPIC -fobjc-arc
LDFLAGS ?=

GLFW_CFLAGS := $(shell pkg-config --cflags glfw3 2>/dev/null)
GLFW_LIBS := $(shell pkg-config --libs glfw3 2>/dev/null)
CPPFLAGS += $(GLFW_CFLAGS)
PLATFORM_LIBS := -framework Metal -framework QuartzCore -framework AppKit -framework Foundation
PRIVATE_LIBS_PC := -framework Metal -framework QuartzCore -framework AppKit -framework Foundation $(GLFW_LIBS)
LIBS := $(GLFW_LIBS) $(PLATFORM_LIBS)

SANITIZER_FLAGS := -fsanitize=address,undefined -fno-omit-frame-pointer
SAN_CFLAGS := -O1 -g -std=c11 -Wall -Wextra -Wpedantic -fPIC $(SANITIZER_FLAGS)
SAN_CXXFLAGS := -O1 -g -std=c++17 -Wall -Wextra -Wpedantic $(SANITIZER_FLAGS)
SAN_OBJCFLAGS := -O1 -g -std=c11 -Wall -Wextra -Wpedantic -fPIC -fobjc-arc $(SANITIZER_FLAGS)

TEST_BINS := $(TEST_DIR)/api-contract-c $(TEST_DIR)/api-contract-cpp $(TEST_DIR)/header-contract-c $(TEST_DIR)/header-contract-cpp $(CONTRACT_C_BINS) $(RUNTIME_BINS)

.PHONY: all clean check test install uninstall stage-check check-deps example sanitize package-check
all: check-deps $(STATIC_LIB) $(SHARED_LIB)
test: check
example: $(EXAMPLE_BINS)

check-deps:
	@command -v pkg-config >/dev/null 2>&1 || { echo "error: pkg-config is required"; exit 1; }
	@command -v otool >/dev/null 2>&1 || { echo "error: otool is required"; exit 1; }
	@pkg-config --atleast-version=3.3 glfw3 || { echo "error: GLFW >= 3.3 development files are required"; exit 1; }

$(BUILD) $(TEST_DIR) $(EXAMPLE_DIR):
	mkdir -p $@

$(BUILD)/%.o: src/%.c $(PUBLIC_HEADERS) | $(BUILD)
	$(CC) $(CPPFLAGS) $(CFLAGS) -Werror -c $< -o $@

$(BUILD)/%.o: src/%.m $(PUBLIC_HEADERS) | $(BUILD)
	$(OBJC) $(CPPFLAGS) $(OBJCFLAGS) -Werror -c $< -o $@

$(STATIC_LIB): $(OBJ)
	rm -f $@
	$(AR) rcs $@ $^

$(SHARED_LIB): $(OBJ)
	rm -f $@
	$(CC) $(SHARED_LDFLAGS) -o $@ $^ $(LDFLAGS) $(LIBS)

$(PKGCONFIG): lwmgl-1.0.0.pc.in | $(BUILD)
	sed -e 's|@PREFIX@|$(PREFIX)|g' -e 's|@PRIVATE_LIBS@|$(PRIVATE_LIBS_PC)|g' $< > $@

$(TEST_DIR)/api-contract-c: tests/api_contract.c $(STATIC_LIB) | $(TEST_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -Werror $< $(STATIC_LIB) $(LDFLAGS) $(LIBS) -o $@

$(TEST_DIR)/api-contract-cpp: tests/api_contract.cpp $(STATIC_LIB) | $(TEST_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -Werror $< $(STATIC_LIB) $(LDFLAGS) $(LIBS) -o $@

$(TEST_DIR)/header-contract-c: tests/header_contract.c | $(TEST_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -Werror $< $(LDFLAGS) -o $@

$(TEST_DIR)/header-contract-cpp: tests/header_contract.cpp | $(TEST_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -Werror $< $(LDFLAGS) -o $@

$(TEST_DIR)/%-contract: tests/%_contract.c $(STATIC_LIB) | $(TEST_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -Werror $< $(STATIC_LIB) $(LDFLAGS) $(LIBS) -o $@

$(TEST_DIR)/runtime-smoke-c: tests/runtime_smoke.c $(STATIC_LIB) | $(TEST_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -Werror $< $(STATIC_LIB) $(LDFLAGS) $(LIBS) -o $@

$(TEST_DIR)/runtime-smoke-cpp: tests/runtime_smoke.cpp $(STATIC_LIB) | $(TEST_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -Werror $< $(STATIC_LIB) $(LDFLAGS) $(LIBS) -o $@

$(EXAMPLE_DIR)/clear-c: examples/clear.c $(STATIC_LIB) | $(EXAMPLE_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -Werror $< $(STATIC_LIB) $(LDFLAGS) $(LIBS) -o $@

$(EXAMPLE_DIR)/clear-cpp: examples/clear.cpp $(STATIC_LIB) | $(EXAMPLE_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -Werror $< $(STATIC_LIB) $(LDFLAGS) $(LIBS) -o $@

stage-check: check-deps $(STATIC_LIB) $(SHARED_LIB) $(PKGCONFIG)
	rm -rf $(STAGE_PREFIX)
	$(MAKE) install PREFIX=$(STAGE_PREFIX)
	PKG_CONFIG_PATH=$(STAGE_PREFIX)/lib/pkgconfig $(CC) $(CFLAGS) tests/stage_consumer.c $$(PKG_CONFIG_PATH=$(STAGE_PREFIX)/lib/pkgconfig pkg-config --cflags --libs lwmgl-$(VERSION)) -Wl,-rpath,$(STAGE_PREFIX)/lib -o $(TEST_DIR)/stage-consumer-c
	PKG_CONFIG_PATH=$(STAGE_PREFIX)/lib/pkgconfig $(CXX) $(CXXFLAGS) tests/stage_consumer.cpp $$(PKG_CONFIG_PATH=$(STAGE_PREFIX)/lib/pkgconfig pkg-config --cflags --libs lwmgl-$(VERSION)) -Wl,-rpath,$(STAGE_PREFIX)/lib -o $(TEST_DIR)/stage-consumer-cpp
	PKG_CONFIG_PATH=$(STAGE_PREFIX)/lib/pkgconfig $(CC) $(CFLAGS) tests/stage_consumer.c $$(PKG_CONFIG_PATH=$(STAGE_PREFIX)/lib/pkgconfig pkg-config --cflags lwmgl-$(VERSION)) $(STAGE_PREFIX)/lib/$(STATIC_LIBNAME) $$(PKG_CONFIG_PATH=$(STAGE_PREFIX)/lib/pkgconfig pkg-config --libs --static lwmgl-$(VERSION) | sed -e 's|-L$(STAGE_PREFIX)/lib ||g' -e 's|-llwmgl ||g') -o $(TEST_DIR)/stage-consumer-c-static
	PKG_CONFIG_PATH=$(STAGE_PREFIX)/lib/pkgconfig $(CXX) $(CXXFLAGS) tests/stage_consumer.cpp $$(PKG_CONFIG_PATH=$(STAGE_PREFIX)/lib/pkgconfig pkg-config --cflags lwmgl-$(VERSION)) $(STAGE_PREFIX)/lib/$(STATIC_LIBNAME) $$(PKG_CONFIG_PATH=$(STAGE_PREFIX)/lib/pkgconfig pkg-config --libs --static lwmgl-$(VERSION) | sed -e 's|-L$(STAGE_PREFIX)/lib ||g' -e 's|-llwmgl ||g') -o $(TEST_DIR)/stage-consumer-cpp-static
	$(TEST_DIR)/stage-consumer-c
	$(TEST_DIR)/stage-consumer-cpp
	$(TEST_DIR)/stage-consumer-c-static
	$(TEST_DIR)/stage-consumer-cpp-static

check: check-deps $(TEST_BINS) stage-check example
	$(TEST_DIR)/api-contract-c
	$(TEST_DIR)/api-contract-cpp
	$(TEST_DIR)/header-contract-c
	$(TEST_DIR)/header-contract-cpp
	@set -e; for t in $(CONTRACT_C_BINS); do $$t; done
	$(TEST_DIR)/runtime-smoke-c
	$(TEST_DIR)/runtime-smoke-cpp

sanitize:
	$(MAKE) clean
	$(MAKE) $(TEST_BINS) example CFLAGS="$(SAN_CFLAGS)" CXXFLAGS="$(SAN_CXXFLAGS)" OBJCFLAGS="$(SAN_OBJCFLAGS)" LDFLAGS="$(SANITIZER_FLAGS)"
	$(TEST_DIR)/api-contract-c
	$(TEST_DIR)/api-contract-cpp
	$(TEST_DIR)/header-contract-c
	$(TEST_DIR)/header-contract-cpp
	@set -e; for t in $(CONTRACT_C_BINS); do $$t; done
	$(TEST_DIR)/runtime-smoke-c
	$(TEST_DIR)/runtime-smoke-cpp

package-check: check-deps
	$(MAKE) clean
	$(MAKE) all
	$(MAKE) check
	rm -rf $(PACKAGE_PREFIX)
	$(MAKE) install PREFIX=$(PACKAGE_PREFIX)
	@test "$$(PKG_CONFIG_PATH=$(PACKAGE_PREFIX)/lib/pkgconfig pkg-config --modversion lwmgl-$(VERSION))" = "$(VERSION)"
	@test "$$(otool -D $(SHARED_LIB) | sed -n '2p')" = "@rpath/$(SHARED_LIBNAME)"
	$(MAKE) uninstall PREFIX=$(PACKAGE_PREFIX)
	@test ! -e $(PACKAGE_PREFIX)/include/lwmgl-$(VERSION)
	@test ! -e $(PACKAGE_PREFIX)/lib/$(STATIC_LIBNAME)
	@test ! -e $(PACKAGE_PREFIX)/lib/$(SHARED_LIBNAME)
	@test ! -e $(PACKAGE_PREFIX)/lib/$(STATIC_ALIAS)
	@test ! -e $(PACKAGE_PREFIX)/lib/$(SHARED_ALIAS)
	@test ! -e $(PACKAGE_PREFIX)/lib/pkgconfig/lwmgl-$(VERSION).pc
	@test -d $(PACKAGE_PREFIX)/include
	@test -d $(PACKAGE_PREFIX)/lib
	@test -d $(PACKAGE_PREFIX)/lib/pkgconfig
	@bad="$$(find . -maxdepth 2 \( -name 'CMakeLists.txt' -o -name 'build.c' -o -name 'README.md' \) -print)"; \
		test -z "$$bad" || { printf '%s\n' "$$bad"; exit 1; }

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
