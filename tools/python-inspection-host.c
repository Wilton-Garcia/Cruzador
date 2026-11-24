/* Runs our inspection script using a matching, caller-selected CPython library.
 * Business modules are decoded as data by that script, never imported/executed.
 */
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>

static void *required(void *library, const char *name) {
    void *value = dlsym(library, name);
    if (!value) { fprintf(stderr, "Missing Python API: %s\n", name); exit(2); }
    return value;
}
int main(int argc, char **argv) {
    if (argc < 4) {
        fprintf(stderr, "usage: python-inspection-host LIBRARY PYTHON_HOME SCRIPT [SCRIPT_ARGS...]\n");
        return 2;
    }
    void *library = dlopen(argv[1], RTLD_NOW | RTLD_GLOBAL);
    if (!library) { fprintf(stderr, "%s\n", dlerror()); return 2; }
    wchar_t *(*decode)(const char *, size_t *) = required(library, "Py_DecodeLocale");
    void (*set_home)(const wchar_t *) = required(library, "Py_SetPythonHome");
    void (*initialize)(int) = required(library, "Py_InitializeEx");
    void (*set_argv)(int, wchar_t **, int) = required(library, "PySys_SetArgvEx");
    int (*run_file)(FILE *, const char *, int, void *) = required(library, "PyRun_SimpleFileExFlags");
    int (*finalize)(void) = required(library, "Py_FinalizeEx");
    void (*raw_free)(void *) = required(library, "PyMem_RawFree");
    *(int *)required(library, "Py_IsolatedFlag") = 1;
    *(int *)required(library, "Py_NoSiteFlag") = 1;
    *(int *)required(library, "Py_DontWriteBytecodeFlag") = 1;
    *(int *)required(library, "Py_IgnoreEnvironmentFlag") = 1;
    wchar_t *home = decode(argv[2], NULL);
    if (!home) return 2;
    set_home(home);
    FILE *script = fopen(argv[3], "rb");
    if (!script) { perror("inspection script"); return 2; }
    initialize(0);
    int script_argc = argc - 3;
    wchar_t **wide = calloc((size_t)script_argc, sizeof(*wide));
    if (!wide) return 2;
    for (int i=0; i<script_argc; ++i) {
        wide[i] = decode(argv[i+3], NULL);
        if (!wide[i]) return 2;
    }
    set_argv(script_argc, wide, 0);
    int status = run_file(script, argv[3], 1, NULL);
    int final_status = finalize();
    for (int i=0; i<script_argc; ++i) raw_free(wide[i]);
    free(wide); raw_free(home);
    return status == 0 && final_status == 0 ? 0 : 1;
}
