# 04: Intermittent crash / fatal session

Status: ready-for-agent

## Summary

Occasional process abort or session death during normal play, fullscreen, scrub, or preview.

## Likely causes

- Android Surface `setSize` / overlay bind races.
- Thumbnail + main pipeline resource contention.
- Seek failure promoted to fatal `PlayerState.error` (feels like a crash).

## Acceptance

- Soft seek failure; thumbnail isolate + single in-flight capture.
- Pause after fullscreen rebind does not force play.
- Soak of toggle/seek/preview without native abort or sticky session error.
