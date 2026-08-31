#include "gstp_internal.h"
#include "http_source.h"

#include <string.h>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

static GstpRuntime g_runtime;
static GOnce g_runtime_once = G_ONCE_INIT;

/* Serializes first-time runtime start across sync + async callers. */
static GMutex g_start_mu;
static GCond g_start_cond;
static gboolean g_start_mu_ready = FALSE;
static gboolean g_start_in_progress = FALSE;
static int32_t g_start_result = GSTP_ERR_OK;

static void gstp_start_gate_ensure(void) {
  if (g_start_mu_ready) {
    return;
  }
  g_mutex_init(&g_start_mu);
  g_cond_init(&g_start_cond);
  g_start_mu_ready = TRUE;
}

static gpointer gstp_runtime_players_init(gpointer data) {
  (void)data;
  g_mutex_init(&g_runtime.players_mu);
  g_runtime.next_id = 1;
  for (int i = 0; i < GSTP_MAX_PLAYERS; i++) {
    g_runtime.players[i].id = 0;
    g_runtime.players[i].in_use = false;
    g_mutex_init(&g_runtime.players[i].frame_mu);
  }
  gstp_start_gate_ensure();
  return NULL;
}

GstpRuntime *gstp_runtime(void) {
  g_once(&g_runtime_once, gstp_runtime_players_init, NULL);
  return &g_runtime;
}

GstpPlayer *gstp_player_lookup(GstpPlayerId id) {
  GstpRuntime *rt = gstp_runtime();
  g_mutex_lock(&rt->players_mu);
  for (int i = 0; i < GSTP_MAX_PLAYERS; i++) {
    if (rt->players[i].in_use && rt->players[i].id == id) {
      GstpPlayer *p = &rt->players[i];
      g_mutex_unlock(&rt->players_mu);
      return p;
    }
  }
  g_mutex_unlock(&rt->players_mu);
  return NULL;
}

typedef struct {
  GSourceFunc func;
  gpointer data;
  GMutex mu;
  GCond cond;
  gboolean done;
} GstpInvokeSync;

static gboolean gstp_invoke_sync_idle(gpointer user_data) {
  GstpInvokeSync *inv = user_data;
  if (inv->func) {
    inv->func(inv->data);
  }
  g_mutex_lock(&inv->mu);
  inv->done = TRUE;
  g_cond_signal(&inv->cond);
  g_mutex_unlock(&inv->mu);
  return G_SOURCE_REMOVE;
}

void gstp_runtime_invoke_sync(GSourceFunc func, gpointer data) {
  GstpRuntime *rt = gstp_runtime();
  if (!rt->initialized || rt->ctx == NULL) {
    if (func) {
      func(data);
    }
    return;
  }

  if (g_main_context_is_owner(rt->ctx)) {
    if (func) {
      func(data);
    }
    return;
  }

  GstpInvokeSync inv = {
      .func = func,
      .data = data,
      .done = FALSE,
  };
  g_mutex_init(&inv.mu);
  g_cond_init(&inv.cond);

  GSource *source = g_idle_source_new();
  g_source_set_callback(source, gstp_invoke_sync_idle, &inv, NULL);
  g_source_attach(source, rt->ctx);
  g_source_unref(source);

  g_mutex_lock(&inv.mu);
  while (!inv.done) {
    g_cond_wait(&inv.cond, &inv.mu);
  }
  g_mutex_unlock(&inv.mu);

  g_mutex_clear(&inv.mu);
  g_cond_clear(&inv.cond);
}

void gstp_runtime_invoke_async(GSourceFunc func, gpointer data) {
  GstpRuntime *rt = gstp_runtime();
  if (!rt->initialized || rt->ctx == NULL) {
    if (func) {
      func(data);
    }
    return;
  }
  GSource *source = g_idle_source_new();
  g_source_set_callback(source, func, data, NULL);
  g_source_attach(source, rt->ctx);
  g_source_unref(source);
}

static gpointer gstp_runtime_thread_main(gpointer data) {
  GstpRuntime *rt = data;
  g_main_context_push_thread_default(rt->ctx);
  g_main_loop_run(rt->loop);
  g_main_context_pop_thread_default(rt->ctx);
  return NULL;
}

