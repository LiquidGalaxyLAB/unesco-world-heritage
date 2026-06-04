import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

class LGActionButtons extends StatelessWidget {
  const LGActionButtons({
    super.key,
    required this.isConnected,
    required this.onConnectPressed,
    required this.onSavePressed,
    required this.onClearPressed,
  });

  final bool isConnected;
  final VoidCallback onConnectPressed;
  final VoidCallback onSavePressed;
  final VoidCallback onClearPressed;

  Color _getForegroundColor(bool isConnected) {
    return isConnected ? AppColors.onErrorContainer : AppColors.onPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: onConnectPressed,
            style: FilledButton.styleFrom(
              backgroundColor: isConnected
                  ? AppColors.error
                  : AppColors.lgButton,
              foregroundColor: _getForegroundColor(isConnected),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Text(
              isConnected ? 'Disconnect LG' : 'Connect to LG',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: onSavePressed,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onClearPressed,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Clear',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
