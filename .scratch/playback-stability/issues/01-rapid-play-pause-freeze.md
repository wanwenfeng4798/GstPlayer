# 01: Rapid play/pause freezes; fullscreen pause still plays

Status: ready-for-agent

## Summary

Continuous play/pause taps freeze the picture. In fullscreen, pausing still leaves audio/video playing.

## Likely causes

- `gstp_pipeline_set_state_sync` blocks the GST thread with `get_state(..., 5s)`.
- Android `setSize` clear/rebind sets `pending_auto_play` and `apply_overlay` forces `gstp_pipeline_play` even after user pause / false PAUSED claim.

## Acceptance

- ≥20 rapid toggles: no freeze; final UI matches A/V.
- Android fullscreen: pause stops A/V; rebind after layout must not auto-resume when `desired_playing` is false.
