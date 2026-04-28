/// Handles export and sharing of bookmarks and AI briefings.
///
/// Generates Markdown and PDF representations and delegates to the system
/// share sheet via `share_plus`. On web, the PDF path triggers a browser
/// download instead of the share sheet.
///
/// This is the only file in the app that imports `share_plus` or `pdf` —
/// all other code goes through [ExportService.instance].
library;

import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/article.dart';
import '../repositories/article_repository.dart';
import 'bookmark_service.dart';
import 'export_web_stub.dart'
    if (dart.library.html) 'export_web_impl.dart';

class ExportService {
  ExportService._();
  static final ExportService _instance = ExportService._();
  static ExportService get instance => _instance;

  final ArticleRepository _repo = ArticleRepository();

  /// Builds a Markdown string from a list of articles.
  ///
  /// Layout: a top-level title, an exported-on subtitle, then per-article
  /// blocks separated by `---` rules.
  String buildMarkdown(List<Article> articles) {
    final buffer = StringBuffer();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    buffer.writeln('# My ShiftFeed Bookmarks');
    buffer.writeln('*Exported $dateStr*');
    buffer.writeln();

    for (final article in articles) {
      final published = article.publishedAt != null
          ? DateFormat('yyyy-MM-dd').format(article.publishedAt!)
          : 'unknown';
      buffer.writeln('## ${article.title}');
      buffer.writeln(
        '**Source:** ${article.source}  |  **Published:** $published',
      );
      buffer.writeln(article.url);
      final excerpt = _excerpt(article.summary);
      if (excerpt.isNotEmpty) {
        buffer.writeln('> $excerpt');
      }
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Generates a PDF document from a list of articles.
  ///
  /// Plain layout — no images, no external fonts — so the bytes are
  /// portable across all platforms the `pdf` package supports.
  Future<Uint8List> buildPdf(List<Article> articles) async {
    final doc = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'ShiftFeed Bookmarks',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Exported $dateStr',
            style: const pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 18),
          for (final article in articles) ..._pdfArticleBlock(article),
        ],
      ),
    );

    return doc.save();
  }

  List<pw.Widget> _pdfArticleBlock(Article article) {
    final published = article.publishedAt != null
        ? DateFormat('yyyy-MM-dd').format(article.publishedAt!)
        : 'unknown';
    final excerpt = _excerpt(article.summary);
    return [
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(
          article.title,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.Text(
        '${article.source}  ·  $published',
        style: const pw.TextStyle(
          fontSize: 9,
          color: PdfColors.grey700,
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        article.url,
        style: const pw.TextStyle(
          fontSize: 9,
          color: PdfColors.blue700,
        ),
      ),
      if (excerpt.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        pw.Text(
          excerpt,
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
      pw.SizedBox(height: 8),
      pw.Divider(thickness: 0.5, color: PdfColors.grey400),
      pw.SizedBox(height: 8),
    ];
  }

  String _excerpt(String? summary) {
    if (summary == null) return '';
    final cleaned = summary.trim();
    if (cleaned.length <= 200) return cleaned;
    return '${cleaned.substring(0, 200)}…';
  }

  /// Resolves bookmarked URLs to [Article]s and shares them via the system
  /// share sheet — Markdown by default, PDF when [asPdf] is true.
  ///
  /// Surfaces a SnackBar via [context] when there's nothing to export.
  /// On web with [asPdf] set, triggers a browser download instead of the
  /// share sheet.
  Future<void> shareBookmarks(
    BuildContext context, {
    bool asPdf = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final urls = await BookmarkService.instance.getBookmarks();
    if (urls.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No bookmarks to export')),
      );
      return;
    }
    final articles = await _repo.fetchArticlesByUrls(urls);
    if (articles.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No bookmarks to export')),
      );
      return;
    }

    if (asPdf) {
      final bytes = await buildPdf(articles);
      if (kIsWeb) {
        triggerWebPdfDownload(bytes);
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/shiftfeed_bookmarks.pdf';
      await File(path).writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'ShiftFeed Bookmarks',
      );
      return;
    }

    final markdown = buildMarkdown(articles);
    await Share.share(markdown, subject: 'ShiftFeed Bookmarks');
  }

  /// Shares the provided digest text via the system share sheet as plain
  /// text. The caller is expected to have a non-empty digest in hand —
  /// this method does not check.
  Future<void> shareDigest(String digestText) async {
    await Share.share(digestText, subject: 'ShiftFeed Daily Briefing');
  }
}
