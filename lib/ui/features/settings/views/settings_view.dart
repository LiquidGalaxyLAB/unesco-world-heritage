import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/lg_connection_settings.dart';
import '../../auth/views/auth_view.dart';
import '../../heritage_sites/heritage_sites_dependencies.dart';
import '../../heritage_sites/view_models/heritage_sites_view_model.dart';
import '../../search/views/search_view.dart';
import '../../about/views/about_view.dart';
import '../settings_dependencies.dart';
import '../view_models/settings_view_model.dart';
import 'widgets/about_components.dart';
import 'widgets/command_tab.dart';
import 'widgets/lg_action_buttons.dart';
import 'widgets/lg_connection_header.dart';
import 'widgets/lg_error_card.dart';
import 'widgets/lg_text_field.dart';
import '../../home/views/home_view.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell>
    with SingleTickerProviderStateMixin {
  static const List<_BottomNavDestination> _destinations = [
    _BottomNavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _BottomNavDestination(
      label: 'Search',
      icon: Icons.search,
      selectedIcon: Icons.search_rounded,
    ),
    _BottomNavDestination(
      label: 'Auth',
      icon: Icons.vpn_key_outlined,
      selectedIcon: Icons.vpn_key_rounded,
    ),
    _BottomNavDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
    _BottomNavDestination(
      label: 'About',
      icon: Icons.info_outline_rounded,
      selectedIcon: Icons.info_rounded,
    ),
  ];

  int _currentIndex = 0; // Default to Home tab
  late final SettingsViewModel _settingsViewModel;
  late final HeritageSitesViewModel _heritageSitesViewModel;
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _settingsViewModel = SettingsDependencies.createViewModel();
    _settingsViewModel.loadSettings();
    _heritageSitesViewModel = HeritageSitesDependencies.createSitesViewModel();
    _heritageSitesViewModel.loadSites();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _settingsViewModel.dispose();
    _heritageSitesViewModel.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
    _fadeController.reset();
    _fadeController.forward();
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return HomeView(
          settingsViewModel: _settingsViewModel,
          sitesViewModel: _heritageSitesViewModel,
        );
      case 1:
        return SearchView(
          viewModel: _settingsViewModel,
          sitesViewModel: _heritageSitesViewModel,
        );
      case 2:
        return AuthView(viewModel: _settingsViewModel);
      case 3:
        return SettingsView(viewModel: _settingsViewModel);
      case 4:
      default:
        return AboutView(viewModel: _settingsViewModel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: FadeTransition(opacity: _fadeController, child: _buildBody()),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 16.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32.0),
              child: Material(
                color: AppColors.surfaceContainerHigh.withValues(alpha: 0.95),
                child: SizedBox(
                  height: 72,
                  child: Row(
                    children: [
                      for (var index = 0; index < _destinations.length; index++)
                        Expanded(
                          child: _BottomNavItem(
                            destination: _destinations[index],
                            isSelected: _currentIndex == index,
                            onTap: () => _onTabSelected(index),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavDestination {
  const _BottomNavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final _BottomNavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          containedInkWell: false,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryContainer
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? destination.selectedIcon : destination.icon,
                color: isSelected
                    ? AppColors.onPrimaryContainer
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.viewModel});

  final SettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: Text(
                  'Settings',
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
              TabBar(
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 5,
                labelPadding: EdgeInsets.zero,
                labelStyle: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                unselectedLabelStyle: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: 'LG Connection'),
                  Tab(text: 'LG Commands'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ConnectionTab(viewModel: viewModel),
                    CommandTab(viewModel: viewModel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectionTab extends StatefulWidget {
  const ConnectionTab({super.key, required this.viewModel});

  final SettingsViewModel viewModel;

  @override
  State<ConnectionTab> createState() => _ConnectionTabState();
}

class _ConnectionTabState extends State<ConnectionTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _screensController;
  bool _obscurePassword = true;
  Timer? _draftSaveTimer;

  @override
  void initState() {
    super.initState();
    final settings = widget.viewModel.state.settings;
    _hostController = TextEditingController(text: settings?.host ?? '');
    _portController = TextEditingController(
      text: settings?.port.toString() ?? '22',
    );
    _usernameController = TextEditingController(
      text: settings?.username ?? 'lg',
    );
    _passwordController = TextEditingController(text: settings?.password ?? '');
    _screensController = TextEditingController(
      text: settings?.screens.toString() ?? '3',
    );

    _hostController.addListener(_scheduleDraftSave);
    _passwordController.addListener(_scheduleDraftSave);

    widget.viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChanged);
    _draftSaveTimer?.cancel();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _screensController.dispose();
    super.dispose();
  }

  void _scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), () {
      final host = _hostController.text.trim();
      final password = _passwordController.text;
      if (host.isEmpty || password.isEmpty) return;

      widget.viewModel.saveSettings(_getFormSettings());
    });
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    final settings = widget.viewModel.state.settings;
    if (settings == null) {
      _hostController.clear();
      _portController.text = '22';
      _usernameController.text = 'lg';
      _passwordController.clear();
      _screensController.text = '3';
    } else {
      if (_hostController.text != settings.host) {
        _hostController.text = settings.host;
      }
      if (_portController.text != settings.port.toString()) {
        _portController.text = settings.port.toString();
      }
      if (_usernameController.text != settings.username) {
        _usernameController.text = settings.username;
      }
      if (_passwordController.text != settings.password) {
        _passwordController.text = settings.password;
      }
      if (_screensController.text != settings.screens.toString()) {
        _screensController.text = settings.screens.toString();
      }
    }
  }

  LGConnectionSettings _getFormSettings() {
    return LGConnectionSettings(
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 22,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      screens: int.tryParse(_screensController.text.trim()) ?? 3,
    );
  }

  void _handleConnect() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.viewModel.connect(_getFormSettings());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attempting to connect to Liquid Galaxy...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleSave() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.viewModel.saveSettings(_getFormSettings());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleClear() {
    widget.viewModel.clearSettings();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connection settings cleared.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final state = widget.viewModel.state;

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.errorMessage != null) ...[
                      LGErrorCard(
                        errorMessage: state.errorMessage!,
                        onClose: () => widget.viewModel.clearError(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    LGTextField(
                      controller: _hostController,
                      label: 'IP Address',
                      hint: 'IP Address',
                      icon: Icons.computer_outlined,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter IP address or host name'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    LGTextField(
                      controller: _usernameController,
                      label: 'LG Username',
                      hint: 'LG Username',
                      icon: Icons.person,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter SSH username'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    LGTextField(
                      controller: _passwordController,
                      label: 'LG Password',
                      hint: 'LG Password',
                      icon: Icons.lock,
                      obscureText: _obscurePassword,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter SSH password'
                          : null,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.onSurfaceVariant,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LGTextField(
                      controller: _portController,
                      label: 'SSH Port',
                      hint: 'SSH Port',
                      icon: Icons.code_rounded,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter port';
                        }
                        if (int.tryParse(value.trim()) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    LGTextField(
                      controller: _screensController,
                      label: 'No. of Rigs',
                      hint: 'No. of Rigs',
                      icon: Icons.settings_input_component_rounded,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter screens';
                        }
                        if (int.tryParse(value.trim()) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 72),
                    LGActionButtons(
                      isConnected: state.isConnected,
                      onConnectPressed: state.isConnected
                          ? () => widget.viewModel.disconnect()
                          : _handleConnect,
                      onSavePressed: _handleSave,
                      onClearPressed: _handleClear,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
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

class AboutTab extends StatelessWidget {
  const AboutTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceContainerHigh,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/Unesco_App_LOGO.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.account_balance_rounded,
                      color: AppColors.primary,
                      size: 60,
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'UNESCO World Heritage',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Liquid Galaxy Controller',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Text(
              'v1.0.0',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Row(
            children: [
              Expanded(
                child: AboutOrgCard(
                  title: 'Liquid Galaxy',
                  subtitle: 'LAB Project',
                  icon: Icons.public_rounded,
                  color: AppColors.secondary,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: AboutOrgCard(
                  title: 'Google Summer',
                  subtitle: 'of Code 2026',
                  icon: Icons.code_rounded,
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AboutInfoSection(
            title: 'Project Overview',
            child: Text(
              'This application was developed as part of Google Summer of Code (GSoC) 2026. '
              'It provides an immersive controller interface to explore, search, and visualize '
              'global UNESCO World Heritage sites panoramic displays using a Liquid Galaxy rig.\n\n'
              'Users can fly to specific heritage sites, trigger pre-configured orbits, and learn about the '
              'importance of these cultural, natural, and mixed sites.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurface.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const AboutInfoSection(
            title: 'Quick Connection Guide',
            child: Column(
              children: [
                AboutGuideStep(
                  stepNum: '1',
                  text:
                      'Access the LG Connection tab and input the Master node IP address of your Liquid Galaxy rig.',
                ),
                Divider(height: 24),
                AboutGuideStep(
                  stepNum: '2',
                  text:
                      'Check and update the default port (22), username (lg), password, and screen count.',
                ),
                Divider(height: 24),
                AboutGuideStep(
                  stepNum: '3',
                  text:
                      'Tap "CONNECT SYSTEM" to authenticate. Once active, the system status indicator will turn green.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
