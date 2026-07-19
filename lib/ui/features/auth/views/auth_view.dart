import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../../settings/views/widgets/lg_connection_header.dart';

class AuthView extends StatefulWidget {
  final SettingsViewModel viewModel;

  const AuthView({super.key, required this.viewModel});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _geminiKeyController = TextEditingController();
  final _googleMapKeyController = TextEditingController();
  bool _obscureGemini = true;
  bool _obscureGoogleMap = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _geminiKeyController.text = prefs.getString('gemini_api_key') ?? '';
      _googleMapKeyController.text =
          prefs.getString('google_map_api_key') ?? '';
    });
  }

  Future<void> _saveKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', _geminiKeyController.text.trim());
    await prefs.setString(
      'google_map_api_key',
      _googleMapKeyController.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Keys saved successfully!')),
      );
    }
  }

  @override
  void dispose() {
    _geminiKeyController.dispose();
    _googleMapKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'API Authentication',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              LgConnectionHeader(viewModel: widget.viewModel),
              const SizedBox(height: 60),

              // Gemini API Key Section
              Center(
                child: Text(
                  'Gemini API Key',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outlineVariant, width: 1),
                ),
                child: TextField(
                  controller: _geminiKeyController,
                  obscureText: _obscureGemini,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter Gemini API Key',
                    hintStyle: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureGemini
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: AppColors.onSurfaceVariant,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureGemini = !_obscureGemini;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Google Map API Key Section
              Center(
                child: Text(
                  'Google Map API Key',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outlineVariant, width: 1),
                ),
                child: TextField(
                  controller: _googleMapKeyController,
                  obscureText: _obscureGoogleMap,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter Google Map API Key',
                    hintStyle: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureGoogleMap
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: AppColors.onSurfaceVariant,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureGoogleMap = !_obscureGoogleMap;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 60),

              // Update Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveKeys,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceContainerHighest,
                    foregroundColor: AppColors.onSurface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Update',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
