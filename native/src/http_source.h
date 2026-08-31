#pragma once

#include <glib.h>
#include <gst/gst.h>

#define GSTP_HTTP_HEADERS_MAX 32

void gstp_http_user_agent_init_platform(void);

void gstp_set_default_user_agent(const char *ua);

const char *gstp_get_default_user_agent(void);

void gstp_http_headers_clear(GHashTable *headers);

void gstp_http_headers_free(GHashTable *headers);

GHashTable *gstp_http_headers_from_json(const char *json);

void gstp_configure_http_source(GstElement *element, GHashTable *headers);
