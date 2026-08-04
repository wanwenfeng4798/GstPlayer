# 03: Progress bar preview thumbnail invalid

Status: ready-for-agent

## Summary

Scrub preview no longer captures live frames. Host apps supply an external thumbnail track (GSY-style WebVTT / sprite / frames). Dragging shows a frame by time; release hides the bubble.

## Acceptance

- No `GstPlayer.captureThumbnail` on the scrub path.
- `GstVideoView(scrubPreview: …)` accepts WebVTT / sprite / frame list.
- Without `scrubPreview`, drag shows time label only.
