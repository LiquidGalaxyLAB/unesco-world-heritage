import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../view_models/settings_view_model.dart';

class LgConnectionHeader extends StatelessWidget {
  const LgConnectionHeader({super.key, required this.viewModel});

  final SettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final isConnected = viewModel.state.isConnected;
        final color = isConnected
            ? AppColors.secondary
            : AppColors.lgDisconnected;

        return Row(
          children: [
            Icon(Icons.public_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              isConnected ? 'LG CONNECTED' : 'LG DISCONNECTED',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      },
    );
  }
}
