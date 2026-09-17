import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/services/avatar_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_toast.dart';
import '../../settings/providers/settings_providers.dart';

/// Modern two-step Welcome & Onboarding flow for "أكلة النهاردة".
///
/// Step 1: Hero Landing Screen matching the design mockup (spices background,
///         blue pot logo, convex curved white card, and "START NOW" pill button).
/// Step 2: Personal Profile & Kitchen Setup (compact hero header, name, gender,
///         interactive avatar selector matching gender, and optional email).
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  String? _selectedGender;
  String? _selectedAvatar;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onGenderSelected(String gender) {
    setState(() {
      _selectedGender = gender;
      // Auto-assign an initial random avatar for this gender if none chosen
      // or if the previously chosen avatar belonged to the other gender.
      if (_selectedAvatar == null ||
          !AvatarService.matchesGender(_selectedAvatar, gender)) {
        _selectedAvatar = AvatarService.randomAvatarForGender(gender);
      }
    });
  }

  void _goToStep2() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _goToStep1() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _submit() async {
    final strings = AppStrings.of(context);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedGender == null) {
      AppToast.showError(context, strings.welcomeGenderRequired);
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    try {
      await ref.read(settingsControllerProvider.notifier).saveWelcomeData(
            name,
            email.isNotEmpty ? email : null,
            _selectedGender,
            _selectedAvatar,
          );

      if (mounted) {
        if (GoRouter.maybeOf(context) != null) {
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, strings.errorGeneric(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppPalette.background(brightness),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildHeroWelcomePage(brightness),
          _buildProfileSetupPage(brightness),
        ],
      ),
    );
  }

  // ===========================================================================
  // Step 1: Hero Welcome Landing
  // ===========================================================================
  Widget _buildHeroWelcomePage(Brightness brightness) {
    final mediaQuery = MediaQuery.of(context);
    final strings = AppStrings.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final heroHeight = (mediaQuery.size.height * 0.50).clamp(240.0, 480.0);

    return Stack(
      children: [
        // 1. Top Hero Artwork (Dark food background + Pot & Branding)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: heroHeight + 36, // Slight overlap beneath the curved card
          child: Image.asset(
            'assets/welcome_hero.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (ctx, err, st) => Container(
              color: AppPalette.darkBg,
              child: const Center(
                child: Icon(Icons.restaurant_menu_rounded,
                    size: 80, color: AppPalette.brandGreen),
              ),
            ),
          ),
        ),

        // 2. Bottom Convex Curved Card
        Positioned(
          top: heroHeight,
          left: 0,
          right: 0,
          bottom: 0,
          child: ClipPath(
            clipper: const _ConvexTopClipper(curveHeight: 32),
            child: Container(
              color: AppPalette.card(brightness),
              child: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Spacer(),

                                // Title: WELCOME / أهلاً بك
                                Text(
                                  strings.welcomeHeroTitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: AppPalette.textPrimary(brightness),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Description
                                Text(
                                  strings.welcomeHeroDescription,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.55,
                                    fontWeight: FontWeight.w400,
                                    color: AppPalette.textSecondary(brightness),
                                  ),
                                ),

                                const Spacer(),
                                const SizedBox(height: 16),

                                // CTA Button: START NOW / ابدأ الآن
                                _CtaButton(
                                  key: const Key('welcome_start_now_button'),
                                  label: strings.welcomeStartNow,
                                  brightness: brightness,
                                  icon: isRtl
                                      ? Icons.arrow_back_rounded
                                      : Icons.arrow_forward_rounded,
                                  onTap: _goToStep2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Step 2: Profile & Preferences Setup
  // ===========================================================================
  Widget _buildProfileSetupPage(Brightness brightness) {
    final strings = AppStrings.of(context);
    final isSaving = ref.watch(settingsControllerProvider).isLoading;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    const compactHeroHeight = 160.0;
    final genderChosen = UserGender.isValid(_selectedGender);
    final avatars = AvatarService.avatarsForGender(_selectedGender);

    return Stack(
      children: [
        // 1. Compact Hero Backdrop
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: compactHeroHeight + 36,
          child: Image.asset(
            'assets/welcome_hero.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),

        // Top back navigation icon
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: isRtl ? null : 16,
          right: isRtl ? 16 : null,
          child: Material(
            color: Colors.black.withValues(alpha: 0.45),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              key: const Key('welcome_back_button'),
              icon: Icon(
                isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              tooltip: strings.welcomeBack,
              onPressed: _goToStep1,
            ),
          ),
        ),

        // 2. Curved Form Card
        Positioned(
          top: compactHeroHeight,
          left: 0,
          right: 0,
          bottom: 0,
          child: ClipPath(
            clipper: const _ConvexTopClipper(curveHeight: 28),
            child: Container(
              color: AppPalette.card(brightness),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title & Subtitle
                        Text(
                          strings.welcomeProfileTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppPalette.textPrimary(brightness),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          strings.welcomeProfileSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppPalette.textSecondary(brightness),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Name Field (Required)
                        TextFormField(
                          key: const Key('welcome_name_field'),
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: strings.welcomeNameLabel,
                            hintText: strings.welcomeNameHint,
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                            filled: true,
                            fillColor: AppPalette.tabContainer(brightness),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return strings.welcomeNameRequired;
                            }
                            return null;
                          },
                          autofillHints: const [AutofillHints.name],
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 18),

                        // Gender Selector (Required)
                        Text(
                          strings.welcomeGenderLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.textPrimary(brightness),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _GenderCard(
                                key: const Key('welcome_gender_male'),
                                label: strings.genderMale,
                                icon: Icons.male_rounded,
                                selected: _selectedGender == UserGender.male,
                                brightness: brightness,
                                onTap: () => _onGenderSelected(UserGender.male),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _GenderCard(
                                key: const Key('welcome_gender_female'),
                                label: strings.genderFemale,
                                icon: Icons.female_rounded,
                                selected: _selectedGender == UserGender.female,
                                brightness: brightness,
                                onTap: () => _onGenderSelected(UserGender.female),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Interactive Avatar Selection
                        if (genderChosen) ...[
                          Text(
                            strings.welcomeAvatarLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.textPrimary(brightness),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.welcomeChooseAvatarHint,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppPalette.textSecondary(brightness),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 64,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: avatars.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final asset = avatars[index];
                                final isSelected = _selectedAvatar == asset;
                                return _AvatarChoiceTile(
                                  key: Key('welcome_avatar_${asset.split('/').last}'),
                                  asset: asset,
                                  selected: isSelected,
                                  brightness: brightness,
                                  onTap: () {
                                    setState(() => _selectedAvatar = asset);
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // Email Field (Optional)
                        TextFormField(
                          key: const Key('welcome_email_field'),
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: strings.welcomeEmailLabel,
                            hintText: strings.welcomeEmailHint,
                            prefixIcon: const Icon(Icons.email_outlined),
                            filled: true,
                            fillColor: AppPalette.tabContainer(brightness),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) =>
                              FocusScope.of(context).unfocus(),
                        ),
                        const SizedBox(height: 28),

                        // Finish CTA Button: انطلق إلى المطبخ
                        _CtaButton(
                          key: const Key('welcome_submit_button'),
                          label: strings.welcomeFinish,
                          brightness: brightness,
                          isLoading: isSaving,
                          icon: isRtl
                              ? Icons.arrow_back_rounded
                              : Icons.arrow_forward_rounded,
                          onTap: isSaving ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Reusable Subwidgets & Helpers
// =============================================================================

/// Smooth Convex Top Curved Clipper matching the design mockup
class _ConvexTopClipper extends CustomClipper<Path> {
  final double curveHeight;

  const _ConvexTopClipper({this.curveHeight = 32});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, curveHeight);
    path.quadraticBezierTo(size.width / 2, 0, size.width, curveHeight);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _ConvexTopClipper oldClipper) =>
      oldClipper.curveHeight != curveHeight;
}

/// Primary Call-To-Action Pill Button with theme-adaptive brand gradient
class _CtaButton extends StatelessWidget {
  final String label;
  final Brightness brightness;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isLoading;

  const _CtaButton({
    super.key,
    required this.label,
    required this.brightness,
    required this.onTap,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = AppPalette.ctaGradient(brightness);

    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (brightness == Brightness.dark
                    ? AppPalette.brandGreen
                    : AppPalette.brandCoral)
                .withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (icon != null) ...[
                        const SizedBox(width: 8),
                        Icon(icon, color: Colors.white, size: 20),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Selectable Gender Card (Male / Female)
class _GenderCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;

  const _GenderCard({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.brightness,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = brightness == Brightness.dark
        ? AppPalette.brandGreen
        : AppPalette.brandCoral;

    return Material(
      color: selected
          ? activeColor
          : AppPalette.tabContainer(brightness),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? activeColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? Colors.white
                    : AppPalette.textSecondary(brightness),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : AppPalette.textPrimary(brightness),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar Choice Tile in the horizontal list
class _AvatarChoiceTile extends StatelessWidget {
  final String asset;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;

  const _AvatarChoiceTile({
    super.key,
    required this.asset,
    required this.selected,
    required this.brightness,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = brightness == Brightness.dark
        ? AppPalette.brandGreen
        : AppPalette.brandCoral;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppPalette.tabContainer(brightness),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? activeColor : Colors.transparent,
            width: selected ? 3 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipOval(
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            cacheWidth: 120,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.person_rounded, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
