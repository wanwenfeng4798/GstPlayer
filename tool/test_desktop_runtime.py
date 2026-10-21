#!/usr/bin/env python3
"""Exercise desktop discovery and URLMON contracts against a real host GLib.

Set GSTP_TEST_GLIB_LIBRARY to a GLib .so/.dylib. Minimal ABI declarations allow
running without development headers. Only Win32 executable-path/URLMON calls
are replaced; environment, Unicode conversion and filesystem calls use GLib.
This POSIX-host contract check does not replace Windows SDK/MSVC integration.
"""
from pathlib import Path
import os
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parent.parent
    library = os.environ.get('GSTP_TEST_GLIB_LIBRARY')
    if not library or not Path(library).is_file():
        raise SystemExit('Set GSTP_TEST_GLIB_LIBRARY to an absolute GLib shared library path. '
                         'This contract test requires a POSIX host and clang (or CC).')
    glib = Path(library).resolve()
    compiler = os.environ.get('CC', 'clang')
    workspace = tempfile.TemporaryDirectory(prefix='gstplayer-runtime-')
    tmp = Path(workspace.name)
    # Minimal declarations for the real host GLib binary; no GLib behavior is mocked.
    (tmp/'glib').mkdir()
    (tmp/'glib/gstdio.h').write_text('#include <glib.h>\n')
    (tmp/'glib.h').write_text('''#pragma once
    #include <stddef.h>
    #include <stdint.h>
    typedef char gchar;
    typedef int gboolean;
    typedef long glong;
    typedef uint16_t gunichar2;
    typedef struct _GError GError;
    #define TRUE 1
    #define FALSE 0
    #define G_FILE_TEST_IS_DIR (1 << 2)
    #define g_new(type,n) ((type*)g_malloc_n((n),sizeof(type)))
    void *g_malloc_n(size_t,size_t);
    void g_free(void*);
    const gchar *g_getenv(const gchar*);
    gboolean g_setenv(const gchar*,const gchar*,gboolean);
    const gchar *g_get_user_cache_dir(void);
    gchar *g_build_filename(const gchar*,...);
    int g_mkdir_with_parents(const gchar*,int);
    gchar *g_path_get_dirname(const gchar*);
    gchar *g_utf16_to_utf8(const gunichar2*,glong,glong*,glong*,GError**);
    gunichar2 *g_utf8_to_utf16(const gchar*,glong,glong*,glong*,GError**);
    gboolean g_file_test(const gchar*,int);
    size_t g_strlcpy(gchar*,const gchar*,size_t);
    ''')
    (tmp/'windows.h').write_text('''#pragma once
    #include <stdint.h>
    typedef uint16_t WCHAR;
    typedef uint32_t DWORD;
    DWORD GetModuleFileNameW(void*,WCHAR*,DWORD);
    ''')
    main='''#include <glib.h>
    #include <stdio.h>
    #ifdef _WIN32
    #include <windows.h>
    #include <string.h>
    DWORD GetModuleFileNameW(void *unused,WCHAR *out,DWORD capacity) {
     (void)unused;
     glong length=0;
     gunichar2 *value=g_utf8_to_utf16(g_getenv("GSTP_TEST_EXE"),-1,NULL,&length,NULL);
     if(!value) return 0;
     DWORD copied=(DWORD)length;
     if(copied>=capacity) copied=capacity;
     memcpy(out,value,(size_t)copied*sizeof(WCHAR));
     if(copied<capacity) out[copied]=0;
     g_free(value); return copied;
    }
    void gstp_setup_windows_env(void);
    #else
    void gstp_setup_linux_env(void);
    #endif
    int main(void) {
    #ifdef _WIN32
     gstp_setup_windows_env();
    #else
     gstp_setup_linux_env();
    #endif
     const char *keys[]={"GST_PLUGIN_SYSTEM_PATH","GST_PLUGIN_SYSTEM_PATH_1_0","GIO_MODULE_DIR","GST_REGISTRY","GST_REGISTRY_1_0","GST_REGISTRY_FORK"};
     for(size_t i=0;i<sizeof(keys)/sizeof(keys[0]);i++) {
      const char *v=g_getenv(keys[i]); printf("%s=%s\\n",keys[i],v?v:"<unset>");
     }
    }
    '''
    (tmp/'main.c').write_text(main)
    keys=['GST_PLUGIN_SYSTEM_PATH','GST_PLUGIN_SYSTEM_PATH_1_0','GIO_MODULE_DIR','GST_REGISTRY','GST_REGISTRY_1_0','GST_REGISTRY_FORK']
    base=os.environ.copy()
    for key in keys: base.pop(key,None)
    base['XDG_CACHE_HOME']=str(tmp/'cache')
    sdk=tmp/'SDK'; app=tmp/'应用 with spaces'
    for parent in (sdk,app/'gstplayer'):
     (parent/'lib/gstreamer-1.0').mkdir(parents=True)
     (parent/'lib/gio/modules').mkdir(parents=True)
    base['GSTP_TEST_EXE']=str(app/'player.exe')
    base['GSTREAMER_1_0_ROOT_MSVC_X86_64']=str(sdk)
    for platform in ('linux','windows'):
     binary=tmp/platform
     subprocess.run([compiler,'-std=c11','-Wall','-Wextra','-Werror','-D'+('__linux__' if platform=='linux' else '_WIN32'),'-I'+str(tmp),str(root/'native/src'/f'{platform}_env.c'),str(tmp/'main.c'),str(glib),'-Wl,-rpath,'+str(glib.parent),'-o',str(binary)],check=True)
     def invoke(extra):
      env=dict(base,**extra)
      output=subprocess.check_output([str(binary)],env=env,text=True)
      return dict(line.split('=',1) for line in output.splitlines())
     preserved={key:'custom-'+key for key in keys}
     assert invoke(preserved)==preserved
     print('PASS',platform,'preserves every explicit override')
     result=invoke({'GST_REGISTRY_1_0':'registry-versioned','GST_PLUGIN_SYSTEM_PATH_1_0':'plugins-versioned'})
     assert result['GST_REGISTRY']=='<unset>' and result['GST_PLUGIN_SYSTEM_PATH']=='<unset>'
     print('PASS',platform,'respects versioned overrides')
     result=invoke({})
     assert result['GST_REGISTRY']==str(tmp/'cache/gstplayer/gstreamer-registry.bin')
     assert result['GST_REGISTRY_FORK']=='no'
     if platform=='linux':
      assert result['GST_PLUGIN_SYSTEM_PATH']=='<unset>' and result['GIO_MODULE_DIR']=='<unset>'
     else:
      assert result['GST_PLUGIN_SYSTEM_PATH']==str(app/'gstplayer/lib/gstreamer-1.0')
      assert result['GIO_MODULE_DIR']==str(app/'gstplayer/lib/gio/modules')
      fallback=invoke({'GSTP_TEST_EXE':str(tmp/'no-bundle/player.exe')})
      assert fallback['GST_PLUGIN_SYSTEM_PATH']==str(sdk/'lib/gstreamer-1.0')
      assert fallback['GIO_MODULE_DIR']==str(sdk/'lib/gio/modules')
      print('PASS Windows SDK fallback and Unicode bundled paths')
     print('PASS',platform,'default registry and discovery')
    ua=(root/'native/src/http_user_agent.c').read_text()
    start=ua.index('static gboolean gstp_windows_probe_browser_ua(')
    end=ua.index('\n#endif',start)
    (tmp/'ua.c').write_text('''#include <glib.h>
    #include <windows.h>
    #include <assert.h>
    #include <string.h>
    #define GSTP_UA_MAX 1024
    #define FAILED(x) ((x)<0)
    static int mode=0;
    static int ObtainUserAgentString(DWORD option,char *out,DWORD *bytes) {
     assert(option==0); assert(*bytes==1024);
     if(mode==1) return -1;
     if(mode==2) {out[0]=0;*bytes=0;return 0;}
     strcpy(out,"Mozilla/5.0 test"); *bytes=17;return 0;
    }
    '''+ua[start:end]+'''
    int main(void) {
     char buffer[1024];
     assert(gstp_windows_probe_browser_ua(buffer,sizeof(buffer)));
     assert(strcmp(buffer,"Mozilla/5.0 test")==0);
     assert(!gstp_windows_probe_browser_ua(buffer,4));
     assert(!gstp_windows_probe_browser_ua(NULL,0));
     mode=1;assert(!gstp_windows_probe_browser_ua(buffer,sizeof(buffer)));
     mode=2;assert(!gstp_windows_probe_browser_ua(buffer,sizeof(buffer)));
    }
    ''')
    subprocess.run([compiler,'-std=c11','-Wall','-Wextra','-Werror','-I'+str(tmp),str(tmp/'ua.c'),str(glib),'-Wl,-rpath,'+str(glib.parent),'-o',str(tmp/'ua')],check=True)
    subprocess.run([str(tmp/'ua')],check=True)
    print('PASS Windows URLMON contract, success, failure, empty and short buffers')
    print('Checked against real GLib; Win32 executable-path and URLMON calls use contract stubs.')
    workspace.cleanup()


if __name__ == "__main__":
    main()
