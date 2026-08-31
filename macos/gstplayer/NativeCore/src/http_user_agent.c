#include <glib.h>

#include "http_source.h"

#include <stdio.h>
#include <string.h>

#if defined(__linux__) && !defined(__ANDROID__)
#include <sys/utsname.h>
#elif defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <urlmon.h>
#include <windows.h>
#elif defined(__APPLE__)
#include <TargetConditionals.h>
#include <sys/sysctl.h>
#endif

#define GSTP_UA_MAX 1024

static char g_custom_ua[GSTP_UA_MAX];
static char g_platform_ua[GSTP_UA_MAX];
static gboolean g_platform_ua_ready = (gboolean)0;
static GMutex g_ua_lock;
static GOnce g_ua_once = G_ONCE_INIT;

#if defined(__linux__) && !defined(__ANDROID__)

static gboolean gstp_linux_run_command(const char *cmd, char *out, size_t out_len) {
  FILE *fp = popen(cmd, "r");
  if (!fp) {
    return (gboolean)0;
  }
  if (!fgets(out, (int)out_len, fp)) {
    pclose(fp);
    return (gboolean)0;
  }
  pclose(fp);
  g_strchomp(out);
  return out[0] != '\0';
}

static gboolean gstp_linux_extract_version(const char *line, char *version,
                                           size_t version_len) {
  const char *p = line;
  while (*p && !g_ascii_isdigit(*p)) {
    p++;
  }
  if (!*p) {
    return (gboolean)0;
  }
  return sscanf(p, "%63s", version) == 1;
}

static gboolean gstp_linux_build_chrome_ua(const char *version, char *ua,
                                           size_t ua_len) {
  struct utsname u;
  char arch[64] = "x86_64";
  if (uname(&u) == 0 && u.machine[0]) {
    g_strlcpy(arch, u.machine, sizeof(arch));
  }
  return g_snprintf(ua, ua_len,
                    "Mozilla/5.0 (X11; Linux %s) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/%s Safari/537.36",
                    arch, version) > 0;
}

static gboolean gstp_linux_build_firefox_ua(const char *version, char *ua,
                                            size_t ua_len) {
  struct utsname u;
  char arch[64] = "x86_64";
  if (uname(&u) == 0 && u.machine[0]) {
    g_strlcpy(arch, u.machine, sizeof(arch));
  }
  return g_snprintf(ua, ua_len,
                    "Mozilla/5.0 (X11; Linux %s; rv:%s) Gecko/20100101 "
                    "Firefox/%s",
                    arch, version, version) > 0;
}

static gboolean gstp_linux_probe_browser_ua(char *ua, size_t ua_len) {
  static const char *chrome_cmds[] = {
      "google-chrome-stable --version 2>/dev/null",
      "google-chrome --version 2>/dev/null",
      "chromium-browser --version 2>/dev/null",
      "chromium --version 2>/dev/null",
      "microsoft-edge-stable --version 2>/dev/null",
      "microsoft-edge --version 2>/dev/null",
      NULL,
  };
  char line[256];
  char version[64];

  for (int i = 0; chrome_cmds[i]; i++) {
    if (!gstp_linux_run_command(chrome_cmds[i], line, sizeof(line))) {
      continue;
    }
    if (gstp_linux_extract_version(line, version, sizeof(version)) &&
        gstp_linux_build_chrome_ua(version, ua, ua_len)) {
      return (gboolean)1;
    }
  }

  if (gstp_linux_run_command("firefox --version 2>/dev/null", line,
                             sizeof(line)) &&
      gstp_linux_extract_version(line, version, sizeof(version)) &&
      gstp_linux_build_firefox_ua(version, ua, ua_len)) {
    return (gboolean)1;
  }

  return (gboolean)0;
}

#elif defined(_WIN32)

static gboolean gstp_windows_probe_browser_ua(char *ua, size_t ua_len) {
  WCHAR wua[GSTP_UA_MAX];
  DWORD wlen = (DWORD)(sizeof(wua) / sizeof(wua[0]));
  if (FAILED(ObtainUserAgentString(URLMON_OPTION_USER_AGENT, wua, &wlen)) ||
      wlen == 0) {
    return (gboolean)0;
  }
  int needed =
      WideCharToMultiByte(CP_UTF8, 0, wua, -1, NULL, 0, NULL, NULL);
  if (needed <= 0 || (size_t)needed > ua_len) {
    return (gboolean)0;
  }
  if (WideCharToMultiByte(CP_UTF8, 0, wua, -1, ua, ua_len, NULL, NULL) <= 0) {
    return (gboolean)0;
  }
  return ua[0] != '\0';
}

