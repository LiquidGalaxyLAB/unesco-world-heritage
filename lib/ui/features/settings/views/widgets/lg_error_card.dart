import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

class LGErrorCard extends StatelessWidget {
  const LGErrorCard({
    super.key,
    required this.errorMessage,
    required this.onClose,
  });

  final String errorMessage;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 20),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
