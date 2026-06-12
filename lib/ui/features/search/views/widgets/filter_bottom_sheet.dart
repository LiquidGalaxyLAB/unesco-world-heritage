import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

enum _FilterView { main, region, stateNames }

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  RangeValues _yearRange = const RangeValues(1999, 2009);
  bool _showDangerSites = false;
  
  _FilterView _currentView = _FilterView.main;
  final Set<String> _selectedRegions = {'Africa', 'Arab States'};

  final List<String> _allRegions = [
    'Africa',
    'Arab States',
    'Asia and the Pacific',
    'Europe and North America',
    'Latin America and the Caribbean',
  ];

  final Set<String> _selectedStates = {
    'Afghanistan',
    'Albania',
    'Algeria',
    'Andorra'
  };

  final List<String> _allStates = [
    'Afghanistan',
    'Albania',
    'Algeria',
    'Andorra',
    'Angola',
    'Antigua and Barbuda',
    'Argentina',
  ];
  String _stateSearchQuery = '';

  Widget _buildFilterTile(String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _currentView == _FilterView.main 
              ? _buildMainView(context, theme)
              : _currentView == _FilterView.region
                  ? _buildRegionView(context, theme)
                  : _buildStateNamesView(context, theme),
        ),
      ),
    );
  }

  Widget _buildMainView(BuildContext context, ThemeData theme) {
    return Padding(
      key: const ValueKey('main_view'),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48), // Balance for centering title
              Text(
                'Filter Preferences',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Color(0xFF333333), height: 32),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Year Inscribed',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _yearRange.start == _yearRange.end 
                                ? 'Inscription Year: ${_yearRange.start.toInt()}'
                                : 'Inscription Year: ${_yearRange.start.toInt()}-${_yearRange.end.toInt()}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor: Colors.grey[700],
                            thumbColor: AppColors.primary,
                            overlayColor: AppColors.primary.withValues(alpha: 0.2),
                            trackHeight: 4.0,
                            rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 8),
                          ),
                          child: RangeSlider(
                            values: _yearRange,
                            min: 1978,
                            max: 2025,
                            divisions: 2025 - 1978,
                            labels: RangeLabels(
                              _yearRange.start.toInt().toString(),
                              _yearRange.end.toInt().toString(),
                            ),
                            onChanged: (RangeValues values) {
                              setState(() {
                                _yearRange = values;
                              });
                            },
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('1978', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('2025', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildFilterTile('Region', () {
                    setState(() => _currentView = _FilterView.region);
                  }),
                  _buildFilterTile('State Names', () {
                    setState(() => _currentView = _FilterView.stateNames);
                  }),
                  _buildFilterTile('Category', () {}),
                  
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Switch(
                        value: _showDangerSites,
                        activeColor: Colors.black,
                        activeTrackColor: Colors.white,
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: const Color(0xFF2D2D2D),
                        onChanged: (val) => setState(() => _showDangerSites = val),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Show sites "In Danger"',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.warning_rounded, color: Colors.redAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _yearRange = const RangeValues(1978, 2025);
                    _showDangerSites = false;
                    _selectedRegions.clear();
                    _selectedStates.clear();
                  });
                },
                child: const Text(
                  'clear filters',
                  style: TextStyle(
                    color: Colors.white70,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white70,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE0E0E0),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text(
                  'Show results',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRegionView(BuildContext context, ThemeData theme) {
    return Padding(
      key: const ValueKey('region_view'),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () => setState(() => _currentView = _FilterView.main),
              ),
              const SizedBox(width: 8),
              Text(
                'Region',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerRight,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF333333), height: 1),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: _allRegions.map((region) {
                return Theme(
                  data: theme.copyWith(
                    unselectedWidgetColor: Colors.white,
                  ),
                  child: CheckboxListTile(
                    checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      region,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    value: _selectedRegions.contains(region),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedRegions.add(region);
                        } else {
                          _selectedRegions.remove(region);
                        }
                      });
                    },
                    fillColor: WidgetStateProperty.all(Colors.white),
                    checkColor: Colors.black,
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedRegions.clear();
                  });
                },
                child: const Text(
                  'clear filters',
                  style: TextStyle(
                    color: Colors.white70,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white70,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () {
                  setState(() => _currentView = _FilterView.main);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE0E0E0),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text(
                  'Save Preferences',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStateNamesView(BuildContext context, ThemeData theme) {
    final filteredStates = _allStates.where((state) => state.toLowerCase().contains(_stateSearchQuery.toLowerCase())).toList();
    
    return Padding(
      key: const ValueKey('state_names_view'),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () => setState(() {
                  _currentView = _FilterView.main;
                  _stateSearchQuery = '';
                }),
              ),
              const SizedBox(width: 8),
              Text(
                'State Names',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerRight,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SearchBar(
            onChanged: (value) => setState(() => _stateSearchQuery = value),
            hintText: 'Search State Names',
            hintStyle: const WidgetStatePropertyAll(TextStyle(color: Colors.grey)),
            textStyle: const WidgetStatePropertyAll(TextStyle(color: Colors.white)),
            leading: const Icon(Icons.search, color: Colors.grey),
            backgroundColor: const WidgetStatePropertyAll(Color(0xFF3A3A3A)),
            elevation: const WidgetStatePropertyAll(0),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: filteredStates.length,
              itemBuilder: (context, index) {
                final stateName = filteredStates[index];
                return Theme(
                  data: theme.copyWith(
                    unselectedWidgetColor: Colors.white,
                  ),
                  child: CheckboxListTile(
                    checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      stateName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    value: _selectedStates.contains(stateName),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedStates.add(stateName);
                        } else {
                          _selectedStates.remove(stateName);
                        }
                      });
                    },
                    fillColor: WidgetStateProperty.all(Colors.white),
                    checkColor: Colors.black,
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedStates.clear();
                    _stateSearchQuery = '';
                  });
                },
                child: const Text(
                  'clear filters',
                  style: TextStyle(
                    color: Colors.white70,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white70,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _currentView = _FilterView.main;
                    _stateSearchQuery = '';
                  });
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE0E0E0),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text(
                  'Save Preferences',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
