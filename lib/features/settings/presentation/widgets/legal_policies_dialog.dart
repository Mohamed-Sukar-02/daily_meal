import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';

class LegalPoliciesDialog extends StatelessWidget {
  final bool isPrivacy;

  const LegalPoliciesDialog({super.key, required this.isPrivacy});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(isPrivacy ? strings.privacyPolicy : strings.termsConditions),
      content: SingleChildScrollView(
        child: Text(
          isPrivacy ? strings.privacyBody : strings.termsBody,
          style: const TextStyle(height: 1.5),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.ok),
        ),
      ],
    );
  }
}
