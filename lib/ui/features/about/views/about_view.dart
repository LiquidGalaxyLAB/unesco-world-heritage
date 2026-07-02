import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../../settings/views/widgets/lg_connection_header.dart';

class AboutView extends StatelessWidget {
  final SettingsViewModel viewModel;

  const AboutView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final totalWidth = size.width;

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
            const SizedBox(height: 26),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: totalWidth * 0.1,
                      ),
                      child: Image.asset(
                        'assets/images/UNESCO_AboutPageTop.png',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: totalWidth * 0.9,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF005DAA).withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            'UNESCO World Heritage',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: totalWidth > 600 ? 24 : 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text(
                                'About the Application',
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  fontSize: totalWidth > 600 ? 20 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '⬧ This project was created during the Google Summer of Code 2026 alongside the Liquid Galaxy organization.\n\n'
                            '⬧ This app has been developed by Saumya Bhattacharya (email: saumyabhattacharya112@gmail.com) under Liquid Galaxy, thanks to the Google Summer of Code 2026 Program.\n\n'
                            '⬧ The UNESCO World Heritage application provides an immersive interactive experience where users can virtually travel the globe and explore special landmarks that connect us to our shared past and the natural world.\n\n'
                            '⬧ The application features Virtual Tours, comprehensive UNESCO Site Displays, AI-driven Storytelling, instant answers to user doubts and queries, and an immersive educational experience.\n\n'
                            '⬧ It works with the Liquid Galaxy rig to seamlessly synchronize mobile exploration with dynamic screen overlays and multi-screen Google Earth flights.\n\n'
                            '⬧ Thanks to the entire Liquid Galaxy team and the headquarters team for their continuous support, guidance, and encouragement throughout my project. Info in www.liquidgalaxy.eu\n\n\n'
                            'Created & Maintained By - Saumya Bhattacharya\n'
                            'Mentors - Yash Raj Bharti, Rohit Kumar\n'
                            'Organization Admin - Andreu Ibáñez',
                            style: TextStyle(
                              fontSize: totalWidth > 600 ? 16 : 14,
                              fontWeight: FontWeight.normal,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(
                            height: 32,
                            color: AppColors.outlineVariant,
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Important Links',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppColors.onSurface,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  children: [
                                    _buildM3LinkChip(
                                      context,
                                      'Project Repository',
                                      Icons.code_rounded,
                                      'https://github.com/LiquidGalaxyLAB',
                                    ),
                                    _buildM3LinkChip(
                                      context,
                                      'LinkedIn',
                                      Icons.work_outline_rounded,
                                      'https://www.linkedin.com/in/saumya-bhattacharya-2b6bb522b/',
                                    ),
                                    _buildM3LinkChip(
                                      context,
                                      'GitHub',
                                      Icons.account_circle_outlined,
                                      'https://github.com/Saumya-28',
                                    ),
                                    _buildM3LinkChip(
                                      context,
                                      'Email',
                                      Icons.email_outlined,
                                      'mailto:saumyabhattacharya112@gmail.com',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'APIs & Data Sources',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppColors.onSurface,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  children: [
                                    _buildM3Chip(
                                      context,
                                      'Gemini API',
                                      'For the AI Smart Assistant and Story Mode generation.',
                                      'https://ai.google.dev/gemini-api/docs',
                                    ),
                                    _buildM3Chip(
                                      context,
                                      'Open-Meteo',
                                      'For providing real-time weather and climate data.',
                                      'https://open-meteo.com/',
                                    ),
                                    _buildM3Chip(
                                      context,
                                      'ArcGIS Hub',
                                      'For spatial rendering and MultiPolygon geometry datasets.',
                                      'https://www.arcgis.com/home/',
                                    ),
                                    _buildM3Chip(
                                      context,
                                      'UNESCO',
                                      'For the official JSON datasets containing site information.',
                                      'https://whc.unesco.org/',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: totalWidth * 0.9,
                      height: size.height * 0.32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 8,
                          ),
                          child: Image.asset(
                            'assets/images/AboutPage_Bottom_2.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildM3LinkChip(
    BuildContext context,
    String label,
    IconData icon,
    String url,
  ) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.primary),
      label: Text(label),
      backgroundColor: AppColors.surfaceContainer,
      side: const BorderSide(color: AppColors.outlineVariant),
      onPressed: () async {
        if (url.isNotEmpty) {
          final uri = Uri.parse(url);
          try {
            await launchUrl(uri);
          } catch (e) {
            debugPrint('Error launching url: $e');
          }
        }
      },
    );
  }

  Widget _buildM3Chip(
    BuildContext context,
    String label,
    String description,
    String url,
  ) {
    return Tooltip(
      message: description,
      child: ActionChip(
        label: Text(label),
        backgroundColor: AppColors.surfaceContainerHighest,
        side: BorderSide.none,
        labelStyle: const TextStyle(color: AppColors.onSurface),
        onPressed: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label: $description'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (url.isNotEmpty) {
            final uri = Uri.parse(url);
            try {
              await launchUrl(uri);
            } catch (e) {
              debugPrint('Error launching url: $e');
            }
          }
        },
      ),
    );
  }
}
