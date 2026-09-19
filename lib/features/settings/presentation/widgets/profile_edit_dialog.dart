import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/services/avatar_service.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/discard_changes_dialog.dart';
import '../../providers/settings_providers.dart';

/// "Edit Profile" dialog.
///
/// Gender is a **required** field: the save button stays disabled until the
/// user picks one. The avatar grid is filtered by that gender — males only ever
/// see the `MO*`/`MY*` set, females only the `F0*`/`FY*` set — and a matching
/// avatar is auto-selected at random the moment the gender changes, so the
/// profile is never left without a picture.
class ProfileEditDialog extends ConsumerStatefulWidget {
  final AppSettingsData settings;

  const ProfileEditDialog({super.key, required this.settings});

  static Future<void> show(BuildContext context, AppSettingsData settings) {
    return showDialog<void>(
      context: context,
      builder: (_) => ProfileEditDialog(settings: settings),
    );
  }

  @override
  ConsumerState<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends ConsumerState<ProfileEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  /// `null` means "the user has not chosen yet" — a deliberate third state,
  /// distinct from male/female, so the required-field rule can be enforced.
  String? _gender;
  String? _avatar;
  bool _saving = false;

  // Effective initial values captured in [initState]. [hasUnsavedChanges]
  // compares the current fields against them — the avatar snapshot accounts
  // for the auto-correction done when the stored picture mismatches the
  // stored gender (that correction is not a user edit).
  String _initialName = '';
  String _initialEmail = '';
  String? _initialGender;
  String? _initialAvatar;

  /// `true` when any field differs from the original profile data.
  bool get hasUnsavedChanges =>
      _nameController.text.trim() != _initialName ||
      _emailController.text.trim() != _initialEmail ||
      _gender != _initialGender ||
      _avatar != _initialAvatar;

  /// Back button / cancel / barrier-tap exit path: when the form is dirty,
  /// confirm the discard first; otherwise close immediately and silently.
  Future<void> _requestClose() async {
    if (!hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDiscardChangesDialog(context);
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _nameController = TextEditingController(text: settings.userName ?? '');
    _emailController = TextEditingController(text: settings.userEmail ?? '');

    if (UserGender.isValid(settings.userGender)) {
      _gender = settings.userGender;
      // Keep the stored avatar only when it actually belongs to that gender,
      // otherwise fall back to a random one from the correct set.
      _avatar = AvatarService.matchesGender(settings.userAvatar, _gender)
          ? settings.userAvatar
          : AvatarService.randomAvatarForGender(_gender);
    }

    // Snapshot the effective initial state for the unsaved-changes check.
    _initialName = _nameController.text.trim();
    _initialEmail = _emailController.text.trim();
    _initialGender = _gender;
    _initialAvatar = _avatar;

    // Warm the file-system cache so the grid paints instantly.
    Future.microtask(() async {
      try {
        await AvatarService.instance.downloadAvatarsIfNeeded();
      } catch (e) {
        debugPrint('Avatar download on dialog open failed: $e');
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Selecting a gender immediately picks a random avatar from its set, so the
  /// user never ends up with a gender but no picture.
  void _selectGender(String gender) {
    if (_gender == gender) return;
    setState(() {
      _gender = gender;
      _avatar = AvatarService.randomAvatarForGender(gender);
    });
  }

  Future<void> _save() async {
    final strings = AppStrings.of(context);
    final gender = _gender;
    final avatar = _avatar;
    // Guarded in the UI too, but never trust the button state alone.
    if (!UserGender.isValid(gender) || avatar == null) {
      AppToast.showError(context, strings.genderRequired);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(settingsControllerProvider.notifier).updateProfile(
            userName: _nameController.text.trim().isEmpty
                ? strings.defaultUserName
                : _nameController.text.trim(),
            userEmail: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            userGender: gender!,
            userAvatar: avatar,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.showSuccess(context, strings.profileSaved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.showError(context, strings.errorGeneric(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final genderChosen = UserGender.isValid(_gender);
    final avatars = AvatarService.avatarsForGender(_gender);

    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        // canPop=false (dirty form) → ask before leaving; clean form pops
        // straight through (didPop=true) without any dialog.
        if (!didPop) _requestClose();
      },
      child: AlertDialog(
      title: Text(strings.editProfile),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('profile_name_field'),
              controller: _nameController,
              autofillHints: const [AutofillHints.name],
              decoration: InputDecoration(
                labelText: strings.nameField,
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('profile_email_field'),
              controller: _emailController,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: strings.emailField,
                prefixIcon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),

            // --- Gender (required) -----------------------------------------
            Text(
              strings.genderField,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _GenderChip(
                    key: const Key('profile_gender_male'),
                    label: strings.genderMale,
                    icon: Icons.male_rounded,
                    selected: _gender == UserGender.male,
                    brightness: brightness,
                    onTap: () => _selectGender(UserGender.male),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GenderChip(
                    key: const Key('profile_gender_female'),
                    label: strings.genderFemale,
                    icon: Icons.female_rounded,
                    selected: _gender == UserGender.female,
                    brightness: brightness,
                    onTap: () => _selectGender(UserGender.female),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- Avatars filtered by gender --------------------------------
            Text(
              strings.chooseAvatar,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              genderChosen ? strings.avatarsForGenderHint : strings.genderRequired,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: genderChosen
                    ? AppPalette.textSecondary(brightness)
                    : AppPalette.heartCoral,
              ),
            ),
            const SizedBox(height: 12),
            if (avatars.isEmpty)
              Container(
                key: const Key('profile_avatar_empty_hint'),
                height: 56,
                alignment: AlignmentDirectional.center,
                decoration: BoxDecoration(
                  color: AppPalette.tabContainer(brightness),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      AppGlyph.person,
                      color: AppPalette.textSecondary(brightness),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      strings.genderRequired,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppPalette.textSecondary(brightness),
                      ),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final asset in avatars)
                    _AvatarTile(
                      key: Key('profile_avatar_${asset.split('/').last}'),
                      asset: asset,
                      selected: _avatar == asset,
                      brightness: brightness,
                      onTap: () => setState(() => _avatar = asset),
                    ),
                ],
              ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: _saving ? null : _requestClose,
          child: Text(strings.cancel),
        ),
        FilledButton(
          key: const Key('profile_save_button'),
          // Required-field rule: nothing can be saved before a gender is picked.
          onPressed: (genderChosen && _avatar != null && !_saving) ? _save : null,
          child: Text(strings.save),
        ),
      ],
    ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;

  const _GenderChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.brightness,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 46,
        decoration: BoxDecoration(
          color: selected
              ? AppPalette.brandGreen
              : AppPalette.tabContainer(brightness),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppPalette.brandGreen : AppPalette.hairline(brightness),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? Colors.white
                  : AppPalette.textSecondary(brightness),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : AppPalette.textPrimary(brightness),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  final String asset;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;

  const _AvatarTile({
    super.key,
    required this.asset,
    required this.selected,
    required this.brightness,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppPalette.tabContainer(brightness),
          border: Border.all(
            color: selected ? AppPalette.brandGreen : Colors.transparent,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppPalette.brandGreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            width: 56,
            height: 56,
            cacheWidth: 112,
            errorBuilder: (ctx, err, st) {
              debugPrint('Avatar grid load error $asset: $err');
              return Container(
                color: const Color(0xFFF3C64F),
                child: const Center(
                  child: AppIcon(AppGlyph.person, color: Colors.white, size: 24),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
