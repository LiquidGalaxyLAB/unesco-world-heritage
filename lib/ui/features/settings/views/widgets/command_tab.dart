import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../view_models/settings_view_model.dart';
import 'lg_error_card.dart';

class CommandTab extends StatelessWidget {
  const CommandTab({super.key, required this.viewModel});

  final SettingsViewModel viewModel;

  void _showCommandMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildCommandButton(
    BuildContext context, {
    required String title,
    required VoidCallback onPressed,
    required bool isEnabled,
  }) {
    return Opacity(
      opacity: isEnabled ? 1 : 0.72,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: isEnabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF343434),
            disabledBackgroundColor: const Color(0xFF343434),
            foregroundColor: AppColors.onSurfaceVariant,
            disabledForegroundColor: AppColors.onSurfaceVariant,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: AppColors.outlineVariant),
            ),
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final state = viewModel.state;
        final isConnected = state.isConnected;

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 82, 24, 24),
              child: Column(
                children: [
                  if (state.errorMessage != null) ...[
                    LGErrorCard(
                      errorMessage: state.errorMessage!,
                      onClose: viewModel.clearError,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildCommandButton(
                    context,
                    title: 'Relaunch LG',
                    isEnabled: isConnected,
                    onPressed: () {
                      viewModel.sendRelaunchCommand();
                      _showCommandMessage(context, 'Relaunch command sent');
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildCommandButton(
                    context,
                    title: 'Reboot LG',
                    isEnabled: isConnected,
                    onPressed: () {
                      viewModel.sendRebootCommand();
                      _showCommandMessage(context, 'Reboot command sent');
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildCommandButton(
                    context,
                    title: 'Clean KML+ Logos',
                    isEnabled: isConnected,
                    onPressed: () {
                      viewModel.sendClearKmlAndLogosCommand();
                      _showCommandMessage(
                        context,
                        'Clean KML + logos command sent',
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildCommandButton(
                    context,
                    title: 'Power Off',
                    isEnabled: isConnected,
                    onPressed: () {
                      viewModel.sendPoweroffCommand();
                      _showCommandMessage(context, 'Power off command sent');
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildCommandButton(
                    context,
                    title: 'Clean KML',
                    isEnabled: isConnected,
                    onPressed: () {
                      viewModel.sendClearKmlCommand();
                      _showCommandMessage(context, 'Clean KML command sent');
                    },
                  ),
                ],
              ),
            ),
            if (state.isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
