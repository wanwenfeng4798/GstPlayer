/// Why a user-initiated seek could not be completed.
enum SeekFailureReason {
  /// Network media still buffering; byte-range or full download not ready.
  bufferingIncomplete,

  /// Source lacks seek support (no index, no HTTP byte ranges, etc.).
  notSeekable,
}
