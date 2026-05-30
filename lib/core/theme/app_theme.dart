import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static const double _fullCorner = 9999;
  static const double _chipCorner = 8;
  static const double _cardCorner = 8;
  static const double _fabCorner = 16;
  static const double _dialogCorner = 28;
  static const double _snackCorner = 4;
  static const double _listTileCorner = 4;
  static const double _tooltipCorner = 8;
  static const double _inputCorner = 5;
  static const double _appBarScrolledElevation = 3;
  static const double _fabElevation = 3;
  static const double _navBarElevation = 3;
  static const double _primaryTonal12 = 0.12;
  static const double _primaryTonal50 = 0.5;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _colorScheme,
      textTheme: _textTheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: _appBarTheme,
      cardTheme: _cardTheme,
      filledButtonTheme: _filledButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      floatingActionButtonTheme: _floatingActionButtonTheme,
      bottomNavigationBarTheme: _bottomNavigationBarTheme,
      navigationBarTheme: _navigationBarTheme,
      chipTheme: _chipTheme,
      inputDecorationTheme: _inputDecorationTheme,
      dividerTheme: _dividerTheme,
      snackBarTheme: _snackBarTheme,
      dialogTheme: _dialogTheme,
      bottomSheetTheme: _bottomSheetTheme,
      listTileTheme: _listTileTheme,
      switchTheme: _switchTheme,
      checkboxTheme: _checkboxTheme,
      radioTheme: _radioTheme,
      sliderTheme: _sliderTheme,
      progressIndicatorTheme: _progressIndicatorTheme,
      tooltipTheme: _tooltipTheme,
      tabBarTheme: _tabBarTheme,
    );
  }

  static ColorScheme get _colorScheme {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainerHighest: AppColors.surfaceVariant,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      inverseSurface: AppColors.inverseSurface,
      inversePrimary: AppColors.inversePrimary,
      shadow: AppColors.shadow,
      scrim: AppColors.scrim,
    );
  }

  static TextTheme get _textTheme {
    final base = Typography.material2021().white;

    return base.apply(
      fontFamily: 'GoogleSans',
      bodyColor: AppColors.onSurface,
      displayColor: AppColors.onSurface,
    );
  }

  static AppBarTheme get _appBarTheme {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: _appBarScrolledElevation,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.onSurface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    );
  }

  static CardThemeData get _cardTheme {
    return CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardCorner),
      ),
    );
  }

  static FilledButtonThemeData get _filledButtonTheme {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_fullCorner)),
        ),
      ),
    );
  }

  static OutlinedButtonThemeData get _outlinedButtonTheme {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_fullCorner)),
        ),
      ),
    );
  }

  static TextButtonThemeData get _textButtonTheme {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_fullCorner)),
        ),
      ),
    );
  }

  static FloatingActionButtonThemeData get _floatingActionButtonTheme {
    return FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryContainer,
      foregroundColor: AppColors.onPrimaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_fabCorner),
      ),
      elevation: _fabElevation,
    );
  }

  static BottomNavigationBarThemeData get _bottomNavigationBarTheme {
    return BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceContainer,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.onSurfaceVariant,
      elevation: _navBarElevation,
    );
  }

  static NavigationBarThemeData get _navigationBarTheme {
    return NavigationBarThemeData(
      backgroundColor: AppColors.surfaceContainer,
      indicatorColor: AppColors.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(_navigationLabelStyle),
      iconTheme: WidgetStateProperty.resolveWith(_navigationIconTheme),
      elevation: _navBarElevation,
    );
  }

  static TextStyle? _navigationLabelStyle(Set<WidgetState> states) {
    if (states.contains(WidgetState.selected)) {
      return _textTheme.labelSmall?.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w500,
      );
    }

    return _textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant);
  }

  static IconThemeData _navigationIconTheme(Set<WidgetState> states) {
    if (states.contains(WidgetState.selected)) {
      return IconThemeData(color: AppColors.onPrimaryContainer);
    }

    return const IconThemeData(color: AppColors.onSurfaceVariant);
  }

  static ChipThemeData get _chipTheme {
    return ChipThemeData(
      backgroundColor: AppColors.surfaceContainerHighest,
      selectedColor: AppColors.primaryContainer,
      labelStyle: _textTheme.labelLarge,
      secondaryLabelStyle: _textTheme.labelLarge?.copyWith(
        color: AppColors.onPrimaryContainer,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_chipCorner),
      ),
    );
  }

  static InputDecorationTheme get _inputDecorationTheme {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceContainerHighest,
      border: _outlineInputBorder(AppColors.outline),
      enabledBorder: _outlineInputBorder(AppColors.outline),
      focusedBorder: _outlineInputBorder(AppColors.primary, width: 2),
      errorBorder: _outlineInputBorder(AppColors.error, width: 2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  static OutlineInputBorder _outlineInputBorder(
    Color color, {
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_inputCorner),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static DividerThemeData get _dividerTheme {
    return const DividerThemeData(
      color: AppColors.outlineVariant,
      thickness: 1,
    );
  }

  static SnackBarThemeData get _snackBarTheme {
    return SnackBarThemeData(
      backgroundColor: AppColors.inverseSurface,
      contentTextStyle: _textTheme.bodyMedium?.copyWith(
        color: AppColors.inverseOnSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_snackCorner),
      ),
      behavior: SnackBarBehavior.floating,
    );
  }

  static DialogThemeData get _dialogTheme {
    return DialogThemeData(
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_dialogCorner),
      ),
    );
  }

  static BottomSheetThemeData get _bottomSheetTheme {
    return BottomSheetThemeData(
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_dialogCorner),
        ),
      ),
    );
  }

  static ListTileThemeData get _listTileTheme {
    return ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor: AppColors.primaryContainer.withValues(
        alpha: _primaryTonal12,
      ),
      iconColor: AppColors.onSurfaceVariant,
      textColor: AppColors.onSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_listTileCorner),
      ),
    );
  }

  static SwitchThemeData get _switchTheme {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(_switchThumbColor),
      trackColor: WidgetStateProperty.resolveWith(_switchTrackColor),
    );
  }

  static Color _switchThumbColor(Set<WidgetState> states) {
    if (states.contains(WidgetState.selected)) return AppColors.primary;

    return AppColors.outline;
  }

  static Color _switchTrackColor(Set<WidgetState> states) {
    if (states.contains(WidgetState.selected)) {
      return AppColors.primary.withValues(alpha: _primaryTonal50);
    }

    return AppColors.surfaceVariant;
  }

  static CheckboxThemeData get _checkboxTheme {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(_checkboxFillColor),
      checkColor: WidgetStateProperty.all(AppColors.onPrimary),
      side: const BorderSide(color: AppColors.outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_chipCorner),
      ),
    );
  }

  static Color _checkboxFillColor(Set<WidgetState> states) {
    if (states.contains(WidgetState.selected)) return AppColors.primary;

    return Colors.transparent;
  }

  static RadioThemeData get _radioTheme {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(_radioFillColor),
    );
  }

  static Color _radioFillColor(Set<WidgetState> states) {
    if (states.contains(WidgetState.selected)) return AppColors.primary;

    return AppColors.outline;
  }

  static SliderThemeData get _sliderTheme {
    return SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.surfaceVariant,
      thumbColor: AppColors.primary,
      overlayColor: AppColors.primary.withValues(alpha: _primaryTonal12),
    );
  }

  static ProgressIndicatorThemeData get _progressIndicatorTheme {
    return const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.surfaceVariant,
      circularTrackColor: AppColors.surfaceVariant,
    );
  }

  static TooltipThemeData get _tooltipTheme {
    return TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.inverseSurface,
        borderRadius: BorderRadius.circular(_tooltipCorner),
      ),
      textStyle: _textTheme.bodySmall?.copyWith(
        color: AppColors.inverseOnSurface,
      ),
    );
  }

  static TabBarThemeData get _tabBarTheme {
    return TabBarThemeData(
      dividerColor: AppColors.outline,
      indicatorColor: AppColors.primary,
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.onSurfaceVariant,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
    );
  }
}
