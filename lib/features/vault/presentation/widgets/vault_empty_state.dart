import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';

/// Empty / no-results states of the vault, restyled onto the design tokens.
class VaultEmptyState extends StatelessWidget {
  final bool isSearchResult;
  final VoidCallback onAction;

  const VaultEmptyState({
    super.key,
    required this.isSearchResult,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSearchResult)
              AppIcon(
                AppGlyph.search,
                size: 64,
                color: AppPalette.textSecondary(brightness),
              )
            else
              Image.asset(
                brightness == Brightness.dark
                    ? 'assets/icons/vault_empty_dark.png'
                    : 'assets/icons/vault_empty_light.png',
                width: 170,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => AppIcon(
                  AppGlyph.pot,
                  size: 64,
                  color: AppPalette.textSecondary(brightness),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              isSearchResult ? strings.vaultNoResultsTitle : strings.vaultEmpty,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearchResult ? strings.vaultNoResultsDesc : strings.vaultEmptyDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppPalette.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: 20),
            if (isSearchResult)
              OutlinedButton.icon(
                key: const Key('vault_clear_filters_button'),
                onPressed: onAction,
                icon: const AppIcon(AppGlyph.close, size: 16, color: AppPalette.brandGreen),
                label: Text(strings.vaultResetFilters),
              )
            else
              FilledButton.icon(
                key: const Key('vault_empty_add_button'),
                onPressed: onAction,
                icon: const AppIcon(AppGlyph.plus, color: Colors.white, size: 18),
                label: Text(strings.addFirstMeal),
              ),
          ],
        ),
      ),
    );
  }
}
