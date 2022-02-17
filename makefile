fetch-dependencies:
	luarocks install telegram-bot-lua
	luarocks install lua-toml

run:
	./main.lua