#endif

static void gstp_http_user_agent_init_platform_once(void) {
  g_mutex_lock(&g_ua_lock);
  if (g_platform_ua_ready) {
    g_mutex_unlock(&g_ua_lock);
    return;
  }

#if defined(__linux__) && !defined(__ANDROID__)
  if (!gstp_linux_probe_browser_ua(g_platform_ua, sizeof(g_platform_ua))) {
    struct utsname u;
    char os_id[64] = "Linux";
    FILE *os_release = fopen("/etc/os-release", "r");
    if (os_release) {
      char line[256];
      while (fgets(line, sizeof(line), os_release)) {
        if (g_str_has_prefix(line, "ID=")) {
          g_strlcpy(os_id, line + 3, sizeof(os_id));
          g_strchomp(os_id);
          if (os_id[0] == '"') {
            memmove(os_id, os_id + 1, strlen(os_id));
            char *q = strchr(os_id, '"');
            if (q) {
              *q = '\0';
            }
          }
          break;
        }
      }
      fclose(os_release);
    }
    if (uname(&u) == 0) {
      g_snprintf(g_platform_ua, sizeof(g_platform_ua),
                 "Mozilla/5.0 (X11; %s %s) AppleWebKit/537.36 (KHTML, like "
                 "Gecko) Chrome/120.0.0.0 Safari/537.36",
                 os_id, u.machine);
    }
  }
#elif defined(_WIN32)
  if (!gstp_windows_probe_browser_ua(g_platform_ua, sizeof(g_platform_ua))) {
    OSVERSIONINFOEXW ver;
    memset(&ver, 0, sizeof(ver));
    ver.dwOSVersionInfoSize = sizeof(ver);
    if (GetVersionExW((OSVERSIONINFOW *)&ver)) {
      g_snprintf(g_platform_ua, sizeof(g_platform_ua),
                 "Mozilla/5.0 (Windows NT %lu.%lu; Win64; x64) "
                 "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 "
                 "Safari/537.36",
                 (unsigned long)ver.dwMajorVersion,
                 (unsigned long)ver.dwMinorVersion);
    }
  }
#elif defined(__ANDROID__)
  g_snprintf(g_platform_ua, sizeof(g_platform_ua),
             "Mozilla/5.0 (Linux; Android %d) AppleWebKit/537.36 (KHTML, like "
             "Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
             __ANDROID_API__);
#elif defined(__APPLE__)
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
  char model[64];
  size_t model_len = sizeof(model);
  if (sysctlbyname("hw.machine", model, &model_len, NULL, 0) != 0) {
    g_strlcpy(model, "iPhone", sizeof(model));
  }
  g_snprintf(g_platform_ua, sizeof(g_platform_ua),
             "Mozilla/5.0 (%s; CPU iPhone OS like Mac OS X) AppleWebKit/605.1.15 "
             "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
             model);
#else
  char model[64];
  size_t model_len = sizeof(model);
  if (sysctlbyname("hw.model", model, &model_len, NULL, 0) != 0) {
    g_strlcpy(model, "Macintosh", sizeof(model));
  }
  g_snprintf(g_platform_ua, sizeof(g_platform_ua),
             "Mozilla/5.0 (%s; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
             "(KHTML, like Gecko) Version/17.0 Safari/605.1.15",
             model);
#endif
#endif

  if (!g_platform_ua[0]) {
    g_strlcpy(g_platform_ua,
              "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko) "
              "Chrome/120.0.0.0 Safari/537.36",
              sizeof(g_platform_ua));
  }
  g_platform_ua_ready = (gboolean)1;
  g_mutex_unlock(&g_ua_lock);
}

static gpointer gstp_http_user_agent_init_trampoline(gpointer data) {
  (void)data;
  gstp_http_user_agent_init_platform_once();
  return NULL;
}

void gstp_http_user_agent_init_platform(void) {
  g_once(&g_ua_once, gstp_http_user_agent_init_trampoline, NULL);
}

void gstp_set_default_user_agent(const char *ua) {
  g_mutex_lock(&g_ua_lock);
  if (ua && *ua) {
    g_strlcpy(g_custom_ua, ua, sizeof(g_custom_ua));
  } else {
    g_custom_ua[0] = '\0';
  }
  g_mutex_unlock(&g_ua_lock);
}

const char *gstp_get_default_user_agent(void) {
  gstp_http_user_agent_init_platform();
  g_mutex_lock(&g_ua_lock);
  const char *ua = g_custom_ua[0] ? g_custom_ua : g_platform_ua;
  g_mutex_unlock(&g_ua_lock);
  return ua;
}
