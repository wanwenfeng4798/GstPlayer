#include "gstp_internal.h"

#if defined(__linux__) && !defined(__ANDROID__)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static void gstp_setenv_copy(const char *key, const char *value) {
  if (!key || !value) {
    return;
  }
  setenv(key, value, 1);
}

static int gstp_dir_exists(const char *path) {
  struct stat st;
  return path && stat(path, &st) == 0 && S_ISDIR(st.st_mode);
}

static void gstp_mkdir_p(const char *path) {
  if (!path || !*path) {
    return;
  }
  char buf[512];
  g_strlcpy(buf, path, sizeof(buf));
  for (char *p = buf + 1; *p; p++) {
    if (*p != '/') {
      continue;
    }
    *p = '\0';
    if (!gstp_dir_exists(buf)) {
      (void)mkdir(buf, 0755);
    }
    *p = '/';
  }
  if (!gstp_dir_exists(buf)) {
    (void)mkdir(buf, 0755);
  }
}

void gstp_setup_linux_env(void) {
  const char *home = getenv("HOME");
  if (!home || home[0] == '\0') {
    home = "/tmp";
  }

  char cache_dir[512];
  snprintf(cache_dir, sizeof(cache_dir), "%s/.cache/gstplayer", home);
  gstp_mkdir_p(cache_dir);

  char registry[512];
  snprintf(registry, sizeof(registry), "%s/gstreamer-registry.bin", cache_dir);
  gstp_setenv_copy("GST_REGISTRY_FORK", "no");
  gstp_setenv_copy("GST_REGISTRY", registry);

  static const char *plugin_paths[] = {
      "/usr/lib/x86_64-linux-gnu/gstreamer-1.0",
      "/usr/lib/aarch64-linux-gnu/gstreamer-1.0",
      "/usr/lib/gstreamer-1.0",
      "/usr/local/lib/gstreamer-1.0",
      NULL,
  };
  for (int i = 0; plugin_paths[i]; i++) {
    if (gstp_dir_exists(plugin_paths[i])) {
      gstp_setenv_copy("GST_PLUGIN_SYSTEM_PATH", plugin_paths[i]);
      break;
    }
  }

  static const char *gio_paths[] = {
      "/usr/lib/x86_64-linux-gnu/gio/modules",
      "/usr/lib/aarch64-linux-gnu/gio/modules",
      "/usr/lib/gio/modules",
      "/usr/local/lib/gio/modules",
      NULL,
  };
  for (int i = 0; gio_paths[i]; i++) {
    if (gstp_dir_exists(gio_paths[i])) {
      gstp_setenv_copy("GIO_MODULE_DIR", gio_paths[i]);
      break;
    }
  }
}

#endif /* __linux__ && !__ANDROID__ */
