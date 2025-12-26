import 'package:flutter/material.dart';
import 'package:ezlab_frontend/services/language_service.dart';
import 'package:ezlab_frontend/l10n/translations.dart';

class LanguageProvider extends ChangeNotifier {
  static final LanguageProvider _instance = LanguageProvider._internal();

  factory LanguageProvider() {
    return _instance;
  }

  LanguageProvider._internal() {
    _initialize();
  }

  String _currentLanguage = 'en';

  String get currentLanguage => _currentLanguage;

  TextDirection get textDirection => LanguageService.getTextDirection(_currentLanguage);

  Locale get locale => LanguageService.getLocale(_currentLanguage);

  bool get isRTL => LanguageService.isRTL(_currentLanguage);

  void _initialize() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    _currentLanguage = await LanguageService().getLanguage();
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (_currentLanguage != languageCode) {
      _currentLanguage = languageCode;
      await LanguageService().setLanguage(languageCode);
      notifyListeners();
    }
  }

  String getString(String key) {
    return AppTranslations.get(key, _currentLanguage);
  }
}
