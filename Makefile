LUA_CPATH = ./wrappers/?.so;$(shell lua -e 'print(package.cpath)')
export LUA_CPATH
test:
	@busted --lua=luajit -o spec/utfTerminal.lua
