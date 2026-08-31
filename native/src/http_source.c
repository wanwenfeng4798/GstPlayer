#include "http_source.h"

#include <ctype.h>
#include <string.h>

static void gstp_http_headers_destroy_value(gpointer data) { g_free(data); }

void gstp_http_headers_clear(GHashTable *headers) {
  if (headers) {
    g_hash_table_remove_all(headers);
  }
}

void gstp_http_headers_free(GHashTable *headers) {
  if (headers) {
    g_hash_table_destroy(headers);
  }
}

static const char *gstp_json_skip_ws(const char *p) {
  while (*p && isspace((unsigned char)*p)) {
    p++;
  }
  return p;
}

static const char *gstp_json_parse_string(const char *p, char **out) {
  p = gstp_json_skip_ws(p);
  if (*p != '"') {
    return NULL;
  }
  p++;
  GString *buf = g_string_new(NULL);
  while (*p && *p != '"') {
    if (*p == '\\') {
      p++;
      if (*p == '\0') {
        g_string_free(buf, TRUE);
        return NULL;
      }
      switch (*p) {
      case '"':
      case '\\':
      case '/':
        g_string_append_c(buf, *p);
        break;
      case 'b':
        g_string_append_c(buf, '\b');
        break;
      case 'f':
        g_string_append_c(buf, '\f');
        break;
      case 'n':
        g_string_append_c(buf, '\n');
        break;
      case 'r':
        g_string_append_c(buf, '\r');
        break;
      case 't':
        g_string_append_c(buf, '\t');
        break;
      default:
        g_string_append_c(buf, *p);
        break;
      }
      p++;
      continue;
    }
    g_string_append_c(buf, *p++);
  }
  if (*p != '"') {
    g_string_free(buf, TRUE);
    return NULL;
  }
  *out = g_string_free(buf, FALSE);
  return p + 1;
}

GHashTable *gstp_http_headers_from_json(const char *json) {
  if (!json || !*json) {
    return NULL;
  }
  const char *p = gstp_json_skip_ws(json);
  if (*p != '{') {
    return NULL;
  }
  p++;
  GHashTable *headers = g_hash_table_new_full(g_str_hash, g_str_equal, g_free,
                                                gstp_http_headers_destroy_value);
  int count = 0;
  p = gstp_json_skip_ws(p);
  if (*p == '}') {
    return headers;
  }
  while (*p && count < GSTP_HTTP_HEADERS_MAX) {
    char *key = NULL;
    char *value = NULL;
    p = gstp_json_parse_string(p, &key);
    if (!p || !key) {
      gstp_http_headers_free(headers);
      g_free(key);
      return NULL;
    }
    p = gstp_json_skip_ws(p);
    if (*p != ':') {
      g_free(key);
      gstp_http_headers_free(headers);
      return NULL;
    }
    p++;
    p = gstp_json_parse_string(p, &value);
    if (!p || !value) {
      g_free(key);
      g_free(value);
      gstp_http_headers_free(headers);
      return NULL;
    }
    g_hash_table_insert(headers, key, value);
    count++;
    p = gstp_json_skip_ws(p);
    if (*p == '}') {
      return headers;
    }
    if (*p != ',') {
      gstp_http_headers_free(headers);
      return NULL;
    }
    p++;
    p = gstp_json_skip_ws(p);
  }
  gstp_http_headers_free(headers);
  return NULL;
}

static const char *gstp_http_header_lookup(GHashTable *headers,
                                           const char *name) {
  if (!headers || !name) {
    return NULL;
  }
  const char *value = g_hash_table_lookup(headers, name);
  if (value) {
    return value;
  }
  GHashTableIter iter;
  gpointer key;
  gpointer val;
  g_hash_table_iter_init(&iter, headers);
  while (g_hash_table_iter_next(&iter, &key, &val)) {
    if (g_ascii_strcasecmp((const char *)key, name) == 0) {
      return (const char *)val;
    }
  }
  return NULL;
}

static gboolean gstp_is_user_agent_header(const char *name) {
  return name && g_ascii_strcasecmp(name, "User-Agent") == 0;
}

void gstp_configure_http_source(GstElement *element, GHashTable *headers) {
  if (!element) {
    return;
  }
  GObjectClass *klass = G_OBJECT_GET_CLASS(element);
  if (g_object_class_find_property(klass, "ssl-strict")) {
    g_object_set(element, "ssl-strict", FALSE, NULL);
  }
  if (g_object_class_find_property(klass, "tls-validation-flags")) {
    g_object_set(element, "tls-validation-flags", 0, NULL);
  }

  const char *user_agent = gstp_http_header_lookup(headers, "User-Agent");
  if (!user_agent) {
    user_agent = gstp_get_default_user_agent();
  }
  if (g_object_class_find_property(klass, "user-agent")) {
    g_object_set(element, "user-agent", user_agent, NULL);
  }

  if (!headers || !g_object_class_find_property(klass, "extra-headers")) {
    return;
  }

  GstStructure *extra = gst_structure_new_empty("extra-headers");
  GHashTableIter iter;
  gpointer key;
  gpointer value;
  g_hash_table_iter_init(&iter, headers);
  while (g_hash_table_iter_next(&iter, &key, &value)) {
    const char *header_name = (const char *)key;
    if (gstp_is_user_agent_header(header_name)) {
      continue;
    }
    gst_structure_set(extra, header_name, G_TYPE_STRING, (const char *)value,
                      NULL);
  }
  if (gst_structure_n_fields(extra) > 0) {
    g_object_set(element, "extra-headers", extra, NULL);
  }
  gst_structure_free(extra);
}
