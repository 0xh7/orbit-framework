LUA_VERSION ?= 5.4
LUA_DIR ?= $(shell if [ -d /opt/homebrew/opt/lua@5.4 ]; then printf /opt/homebrew/opt/lua@5.4; fi)
ROCKS_TREE ?= ./.luarocks
ROCKSPEC ?= orbit-framework-dev-1.rockspec
ROCKS_BIN := $(abspath $(ROCKS_TREE))/bin
LUAROCKS ?= luarocks
LUAROCKS_FLAGS := --lua-version=$(LUA_VERSION) --tree $(ROCKS_TREE)

ifneq ($(LUA_DIR),)
LUAROCKS_FLAGS += --lua-dir=$(LUA_DIR)
endif

.PHONY: test lint format format-check install-deps rock

install-deps:
	$(LUAROCKS) $(LUAROCKS_FLAGS) install luasocket
	$(LUAROCKS) $(LUAROCKS_FLAGS) install busted
	$(LUAROCKS) $(LUAROCKS_FLAGS) install luacheck

test:
	PATH="$(ROCKS_BIN):$$PATH" busted spec

lint:
	PATH="$(ROCKS_BIN):$$PATH" luacheck src spec examples bin/orbit

format:
	stylua src spec examples bin/orbit

format-check:
	stylua --check src spec examples bin/orbit

rock:
	$(LUAROCKS) $(LUAROCKS_FLAGS) make $(ROCKSPEC)
