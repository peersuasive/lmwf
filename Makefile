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

install:
	@echo Installing...
	@install -d /usr/local/share/lua/5.1/lmwf
	@install -d /usr/local/lib/lua/5.1/lmwf
	@cp -a lmwf/* /usr/local/share/lua/5.1/lmwf
	@install -m 755 bin/lemwaf /usr/local/bin
	@install -m 755 bin/server_ctl.lua /usr/local/bin/lemwaf_ctl
	@install -m 755 3rd/lua-httpd/libhttpd.so /usr/local/lib/lua/5.1/lmwf
	@echo done.

uninstall:
	@echo Uninstalling...
	@rm -f /usr/local/bin/lemwaf
	@rm -f /usr/local/bin/lemwaf_ctl
	@rm -rf /usr/local/share/lua/5.1/lmwf
	@rm -rf /usr/local/lib/lua/5.1/lmwf
	@echo done.
clean:
	@rm -f lmwf/libhttpd.so

