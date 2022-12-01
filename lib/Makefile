VTUNE_DIR := /opt/intel/oneapi/vtune/latest

itt.so: itt.c
	gcc -shared -fPIC $< -I$(VTUNE_DIR)/include -L$(VTUNE_DIR)/lib64 -l:libittnotify.a -o $@
