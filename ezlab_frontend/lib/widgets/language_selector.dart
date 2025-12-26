// lib/widgets/language_selector.dart

import 'package:flutter/material.dart';
import 'package:ezlab_frontend/services/language_service.dart';
import 'package:ezlab_frontend/providers/language_provider.dart';

class LanguageSelector extends StatelessWidget {
  final Function(String)? onLanguageChanged;
  final bool isCompact;

  const LanguageSelector({
    Key? key,
    this.onLanguageChanged,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageProvider = LanguageProvider();
    final languages = LanguageService.getAvailableLanguages();

    if (isCompact) {
      // Compact version for toolbar/header
      return PopupMenuButton<String>(
        onSelected: (String languageCode) async {
          await languageProvider.setLanguage(languageCode);
          onLanguageChanged?.call(languageCode);
        },
        itemBuilder: (BuildContext context) {
          return languages.map((language) {
            return PopupMenuItem<String>(
              value: language.code,
              child: Row(
                children: [
                  Text(language.flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(language.nativeName),
                ],
              ),
            );
          }).toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getLanguageFlag(languageProvider.currentLanguage),
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      );
    }

    // Full version for settings/login page
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getString('language'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: languages.length,
          itemBuilder: (context, index) {
            final language = languages[index];
            final isSelected = languageProvider.currentLanguage == language.code;

            return GestureDetector(
              onTap: () async {
                await languageProvider.setLanguage(language.code);
                onLanguageChanged?.call(language.code);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade100 : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      language.flag,
                      style: const TextStyle(fontSize: 36),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      language.nativeName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: isSelected ? Colors.blue : Colors.grey[700],
                      ),
                    ),
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _getLanguageFlag(String languageCode) {
    switch (languageCode) {
      case 'ar':
        return '🇸🇦';
      case 'tr':
        return '🇹🇷';
      default:
        return '🇺🇸';
    }
  }
}
