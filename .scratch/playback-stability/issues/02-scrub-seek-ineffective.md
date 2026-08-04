# 02: Progress bar seek ineffective

Status: ready-for-agent

## Summary

Dragging the progress bar does not seek (thumb snaps back / no position change / session may enter error).

## Likely causes

- Seek and `gstp_thumbnail_capture` share one `FfiNativeWorker` queue; preview blocks seek.
- Seek failure goes through `_guard` → `PlayerState.error`.
- `isSeekable` only snapshotted at open; never refreshed from events.

## Acceptance

- Scrub end seeks without entering error on soft failure.
- Preview activity must not stall seek beyond settle timeout.
- `isSeekable` updates from native duration/state events.
