import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../../settings/views/widgets/lg_connection_header.dart';

class AboutView extends StatelessWidget {
  final SettingsViewModel viewModel;

  const AboutView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Text(
                'About',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LgConnectionHeader(viewModel: viewModel),
            ),
          ],
        ),
      ),
    );
  }
}
