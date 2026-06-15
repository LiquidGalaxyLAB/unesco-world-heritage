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
  static const int _preferredImageWidth = 960;

  final http.Client _client;
  final int maxConcurrentRequests;
  final Map<String, Future<String?>> _imageCache = <String, Future<String?>>{};
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

  Future<String?> _fetchImageUrl(String siteName) async {
    await _acquireRequestSlot();
    try {
      final query = siteName.replaceAll(RegExp(r'\s+'), '_');
      final uri = Uri.parse(
        _searchEndpoint,
      ).replace(queryParameters: <String, String>{'q': query, 'limit': '20'});

      final response = await _client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return null;
      }

      final pages = decoded['pages'];
      if (pages is! List) {
        return null;
      }

      final normalizedSiteName = _normalizeTitle(siteName);
      Map<dynamic, dynamic>? firstPageWithThumbnail;
      for (final page in pages.whereType<Map>()) {
        final thumbnailUrl = _readThumbnailUrl(page);
        if (thumbnailUrl == null) {
          continue;
        }

        firstPageWithThumbnail ??= page;
        final title = page['title'];
        final key = page['key'];
        if ((title is String && _normalizeTitle(title) == normalizedSiteName) ||
            (key is String && _normalizeTitle(key) == normalizedSiteName)) {
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
