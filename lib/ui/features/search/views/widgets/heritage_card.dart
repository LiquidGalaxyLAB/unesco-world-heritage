import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';

import '../../../../../core/theme/app_colors.dart';

class HeritageCard extends StatelessWidget {
  final String title;
  final String location;
  final String imageUrl;
  final String category;

  const HeritageCard({
    super.key,
    required this.title,
    required this.location,
    required this.imageUrl,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
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
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                return Shimmer(
                  duration: const Duration(milliseconds: 1400),
                  color: AppColors.onSurface,
                  colorOpacity: 0.12,
                  child: const ColoredBox(
                    color: AppColors.surfaceContainerHighest,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(
                  Icons.image_not_supported_rounded,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            // Gradient Overlay for text readability
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
            // Text Content on Bottom Left
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category,
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
