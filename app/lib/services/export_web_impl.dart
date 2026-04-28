/// Web-only PDF download helper. Selected by the conditional import in
/// `export_service.dart` when `dart.library.html` is available.
library;

// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Triggers a PDF download in the browser by creating an in-memory blob,
/// programmatically clicking an anchor element, and revoking the URL.
void triggerWebPdfDownload(List<int> bytes) {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', 'shiftfeed_bookmarks.pdf')
    ..click();
  html.Url.revokeObjectUrl(url);
}
