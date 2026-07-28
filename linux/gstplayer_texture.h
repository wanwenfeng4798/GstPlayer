#ifndef GSTPLAYER_VIDEO_TEXTURE_H_
#define GSTPLAYER_VIDEO_TEXTURE_H_

#include <glib-object.h>

G_BEGIN_DECLS

typedef struct _FlTextureRegistrar FlTextureRegistrar;
typedef struct _GstVideoTexture GstVideoTexture;

GstVideoTexture* gstplayer_texture_new(int64_t player_id,
                                              FlTextureRegistrar* registrar);

void gstplayer_texture_dispose_instance(GstVideoTexture* texture,
                                            FlTextureRegistrar* registrar);

G_END_DECLS

#endif  // GSTPLAYER_VIDEO_TEXTURE_H_
