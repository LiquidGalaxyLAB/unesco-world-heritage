import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../settings/view_models/settings_view_model.dart';
import 'widgets/heritage_card.dart';

class SearchView extends StatefulWidget {
  final SettingsViewModel viewModel;

  const SearchView({super.key, required this.viewModel});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Discover new sites',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ListenableBuilder(
                listenable: widget.viewModel,
                builder: (context, _) {
                  final isConnected = widget.viewModel.state.isConnected;
                  final color = isConnected ? AppColors.secondary : AppColors.lgDisconnected;
                  return Row(
                    children: [
                      Icon(
                        Icons.public_rounded,
                        color: color,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isConnected ? 'LG CONNECTED' : 'LG DISCONNECTED',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SearchBar(
                controller: _searchController,
                hintText: 'Search Heritage Sites...',
                hintStyle: const WidgetStatePropertyAll(TextStyle(color: AppColors.onSurfaceVariant)),
                textStyle: WidgetStatePropertyAll(theme.textTheme.bodyLarge?.copyWith(color: AppColors.onSurface)),
                leading: const Icon(Icons.search_rounded, color: AppColors.onSurfaceVariant),
                trailing: const [Icon(Icons.tune_rounded, color: AppColors.onSurfaceVariant)],
                backgroundColor: WidgetStatePropertyAll(AppColors.surfaceContainerHigh.withValues(alpha: 0.5)),
                elevation: const WidgetStatePropertyAll(0),
                side: const WidgetStatePropertyAll(BorderSide(color: AppColors.outlineVariant, width: 0.5)),
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                itemCount: 6,
                separatorBuilder: (context, index) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  final titles = [
                    'Bamiyan Valley', 'Minaret and Archaeological Remains of Jam', 'Butrint',
                    'Djémila', 'Acropolis', 'Serengeti'
                  ];
                  final locations = [
                    'Afghanistan', 'Afghanistan', 'Albania',
                    'Algeria', 'Greece', 'Tanzania'
                  ];
                  final images = [
                    'https://images.unsplash.com/photo-1587595431973-160d0d94add1?w=800&q=80',
                    'https://images.unsplash.com/photo-1564507592208-52875692857e?w=800&q=80',
                    'https://images.unsplash.com/photo-1582967635905-2d4e3eb1a3c6?w=800&q=80',
                    'https://images.unsplash.com/photo-1504280741503-f32fe6a47a06?w=800&q=80',
                    'https://images.unsplash.com/photo-1555993539-1732b0258235?w=800&q=80',
                    'https://images.unsplash.com/photo-1516426122078-c23e76319801?w=800&q=80'
                  ];
                  return HeritageCard(
                    title: titles[index],
                    location: locations[index],
                    imageUrl: images[index],
                    category: 'Cultural', 
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

