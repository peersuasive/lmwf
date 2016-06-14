LUA_CPATH = ./wrappers/?.so;$(shell lua -e 'print(package.cpath)')
export LUA_CPATH

all: lmwf/libhttpd.so
	
lmwf/libhttpd.so: 3rd/lua-httpd/libhttpd.so
	@cd lmwf && ln -sf ../3rd/lua-httpd/libhttpd.so .
	@echo OK

3rd/lua-httpd/libhttpd.so: 3rd/lua-httpd/libhttpd.c
	@echo Compiling libhttpd...
	@git submodule update --remote
	@cd 3rd/lua-httpd && make
	@echo ...done

test:
	@busted --lua=luajit -o spec/utfTerminal.lua

clean:
	@rm -f lmwf/libhttpd.so