/** Performs env/gst_init/thread start. Caller must own the start gate. */
static int32_t gstp_runtime_start_unlocked(void) {
  GstpRuntime *rt = gstp_runtime();
  if (rt->initialized) {
    return GSTP_ERR_OK;
  }

#if defined(__APPLE__) && TARGET_OS_IPHONE
  gstp_setup_ios_env();
#elif defined(__APPLE__)
  gstp_setup_macos_env();
#elif defined(_WIN32)
  gstp_setup_windows_env();
#elif defined(__linux__) && !defined(__ANDROID__)
  gstp_setup_linux_env();
#endif

  gstp_http_user_agent_init_platform();
  gst_init(NULL, NULL);

#if defined(__APPLE__) && TARGET_OS_IPHONE
  gstp_register_ios_static_plugins();
  gstp_register_ios_tls_backend();
#endif

  rt->ctx = g_main_context_new();
  rt->loop = g_main_loop_new(rt->ctx, FALSE);
  rt->thread = g_thread_new("gstp-gst", gstp_runtime_thread_main, rt);
  rt->initialized = true;
  return GSTP_ERR_OK;
}

int32_t gstp_runtime_start(void) {
  GstpRuntime *rt = gstp_runtime();
  gstp_start_gate_ensure();

  g_mutex_lock(&g_start_mu);
  while (g_start_in_progress) {
    g_cond_wait(&g_start_cond, &g_start_mu);
  }
  if (rt->initialized) {
    g_mutex_unlock(&g_start_mu);
    return GSTP_ERR_OK;
  }
  g_start_in_progress = TRUE;
  g_mutex_unlock(&g_start_mu);

  const int32_t code = gstp_runtime_start_unlocked();

  g_mutex_lock(&g_start_mu);
  g_start_result = code;
  g_start_in_progress = FALSE;
  g_cond_broadcast(&g_start_cond);
  g_mutex_unlock(&g_start_mu);
  return code;
}

typedef struct {
  GstpInitDoneFn cb;
  void *ctx;
} GstpInitAsyncJob;

static gpointer gstp_init_async_thread(gpointer data) {
  GstpInitAsyncJob *job = data;
  const int32_t code = gstp_init();
  if (job->cb) {
    job->cb(job->ctx, code);
  }
  g_free(job);
  return NULL;
}

void gstp_init_async(GstpInitDoneFn cb, void *ctx) {
  GstpRuntime *rt = gstp_runtime();
  gstp_start_gate_ensure();

  g_mutex_lock(&g_start_mu);
  if (rt->initialized) {
    const int32_t code = g_start_result;
    g_mutex_unlock(&g_start_mu);
    if (cb) {
      cb(ctx, code);
    }
    return;
  }
  if (g_start_in_progress) {
    /* Wait on a helper thread so the caller's isolate is not blocked. */
    g_mutex_unlock(&g_start_mu);
    GstpInitAsyncJob *job = g_new0(GstpInitAsyncJob, 1);
    job->cb = cb;
    job->ctx = ctx;
    g_thread_unref(g_thread_new("gstp-init-wait", gstp_init_async_thread, job));
    return;
  }
  g_mutex_unlock(&g_start_mu);

  GstpInitAsyncJob *job = g_new0(GstpInitAsyncJob, 1);
  job->cb = cb;
  job->ctx = ctx;
  g_thread_unref(g_thread_new("gstp-init", gstp_init_async_thread, job));
}

void gstp_runtime_stop(void) {
  GstpRuntime *rt = gstp_runtime();
  gstp_start_gate_ensure();

  g_mutex_lock(&g_start_mu);
  while (g_start_in_progress) {
    g_cond_wait(&g_start_cond, &g_start_mu);
  }
  if (!rt->initialized) {
    g_mutex_unlock(&g_start_mu);
    return;
  }
  g_mutex_unlock(&g_start_mu);

  for (int i = 0; i < GSTP_MAX_PLAYERS; i++) {
    if (rt->players[i].in_use) {
      gstp_pipeline_destroy(&rt->players[i]);
      rt->players[i].in_use = false;
    }
  }

  if (rt->loop) {
    g_main_loop_quit(rt->loop);
  }
  if (rt->thread) {
    g_thread_join(rt->thread);
    rt->thread = NULL;
  }
  if (rt->loop) {
    g_main_loop_unref(rt->loop);
    rt->loop = NULL;
  }
  if (rt->ctx) {
    g_main_context_unref(rt->ctx);
    rt->ctx = NULL;
  }
  rt->initialized = false;
}
