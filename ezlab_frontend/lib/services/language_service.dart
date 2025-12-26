// lib/services/language_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class LanguageService {
  static const String _languageKey = 'app_language';
  static const String _defaultLanguage = 'en';

  static final LanguageService _instance = LanguageService._internal();

  factory LanguageService() {
    return _instance;
  }

  LanguageService._internal();

  // Save selected language
  Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  // Get saved language or default
  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? _defaultLanguage;
  }

  // Check if language is RTL
  static bool isRTL(String languageCode) {
    return languageCode == 'ar';
  }

  // Get text direction
  static TextDirection getTextDirection(String languageCode) {
    return isRTL(languageCode) ? TextDirection.rtl : TextDirection.ltr;
  }

  // Get locale from language code
  static Locale getLocale(String languageCode) {
    switch (languageCode) {
      case 'ar':
        return const Locale('ar', 'SA');
      case 'tr':
        return const Locale('tr', 'TR');
      default:
        return const Locale('en', 'US');
    }
  }

  // Get list of available languages
  static List<LanguageOption> getAvailableLanguages() {
    return [
      LanguageOption(
        code: 'en',
        name: 'English',
        nativeName: 'English',
        flag: 'EN',
      ),
      LanguageOption(
        code: 'ar',
        name: 'Arabic',
        nativeName: 'العربية',
        flag: 'AR',
      ),
      LanguageOption(
        code: 'tr',
        name: 'Turkish',
        nativeName: 'Türkçe',
        flag: 'TR',
      ),
    ];
  }
}

class LanguageOption {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}
