import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kRed = Color(0xFFEE0000);
const kBg = Color(0xFF0D0D0D);
const kSurface = Color(0xFF1A1A1A);
const kSurface2 = Color(0xFF242424);
const kBorder = Color(0xFF2A2A2A);
const kTextPrimary = Color(0xFFFFFFFF);
const kTextSecondary = Color(0xFF888888);
const kTextMuted = Color(0xFF555555);
const kStatusGreen = Color(0xFF00FF88);

ThemeData appTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBg,
  colorScheme: const ColorScheme.dark(
    primary: kRed,
    surface: kSurface,
  ),
  cardColor: kSurface,
  dividerColor: kBorder,
  fontFamily: 'monospace',
  appBarTheme: const AppBarTheme(
    backgroundColor: kBg,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: kTextPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w800,
      letterSpacing: 2.0,
    ),
    iconTheme: IconThemeData(color: kTextSecondary),
    systemOverlayStyle: SystemUiOverlayStyle.light,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: kSurface2,
    labelStyle: const TextStyle(
      color: kTextSecondary,
      fontSize: 11,
      letterSpacing: 1.0,
      fontWeight: FontWeight.w600,
    ),
    side: const BorderSide(color: kBorder),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    ),
  ),
);
