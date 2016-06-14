LUA_CPATH = ./wrappers/?.so;$(shell lua -e 'print(package.cpath)')
export LUA_CPATH

all: wrappers/libhttpd.so
	
wrappers/libhttpd.so: httpd
	@cd wrappers/ && ln -sf ../3rd/lua-httpd/libhttpd.so .
	@echo OK

httpd: 3rd/lua-httpd/libhttpd.so
	@echo Compiling libhttpd...
	@git submodule update --remote
	@cd 3rd/lua-httpd && make
	@echo ...done

test:
	@busted --lua=luajit -o spec/utfTerminal.lua

clean:
	@rm -f wrappers/libhttpd.so

