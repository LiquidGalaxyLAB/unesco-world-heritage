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

  Future<void> _showConfirmationDialog(
    BuildContext context, {
    required String actionTitle,
    required VoidCallback onConfirmed,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Confirm Action',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to $actionTitle?',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.85),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onConfirmed();
    }
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
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: const Color(0xFF343434),
            foregroundColor: AppColors.onPrimary,
            disabledForegroundColor: AppColors.onSurfaceVariant,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: isEnabled ? AppColors.primary : AppColors.outlineVariant,
              ),
            ),
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isEnabled
                  ? AppColors.onPrimary
                  : AppColors.onSurfaceVariant,
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
                      _showConfirmationDialog(
                        context,
                        actionTitle: 'Relaunch LG',
                        onConfirmed: () {
                          viewModel.sendRelaunchCommand();
                          _showCommandMessage(context, 'Relaunch command sent');
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildCommandButton(
                    context,
                    title: 'Reboot LG',
                    isEnabled: isConnected,
                    onPressed: () {
                      _showConfirmationDialog(
                        context,
                        actionTitle: 'Reboot LG',
                        onConfirmed: () {
                          viewModel.sendRebootCommand();
                          _showCommandMessage(context, 'Reboot command sent');
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildCommandButton(
                    context,
                    title: 'Clean KML',
                    isEnabled: isConnected,
                    onPressed: () {
                      _showConfirmationDialog(
                        context,
                        actionTitle: 'Clean KML',
                        onConfirmed: () {
                          viewModel.sendClearKmlCommand();
                          _showCommandMessage(context, 'Clean KML command sent');
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildCommandButton(
                    context,
                    title: 'Power Off',
                    isEnabled: isConnected,
                    onPressed: () {
                      _showConfirmationDialog(
                        context,
                        actionTitle: 'Power Off',
                        onConfirmed: () {
                          viewModel.sendPoweroffCommand();
                          _showCommandMessage(context, 'Power off command sent');
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildCommandButton(
                    context,
                    title: 'Clean Logo',
                    isEnabled: isConnected,
                    onPressed: () {
                      _showConfirmationDialog(
                        context,
                        actionTitle: 'Clean Logo',
                        onConfirmed: () {
                          viewModel.sendClearLogoCommand();
                          _showCommandMessage(context, 'Clean logo command sent');
                        },
                      );
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
