# PRD: Playback stability

## Problem

Built-in controls show four coupled failures: rapid play/pause freezes (and fullscreen pause does not stick), scrub seek appears dead, scrub preview thumbnails fail, and occasional native/session crashes.

## Goals

1. Play/pause remains responsive under rapid taps; fullscreen pause stops A/V and is not undone by Surface rebind.
2. Progress scrub seek lands near the requested position without entering session `error`.
3. Scrub preview shows a frame near the hover/drag time (or a clear placeholder on failure), without blocking seek/transport.
4. Reduce abort / `BufferQueue` / fatal-on-seek crash surfaces during normal control use.

## Non-goals

- Offline sprite/thumbnail tile generation.
- Accurate (non-KEY_UNIT) seek as the default.
- Redesigning control chrome.

## Success criteria

See verification checklist in the implementation plan: rapid toggle, Android fullscreen pause, seek + preview coexistence, and extended soak without fatal session/native abort.
