import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

class LGConnectionStatusBanner extends StatelessWidget {
  const LGConnectionStatusBanner({
    super.key,
    required this.isConnected,
  });

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isConnected
              ? [
                  AppColors.secondaryContainer.withValues(alpha: 0.8),
                  AppColors.secondaryContainer.withValues(alpha: 0.4),
                ]
              : [
                  AppColors.surfaceContainerHighest,
                  AppColors.surfaceContainerHigh,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? AppColors.secondary.withValues(alpha: 0.3)
              : AppColors.outlineVariant,
        ),
        boxShadow: isConnected
            ? [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isConnected
                  ? AppColors.secondary.withValues(alpha: 0.2)
                  : AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: isConnected ? AppColors.secondary : AppColors.onSurfaceVariant,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'SYSTEM ACTIVE' : 'SYSTEM OFFLINE',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isConnected ? AppColors.onSecondaryContainer : AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isConnected
                      ? 'The device is synchronized and broadcasting live viewport coordinates.'
                      : 'Connect your device to synchronize panorama screens with heritage sites.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isConnected
                        ? AppColors.onSecondaryContainer.withValues(alpha: 0.7)
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
