import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
/// The [AppTheme] defines light and dark themes for the app.
///
/// Theme setup for FlexColorScheme package v8.
/// Use same major flex_color_scheme package version. If you use a
/// lower minor version, some properties may not be supported.
/// In that case, remove them after copying this theme to your
/// app or upgrade package to version 8.1.1.
///
/// Use in [MaterialApp] like this:
///
/// MaterialApp(
///   theme: AppTheme.light,
///   darkTheme: AppTheme.dark,
/// );
class AppTheme {
  AppTheme._();
  // The defined light theme.
  static ThemeData light = FlexThemeData.light(
  colors: const FlexSchemeColor( // Custom colors
    primary: Color(0xFF007BFF),
    primaryContainer: Color(0xFFFFFFFF),
    primaryLightRef: Color(0xFF007BFF),
    secondary: Color(0xFF005FEE),
    secondaryContainer: Color(0xFFEBF3FF),
    secondaryLightRef: Color(0xFF005FEE),
    tertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF007BFF),
    tertiaryLightRef: Color(0xFFFFFFFF),
    appBarColor: Color(0xFFEBF3FF),
    error: Color(0xFFBA1A1A),
    errorContainer: Color(0xFFFFFFFF),
  ),
  subThemesData: const FlexSubThemesData(
    interactionEffects: true,
    tintedDisabledControls: true,
    useM2StyleDividerInM3: true,
    inputDecoratorSchemeColor: SchemeColor.primaryContainer,
    inputDecoratorIsFilled: true,
    inputDecoratorIsDense: true,
    inputDecoratorBackgroundAlpha: 14,
    inputDecoratorBorderSchemeColor: SchemeColor.primary,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    inputDecoratorRadius: 10.0,
    inputDecoratorUnfocusedBorderIsColored: true,
    inputDecoratorPrefixIconSchemeColor: SchemeColor.onPrimaryFixedVariant,
    fabUseShape: true,
    fabAlwaysCircular: true,
    fabForegroundSchemeColor: SchemeColor.onPrimaryContainer,
    alignedDropdown: true,
    dialogBackgroundSchemeColor: SchemeColor.onPrimary,
    useInputDecoratorThemeInDialogs: true,
    timePickerElementRadius: 18.0,
    datePickerHeaderBackgroundSchemeColor: SchemeColor.primary,
    datePickerDividerSchemeColor: SchemeColor.primary,
    bottomAppBarSchemeColor: SchemeColor.onPrimary,
    tabBarDividerColor: Color(0x00000000),
    drawerIndicatorSchemeColor: SchemeColor.primary,
    drawerSelectedItemSchemeColor: SchemeColor.onSecondary,
    drawerUnselectedItemSchemeColor: SchemeColor.onSurfaceVariant,
    searchBarBackgroundSchemeColor: SchemeColor.primaryContainer,
    searchViewBackgroundSchemeColor: SchemeColor.primaryContainer,
    navigationBarUnselectedLabelSchemeColor: SchemeColor.primary,
    navigationBarMutedUnselectedLabel: true,
    navigationBarUnselectedIconSchemeColor: SchemeColor.primary,
    navigationBarMutedUnselectedIcon: true,
    navigationBarIndicatorSchemeColor: SchemeColor.primary,
    navigationBarBackgroundSchemeColor: SchemeColor.primaryContainer,
    navigationRailUseIndicator: true,
    navigationRailLabelType: NavigationRailLabelType.all,
  ),
  useMaterial3ErrorColors: true,
  visualDensity: FlexColorScheme.comfortablePlatformDensity,
  cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );
  // The defined dark theme.
  static ThemeData dark = FlexThemeData.dark(
  colors: const FlexSchemeColor( // Custom colors
    primary: Color(0xFF007BFF),
    primaryContainer: Color(0xFF000710),
    primaryLightRef: Color(0xFF007BFF),
    secondary: Color(0xFF005FEE),
    secondaryContainer: Color(0xFF000710),
    secondaryLightRef: Color(0xFF005FEE),
    tertiary: Color(0xFF007BFF),
    tertiaryContainer: Color(0xFF001C3C),
    tertiaryLightRef: Color(0xFFFFFFFF),
    appBarColor: Color(0xFFEBF3FF),
    error: Color(0xFFFFB4AB),
    errorContainer: Color(0xFF93000A),
  ),
  subThemesData: const FlexSubThemesData(
    interactionEffects: true,
    tintedDisabledControls: true,
    blendOnColors: true,
    useM2StyleDividerInM3: true,
    inputDecoratorSchemeColor: SchemeColor.primary,
    inputDecoratorIsFilled: true,
    inputDecoratorIsDense: true,
    inputDecoratorBackgroundAlpha: 45,
    inputDecoratorBorderSchemeColor: SchemeColor.primary,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    inputDecoratorRadius: 10.0,
    inputDecoratorUnfocusedBorderIsColored: true,
    inputDecoratorPrefixIconSchemeColor: SchemeColor.primaryFixed,
    fabUseShape: true,
    fabAlwaysCircular: true,
    fabForegroundSchemeColor: SchemeColor.onPrimaryContainer,
    alignedDropdown: true,
    useInputDecoratorThemeInDialogs: true,
    timePickerElementRadius: 18.0,
    datePickerHeaderBackgroundSchemeColor: SchemeColor.primary,
    datePickerDividerSchemeColor: SchemeColor.primary,
    tabBarDividerColor: Color(0x00000000),
    drawerIndicatorSchemeColor: SchemeColor.primary,
    drawerSelectedItemSchemeColor: SchemeColor.onSecondary,
    drawerUnselectedItemSchemeColor: SchemeColor.onSurfaceVariant,
    searchBarBackgroundSchemeColor: SchemeColor.primaryContainer,
    searchViewBackgroundSchemeColor: SchemeColor.primaryContainer,
    navigationBarUnselectedLabelSchemeColor: SchemeColor.primary,
    navigationBarMutedUnselectedLabel: true,
    navigationBarUnselectedIconSchemeColor: SchemeColor.primary,
    navigationBarMutedUnselectedIcon: true,
    navigationBarIndicatorSchemeColor: SchemeColor.primary,
    navigationBarBackgroundSchemeColor: SchemeColor.primaryContainer,
    navigationRailUseIndicator: true,
    navigationRailLabelType: NavigationRailLabelType.all,
  ),
  useMaterial3ErrorColors: true,
  visualDensity: FlexColorScheme.comfortablePlatformDensity,
  cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );
}
