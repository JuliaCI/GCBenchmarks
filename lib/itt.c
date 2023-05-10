#include <ittnotify.h>

__itt_domain* gc_domain = 0;
__itt_string_handle* handle_main = 0;

void init() {
    gc_domain = __itt_domain_create("org.julialang.gc");
    handle_main = __itt_string_handle_create("collect");
}

void gc_begin() {
    __itt_task_begin(gc_domain, __itt_null, __itt_null, handle_main);
}

void gc_end() {
    __itt_task_end(gc_domain);
}
