import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

class WikipediaImageService {
  WikipediaImageService({http.Client? client, this.maxConcurrentRequests = 6})
    : assert(maxConcurrentRequests > 0),
      _client = client ?? http.Client();

  static const String _searchEndpoint =
      'https://en.wikipedia.org/w/rest.php/v1/search/page';
  static const String _summaryEndpoint =
      'https://en.wikipedia.org/api/rest_v1/page/summary';
  static const int _preferredImageWidth = 960;

  final http.Client _client;
  final int maxConcurrentRequests;
  final Map<String, Future<String?>> _imageCache = <String, Future<String?>>{};
  final Map<String, Future<String?>> _summaryCache = <String, Future<String?>>{};
  final Queue<Completer<void>> _requestQueue = Queue<Completer<void>>();
  int _activeRequests = 0;

  Future<String?> fetchImageUrl(String siteName) {
    final normalizedName = siteName.trim();
    if (normalizedName.isEmpty) {
      return Future<String?>.value();
    }

    return _imageCache.putIfAbsent(
      normalizedName.toLowerCase(),
      () => _fetchImageUrl(normalizedName),
    );
  }

  Future<String?> fetchShortDescription(String siteName) {
    final normalizedName = siteName.trim();
    if (normalizedName.isEmpty) {
      return Future<String?>.value();
    }

    return _summaryCache.putIfAbsent(
      normalizedName.toLowerCase(),
      () => _fetchShortDescription(normalizedName),
    );
  }

  Future<String?> _fetchImageUrl(String siteName) async {
    await _acquireRequestSlot();
    try {
      final pages = await _searchPages(siteName);
      if (pages.isEmpty) {
        return null;
      }

      Map<dynamic, dynamic>? firstPageWithThumbnail;
      for (final page in pages.whereType<Map>()) {
        final thumbnailUrl = _readThumbnailUrl(page);
        if (thumbnailUrl == null) {
          continue;
        }

        firstPageWithThumbnail ??= page;
        if (_isExactMatch(page, siteName)) {
          return thumbnailUrl;
        }
      }

      return firstPageWithThumbnail == null
          ? null
          : _readThumbnailUrl(firstPageWithThumbnail);
    } catch (_) {
      return null;
    } finally {
      _releaseRequestSlot();
    }
  }

  Future<String?> _fetchShortDescription(String siteName) async {
    await _acquireRequestSlot();
    try {
      final pages = await _searchPages(siteName);
      if (pages.isEmpty) {
        return null;
      }

      Map<dynamic, dynamic>? selectedPage;
      for (final page in pages.whereType<Map>()) {
        if (_isExactMatch(page, siteName)) {
          selectedPage = page;
          break;
        }
        selectedPage ??= page;
      }

      if (selectedPage == null) {
        return null;
      }

      final pageKey = selectedPage['key'];
      final pageTitle = selectedPage['title'];
      final summarySlug = pageKey is String && pageKey.trim().isNotEmpty
          ? pageKey.trim()
          : pageTitle is String && pageTitle.trim().isNotEmpty
          ? pageTitle.trim().replaceAll(' ', '_')
          : null;
      if (summarySlug == null) {
        return null;
      }

      final summaryUri = Uri.parse(
        '$_summaryEndpoint/${Uri.encodeComponent(summarySlug)}',
      );
      final response = await _client.get(summaryUri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return null;
      }

      final extract = decoded['extract'];
      if (extract is! String || extract.trim().isEmpty) {
        return null;
      }

      return extract.replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (_) {
      return null;
    } finally {
      _releaseRequestSlot();
    }
  }

  Future<List<dynamic>> _searchPages(String siteName) async {
    final query = siteName.replaceAll(RegExp(r'\s+'), '_');
    final uri = Uri.parse(
      _searchEndpoint,
    ).replace(queryParameters: <String, String>{'q': query, 'limit': '20'});

    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const <dynamic>[];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      return const <dynamic>[];
    }

    final pages = decoded['pages'];
    return pages is List ? pages : const <dynamic>[];
  }

  String? _readThumbnailUrl(Map<dynamic, dynamic> page) {
    final thumbnail = page['thumbnail'];
    if (thumbnail is! Map) {
      return null;
    }

    final url = thumbnail['url'];
    if (url is! String || url.trim().isEmpty) {
      return null;
    }

    final trimmedUrl = url.trim();
    final absoluteUrl = trimmedUrl.startsWith('//')
        ? 'https:$trimmedUrl'
        : trimmedUrl;
    return _requestLargerWikimediaThumbnail(absoluteUrl);
  }

  bool _isExactMatch(Map<dynamic, dynamic> page, String siteName) {
    final normalizedSiteName = _normalizeTitle(siteName);
    final title = page['title'];
    final key = page['key'];
    return (title is String && _normalizeTitle(title) == normalizedSiteName) ||
        (key is String && _normalizeTitle(key) == normalizedSiteName);
  }

  String _requestLargerWikimediaThumbnail(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.host != 'upload.wikimedia.org' ||
        !uri.path.contains('/thumb/')) {
      return url;
    }

    final resizedPath = uri.path.replaceFirstMapped(
      RegExp(r'/\d+px-([^/]+)$'),
      (match) => '/${_preferredImageWidth}px-${match.group(1)}',
    );
    return uri.replace(path: resizedPath).toString();
  }

  String _normalizeTitle(String value) {
    return value
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  Future<void> _acquireRequestSlot() async {
    if (_activeRequests < maxConcurrentRequests) {
      _activeRequests++;
      return;
    }

    final completer = Completer<void>();
    _requestQueue.add(completer);
    await completer.future;
    _activeRequests++;
  }

  void _releaseRequestSlot() {
    _activeRequests--;
    if (_requestQueue.isNotEmpty) {
      _requestQueue.removeFirst().complete();
    }
  }
}
