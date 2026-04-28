/// Stub for non-web platforms. Never called on mobile/desktop — the
/// conditional import in `export_service.dart` swaps in
/// `export_web_impl.dart` only when `dart.library.html` is available.
library;

/// No-op on non-web. The real implementation lives in
/// `export_web_impl.dart` and is selected via conditional import.
void triggerWebPdfDownload(List<int> bytes) {}
