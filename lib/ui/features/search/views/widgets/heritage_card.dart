import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer_animation/shimmer_animation.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/services/wikipedia_image_service.dart';

// ---------------------------------------------------------------------------
// HeritageCard
// ---------------------------------------------------------------------------

/// A card that displays a heritage site image, title, location and category.
///
/// When [imageUrl] is empty and [siteName] is provided the card lazily fetches
/// a Wikipedia thumbnail so sites without UNESCO photos (e.g. Sundarbans
/// National Park) still show an image. The fetch is done per-card so the
/// bulk list load is never slowed down.
class HeritageCard extends StatefulWidget {
  const HeritageCard({
    super.key,
    required this.title,
    required this.location,
    required this.imageUrl,
    required this.category,
    this.siteName,
  });

  final String title;
  final String location;
  final String imageUrl;
  final String category;

  /// Site name used for the Wikipedia image fallback when [imageUrl] is empty.
  /// Pass [HeritageSite.name] here from the caller.
  final String? siteName;

  @override
  State<HeritageCard> createState() => _HeritageCardState();
}

class _HeritageCardState extends State<HeritageCard> {
  /// Shared across all card instances so the same site is never fetched twice
  /// during a session (WikipediaImageService has its own internal Future-cache).
  static final WikipediaImageService _wikiService = WikipediaImageService();

  /// Resolved image URL — starts as the passed-in URL, may be filled by the
  /// Wikipedia fallback fetch.
  late String _resolvedImageUrl;

  /// True while the Wikipedia fallback fetch is in progress.
  bool _fetchingWikipediaImage = false;

  @override
  void initState() {
    super.initState();
    _resolvedImageUrl = widget.imageUrl;
    _maybeLoadWikipediaFallback();
  }

  @override
  void didUpdateWidget(HeritageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent supplies a real URL now, use it and skip the fallback.
    if (widget.imageUrl != oldWidget.imageUrl) {
      _resolvedImageUrl = widget.imageUrl;
      if (_resolvedImageUrl.isEmpty) {
        _maybeLoadWikipediaFallback();
      }
    }
  }

  /// Kicks off a Wikipedia image fetch only when the UNESCO image is absent.
  Future<void> _maybeLoadWikipediaFallback() async {
    final name = widget.siteName;
    if (_resolvedImageUrl.isNotEmpty || name == null || name.trim().isEmpty) {
      return;
    }

    if (mounted) {
      setState(() => _fetchingWikipediaImage = true);
    }

    final url = await _wikiService.fetchImageUrl(name);

    if (!mounted) return;
    setState(() {
      _fetchingWikipediaImage = false;
      if (url != null && url.isNotEmpty) {
        _resolvedImageUrl = url;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _resolvedImageUrl.trim().isNotEmpty;
    final isLoadingFallback = _fetchingWikipediaImage;

    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.surfaceContainerHighest,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            if (hasImage)
              CachedNetworkImage(
                imageUrl: _resolvedImageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) {
                  return Shimmer(
                    duration: const Duration(milliseconds: 1400),
                    color: AppColors.onSurface,
                    colorOpacity: 0.12,
                    child: const ColoredBox(
                      color: AppColors.surfaceContainerHighest,
                    ),
                  );
                },
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    Icons.image_not_supported_rounded,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              )
            else if (isLoadingFallback)
              // Wikipedia fetch in progress — show shimmer placeholder
              Shimmer(
                duration: const Duration(milliseconds: 1400),
                color: AppColors.onSurface,
                colorOpacity: 0.12,
                child: const ColoredBox(
                  color: AppColors.surfaceContainerHighest,
                ),
              )
            else
              const ColoredBox(
                color: AppColors.surfaceContainerHighest,
                child: Center(
                  child: Icon(
                    Icons.image_not_supported_rounded,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            // Gradient overlay for text readability
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 1.0),
                  ],
                  stops: const [0.4, 0.7, 1.0],
                ),
              ),
            ),
            // Text content on bottom left
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.location,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.category,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HeritageCardSkeleton — unchanged
// ---------------------------------------------------------------------------

class HeritageCardSkeleton extends StatelessWidget {
  const HeritageCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      duration: const Duration(milliseconds: 1400),
      color: AppColors.onSurface,
      colorOpacity: 0.1,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppColors.surfaceContainerHighest,
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 24,
              width: 200,
              decoration: BoxDecoration(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 16,
              width: 120,
              decoration: BoxDecoration(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 14,
              width: 80,
              decoration: BoxDecoration(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
