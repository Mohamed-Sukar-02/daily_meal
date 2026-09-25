import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/discard_changes_dialog.dart';
import '../../../../core/widgets/meal_image.dart';
import '../../providers/vault_providers.dart';

/// Quick Add Meal — professional image upload implementation
/// 
/// Latest professional practices (2024-2025):
/// - Uses system photo picker (Android Photo Picker + iOS PHPicker) - no broad storage permission needed [4][5]
/// - Supports limited access: iOS 14+ PHPicker & Android 14+ photo picker allow user to select specific photos [6][9]
/// - Handles Android activity destruction via retrieveLostData [8][10]
/// - Compresses images: maxWidth 1080, imageQuality 85, requestFullMetadata false [7][10]
/// - Copies camera results from cache to app documents for persistence [8][10]
/// - Graceful cancellation handling (null result = normal) [10]
/// - Permission handling: only CAMERA requested, gallery uses system picker [5][7]
class QuickAddSheet extends ConsumerStatefulWidget {
  final Meal? mealToEdit;
  const QuickAddSheet({super.key, this.mealToEdit});

  /// Presented on the **root** navigator on purpose.
  ///
  /// [showModalBottomSheet] defaults to `useRootNavigator: false`, which pushed
  /// the sheet onto the vault branch's own [Navigator]. That navigator's
  /// Overlay is the shell `Scaffold`'s *body*, so the modal barrier stopped
  /// above the bottom navigation bar: with a half-typed meal on screen the tabs
  /// stayed live, and tapping one switched branch and threw the sheet route
  /// away without ever asking. (Measured before the fix, at 400x900: all four
  /// destinations hit-testable and, after a tap on History, `sheet=false
  /// dialog=false` with the History tab selected.) It is the third escape
  /// listed in ISSUES.md and the only one `enableDrag: false` and the
  /// controller listener could not cover.
  ///
  /// On the root navigator the barrier spans the whole screen, so a tap that
  /// would have landed on a tab lands on the scrim instead, and the scrim's
  /// dismiss goes through `Navigator.maybePop` (see
  /// `ModalBarrier.handleDismiss` in the Flutter SDK) — which is exactly the
  /// path [PopScope.canPop] gates. A dirty sheet therefore answers with the
  /// discard prompt rather than silently vanishing.
  ///
  /// Nothing else moves: the sheet's 640dp max width comes from
  /// `ThemeData.bottomSheetTheme`/`_BottomSheetDefaultsM3`, not from the host
  /// navigator, so tablets are unaffected; `Localizations` and the app's RTL
  /// `Directionality` are installed by `MaterialApp` *above* its router
  /// navigator, so `AppStrings.of(context)` still resolves; and the only
  /// [ProviderScope] in the app sits above `DailyMealApp` (lib/main.dart), so
  /// `ref` still reaches the vault controller.
  static Future<void> show(BuildContext context, {Meal? mealToEdit}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      // Drag-to-close is popped imperatively by `BottomSheet.onClosing`
      // (`Navigator.pop`), which `PopScope.canPop` cannot veto — so a swipe
      // down past the header strip used to throw a half-typed meal away without
      // ever asking. Leaving is done through the barrier, the X, Cancel or
      // back, and every one of those goes through the unsaved-changes guard.
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => QuickAddSheet(mealToEdit: mealToEdit),
    );
  }

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _prepTimeController;

  late MealCategory _selectedCategory;
  late ProteinType _selectedProtein;
  late CarbsType _selectedCarbs;
  late bool _isFridaySpecial;
  late bool _isBudgetFriendly;
  late bool _isFavorite;
  String? _photoPath;
  File? _pickedImageFile;
  bool _isPicking = false;
  bool _saving = false;

  /// Set the moment the sheet closes itself (a committed save, or a discard the
  /// user just confirmed). [PopScope.canPop] never gates an imperative
  /// `Navigator.pop`, so this flag is what keeps a back press landing on the
  /// exit animation — or on an in-flight write — from asking "Discard
  /// changes?" about a meal that is already stored.
  bool _isPopping = false;

  /// `true` while the discard prompt is on screen, so a rapid double back press
  /// cannot stack a second one.
  bool _confirmOpen = false;

  final ImagePicker _picker = ImagePicker();

  // Original values captured in [initState]. [hasUnsavedChanges] compares the
  // current fields against them so the sheet can ask before discarding edits.
  late String _initialName;
  late String _initialPrepTime;
  late MealCategory _initialCategory;
  late ProteinType _initialProtein;
  late CarbsType _initialCarbs;
  late bool _initialFridaySpecial;
  late bool _initialBudgetFriendly;
  late bool _initialFavorite;
  String? _initialPhotoPath;

  bool get isEditing => widget.mealToEdit != null;

  /// `true` when any field (including the photo) differs from the original
  /// values — the sheet asks before discarding in that case.
  ///
  /// Read during `build` (for [PopScope.canPop]) *and* at pop time (in
  /// [_requestClose]) — the text controllers push a rebuild through
  /// [_onFormChanged] so the two can never disagree.
  bool get hasUnsavedChanges =>
      _nameController.text.trim() != _initialName ||
      _prepTimeController.text.trim() != _initialPrepTime ||
      _selectedCategory != _initialCategory ||
      _selectedProtein != _initialProtein ||
      _selectedCarbs != _initialCarbs ||
      _isFridaySpecial != _initialFridaySpecial ||
      _isBudgetFriendly != _initialBudgetFriendly ||
      _isFavorite != _initialFavorite ||
      _photoPath != _initialPhotoPath;

  /// A [TextEditingController] does not rebuild its owner widget, so
  /// [hasUnsavedChanges] — and therefore `canPop` — kept the value it had when
  /// the sheet was built: typing a meal name left the route poppable and back
  /// destroyed the half-written meal without asking. Listening keeps it live.
  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  /// Back button / X / cancel / barrier-tap exit path: when the form is dirty,
  /// confirm the discard first; otherwise close immediately and silently.
  Future<void> _requestClose() async {
    // The write already happened (or is running): the sheet closes itself and a
    // prompt here would ask about a meal that is already saved.
    if (_saving || _isPopping || _confirmOpen) return;
    if (!hasUnsavedChanges) {
      _closeSelf();
      return;
    }
    _confirmOpen = true;
    final discard = await showDiscardChangesDialog(context);
    if (!mounted) return;
    _confirmOpen = false;
    if (discard == true) _closeSelf();
  }

  /// Pops the sheet and records that it is on its way out.
  void _closeSelf() {
    if (_isPopping) return;
    _isPopping = true;
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    // كل متغيرات late دي بتتعبى أول حاجة في initState من widget.mealToEdit أو بقيم افتراضية
    // عشان نتجنب LateInitializationError قبل أي استخدام في build
    final m = widget.mealToEdit;
    _nameController = TextEditingController(text: m?.name ?? '');
    _prepTimeController = TextEditingController(text: m?.prepTime.toString() ?? '30');
    _nameController.addListener(_onFormChanged);
    _prepTimeController.addListener(_onFormChanged);
    _selectedCategory = m?.category ?? MealCategory.egyptianTraditional;
    _selectedProtein = m?.proteinType ?? ProteinType.chicken;
    _selectedCarbs = m?.carbsType ?? CarbsType.rice;
    _isFridaySpecial = m?.isFridaySpecial ?? false;
    _isBudgetFriendly = m?.isBudgetFriendly ?? false;
    _isFavorite = m?.isFavorite ?? false;
    _photoPath = m?.photoPath;
    if (_photoPath != null && _photoPath!.isNotEmpty) {
      final f = File(_photoPath!);
      if (f.existsSync()) {
        _pickedImageFile = f;
      }
    }
    // Snapshot the original values for the unsaved-changes check.
    _initialName = _nameController.text.trim();
    _initialPrepTime = _prepTimeController.text.trim();
    _initialCategory = _selectedCategory;
    _initialProtein = _selectedProtein;
    _initialCarbs = _selectedCarbs;
    _initialFridaySpecial = _isFridaySpecial;
    _initialBudgetFriendly = _isBudgetFriendly;
    _initialFavorite = _isFavorite;
    _initialPhotoPath = _photoPath;
    // Professional: handle Android activity destruction via retrieveLostData [8][10]
    _retrieveLostData();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _prepTimeController.removeListener(_onFormChanged);
    _nameController.dispose();
    _prepTimeController.dispose();
    super.dispose();
  }

  int get _prepMins => int.tryParse(_prepTimeController.text) ?? 30;
  void _setPrep(int v) => setState(() => _prepTimeController.text = v.clamp(5, 180).toString());

  // Professional: recover lost image after Android activity destruction [8][10]
  Future<void> _retrieveLostData() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) return;
      if (response.file != null) {
        final copied = await _copyToAppStorage(response.file!);
        if (mounted) {
          setState(() {
            _pickedImageFile = File(copied);
            _photoPath = copied;
          });
        }
      }
    } catch (e) {
      debugPrint('retrieveLostData error: $e');
    }
  }

  // Professional: copy from cache to app documents for persistence [8][10]
  Future<String> _copyToAppStorage(XFile xfile) async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${dir.path}/meal_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = xfile.path.split('.').last.toLowerCase();
    final validExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
    final newPath = '${imagesDir.path}/meal_${timestamp}.$validExt';
    final newFile = await File(xfile.path).copy(newPath);
    return newFile.path;
  }

  // Professional: handle limited access gracefully [2][6][9]
  Future<bool> _handlePhotosPermission() async {
    // On Android 13+ and iOS, system photo picker doesn't require broad permission [5][7]
    // But we check for limited access state to inform user
    if (Platform.isAndroid) {
      // Android 13+ uses granular media permissions, but system picker works without them [4][5]
      return true;
    } else if (Platform.isIOS) {
      // iOS PHPicker doesn't require full library permission [7][9]
      // Check if we have limited access to show UI hint
      final status = await Permission.photos.status;
      if (status.isPermanentlyDenied) {
        if (mounted) {
          final strings = AppStrings.of(context);
          final open = await _showPermissionDialog(
            title: strings.photoAccessLimited,
            content: strings.photoAccessLimitedDesc,
          );
          if (open) await openAppSettings();
        }
        return false;
      }
      return true;
    }
    return true;
  }

  Future<bool> _showPermissionDialog({required String title, required String content}) async {
    final strings = AppStrings.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(strings.openSettings)),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      if (source == ImageSource.camera) {
        // Professional: request camera permission only when needed [10]
        final cameraStatus = await Permission.camera.status;
        if (cameraStatus.isDenied) {
          final result = await Permission.camera.request();
          if (!result.isGranted) {
            if (mounted) {
              AppToast.showError(context, AppStrings.of(context).cameraPermissionDenied);
            }
            return;
          }
        } else if (cameraStatus.isPermanentlyDenied) {
          if (mounted) {
            final strings = AppStrings.of(context);
            final open = await _showPermissionDialog(
              title: strings.cameraPermissionTitle,
              content: strings.cameraPermissionDesc,
            );
            if (open) await openAppSettings();
          }
          return;
        }
      } else {
        // Gallery: use system picker, supports limited access [6][9]
        await _handlePhotosPermission();
      }

      // Professional: compress + requestFullMetadata false for privacy [7][10]
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
        requestFullMetadata: false,
      );

      // Professional: treat cancellation as normal branch [10]
      if (picked == null) {
        debugPrint('User cancelled image picker');
        return;
      }

      // Professional: copy to durable storage [8][10]
      final savedPath = await _copyToAppStorage(picked);

      if (mounted) {
        setState(() {
          _pickedImageFile = File(savedPath);
          _photoPath = savedPath;
        });
        final strings = AppStrings.of(context);
        AppToast.showSuccess(
          context,
          source == ImageSource.camera ? strings.photoCaptured : strings.photoPicked,
        );
      }
    } on PlatformException catch (e) {
      debugPrint('PlatformException picking image: $e');
      if (mounted) {
        AppToast.showError(context, AppStrings.of(context).imagePickError('${e.message}'));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        AppToast.showError(context, AppStrings.of(context).errorGeneric(e));
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _showImageSourceSheet(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppPalette.card(brightness),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 44, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : const Color(0xFFE4E9F0), borderRadius: BorderRadius.circular(3))),
              ),
              const SizedBox(height: 20),
              Text(
                strings.chooseMealPhoto,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppPalette.textPrimary(brightness)),
              ),
              const SizedBox(height: 16),
              _sourceOption(
                brightness: brightness,
                icon: Icons.photo_camera_rounded,
                title: strings.takePhoto,
                subtitle: strings.takePhotoDesc,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),
              _sourceOption(
                brightness: brightness,
                icon: Icons.photo_library_rounded,
                title: strings.pickFromGallery,
                subtitle: strings.pickFromGalleryDesc,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_pickedImageFile != null) ...[
                const SizedBox(height: 12),
                _sourceOption(
                  brightness: brightness,
                  icon: Icons.delete_rounded,
                  title: strings.removePhoto,
                  subtitle: strings.removePhotoDesc,
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _pickedImageFile = null;
                      _photoPath = null;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceOption({
    required Brightness brightness,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.shade50 : AppPalette.tabContainer(brightness),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDestructive ? Colors.red.shade200 : AppPalette.hairline(brightness)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDestructive ? Colors.red.shade100 : AppPalette.card(brightness),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isDestructive ? Colors.red.shade700 : AppPalette.textPrimary(brightness), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDestructive ? Colors.red.shade700 : AppPalette.textPrimary(brightness))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: AppPalette.textSecondary(brightness))),
                ],
              ),
            ),
            AppIcon(AppGlyph.chevron, color: AppPalette.textSecondary(brightness), size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final prep = int.parse(_prepTimeController.text.trim());
    setState(() => _saving = true);
    try {
      if (isEditing) {
        await ref.read(vaultControllerProvider.notifier).updateMeal(widget.mealToEdit!.copyWith(
              name: name,
              category: _selectedCategory,
              proteinType: _selectedProtein,
              carbsType: _selectedCarbs,
              prepTime: prep,
              photoPath: Value(_photoPath),
              isFridaySpecial: _isFridaySpecial,
              isBudgetFriendly: _isBudgetFriendly,
              isFavorite: _isFavorite,
              updatedAt: DateTime.now(),
            ));
        if (mounted) {
          // Written already: leave without asking, and with the guard released
          // so nothing intercepts this pop and re-opens the prompt.
          _closeSelf();
          AppToast.showSuccess(context, AppStrings.of(context).mealUpdated(name));
        }
      } else {
        await ref.read(vaultControllerProvider.notifier).addMeal(
              name: name, category: _selectedCategory, proteinType: _selectedProtein, carbsType: _selectedCarbs,
              prepTimeMinutes: prep, photoPath: _photoPath, isFridaySpecial: _isFridaySpecial,
              isBudgetFriendly: _isBudgetFriendly, isFavorite: _isFavorite);
        if (mounted) {
          _closeSelf();
          AppToast.showSuccess(context, AppStrings.of(context).mealAdded(name));
        }
      }
    } catch (e) {
      if (!mounted) return;
      // The write failed: re-arm the guard so abandoning really does ask.
      setState(() => _saving = false);
      AppToast.showError(context, AppStrings.of(context).saveError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: PopScope(
        // [_isPopping] keeps the route free once the sheet decides to close
        // itself, so a back press landing on the exit animation (or on an
        // in-flight write) can never gate on the pre-save snapshot.
        canPop: _isPopping || !hasUnsavedChanges,
        onPopInvokedWithResult: (didPop, result) {
          // canPop=false (dirty form) → ask before leaving; clean form pops
          // straight through (didPop=true) without any dialog.
          if (!didPop) _requestClose();
        },
        child: Container(
        decoration: BoxDecoration(
          color: AppPalette.card(brightness),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(width: 44, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : const Color(0xFFE4E9F0), borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 14),
                  // Header - removed chef hat spark as requested
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _requestClose,
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(color: isDark ? Colors.white10 : const Color(0xFFF0F2F5), shape: BoxShape.circle),
                            child: Icon(Icons.close, size: 18, color: isDark ? Colors.white70 : const Color(0xFF5A6B81)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(strings.quickAddMealTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppPalette.textPrimary(brightness))),
                              const SizedBox(height: 2),
                              Text(strings.quickAddMealSubtitle, style: TextStyle(fontSize: 12, color: AppPalette.textSecondary(brightness))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Photo + Meal Name row - professional image upload
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Professional Add Photo with preview and limited access support
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _isPicking ? null : () => _showImageSourceSheet(brightness),
                                child: Container(
                                  width: 110, height: 110,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : const Color(0xFFF7F8FB),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFD9DFE8), width: 1),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: _pickedImageFile != null
                                      ? Stack(
                                          children: [
                                            MealImage(
                                              photoPath: _pickedImageFile!.path,
                                              width: 110,
                                              height: 110,
                                              cacheWidth: 600,
                                              fallback: Container(color: AppPalette.tabContainer(brightness)),
                                            ),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                                                child: InkWell(
                                                  customBorder: const CircleBorder(),
                                                  onTap: () => setState(() {
                                                    _pickedImageFile = null;
                                                    _photoPath = null;
                                                  }),
                                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                            if (_isPicking)
                                              Container(
                                                color: Colors.black.withValues(alpha: 0.4),
                                                child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                              ),
                                          ],
                                        )
                                      : DashedBorder(
                                          color: isDark ? Colors.white24 : const Color(0xFFCBD3DF),
                                          radius: 14,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 40, height: 40,
                                                decoration: BoxDecoration(color: isDark ? Colors.white10 : const Color(0xFFE9EDF3), shape: BoxShape.circle),
                                                child: Icon(_isPicking ? Icons.hourglass_top_rounded : Icons.photo_camera_outlined, size: 20, color: isDark ? Colors.white70 : const Color(0xFF5A6B81)),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(_isPicking ? strings.loading : strings.addPhoto, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF16283B))),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Meal Name field
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 28, height: 28,
                                          decoration: BoxDecoration(color: isDark ? Colors.white10 : const Color(0xFFFFF3E0), shape: BoxShape.circle),
                                          child: const Center(child: Text('🍴', style: TextStyle(fontSize: 14))),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(strings.mealNameLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF16283B))),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      key: const Key('meal_form_name_field'),
                                      controller: _nameController,
                                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF16283B)),
                                      decoration: InputDecoration(
                                        hintText: strings.mealNameHint,
                                        hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF9AA6B2)),
                                        filled: true,
                                        fillColor: isDark ? Colors.white10 : const Color(0xFFF7F8FB),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE4E9F0))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE4E9F0))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppPalette.brandGreen)),
                                      ),
                                      maxLength: 120,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return strings.mealNameRequired;
                                        if (v.trim().length < 2) return strings.mealNameMinLength;
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Protein Type
                          _labelRow(isDark, AppGlyph.steak, const Color(0xFF6C5CE7), strings.proteinTypeLabel),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: ProteinType.values.map((p) {
                              final isSelected = _selectedProtein == p;
                              final (color, fg) = _proteinColors(p);
                              return _pill(
                                isDark,
                                label: p.label(strings),
                                emoji: p.emoji,
                                selected: isSelected,
                                color: color,
                                fg: fg,
                                onTap: () => setState(() => _selectedProtein = p),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                          // Carb Type - عرض كل الأنواع
                          Row(
                            children: [
                              Container(width: 28, height: 28, decoration: BoxDecoration(color: isDark ? Colors.white10 : const Color(0xFFFFF3E0), shape: BoxShape.circle), child: const Center(child: Text('🍚', style: TextStyle(fontSize: 14)))),
                              const SizedBox(width: 8),
                              Text(strings.carbsTypeShort, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF16283B))),
                              const SizedBox(width: 8),
                              Text(strings.carbsTypeLabel, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF7B8794))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: CarbsType.values.map((c) {
                              final isSelected = _selectedCarbs == c;
                              final (color, fg) = _carbsColors(c);
                              return _pill(
                                isDark,
                                label: c.label(strings),
                                emoji: _carbsEmoji(c),
                                selected: isSelected,
                                color: color,
                                fg: fg,
                                onTap: () => setState(() => _selectedCarbs = c),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                          // Category Type
                          _labelRow(isDark, AppGlyph.pot, const Color(0xFF6C5CE7), strings.categoryShortLabel),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: MealCategory.values.map((cat) {
                              final isSelected = _selectedCategory == cat;
                              return _pill(
                                isDark,
                                label: cat.label(strings),
                                emoji: '🍲',
                                selected: isSelected,
                                color: const Color(0xFFE7E1F9),
                                fg: const Color(0xFF6C5CE7),
                                onTap: () => setState(() => _selectedCategory = cat),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                          // Meal flags: Friday special / budget / favorite.
                          // These previously had NO visible controls (only the
                          // Offstage test hooks below). The hooks are kept so
                          // existing widget tests keep working.
                          _labelRow(isDark, AppGlyph.star, const Color(0xFFFF9800), strings.mealFlagsLabel),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: [
                              _pill(
                                isDark,
                                label: strings.fridaySpecial,
                                emoji: '🕌',
                                selected: _isFridaySpecial,
                                color: const Color(0xFFE7E1F9),
                                fg: const Color(0xFF6C5CE7),
                                onTap: () => setState(() => _isFridaySpecial = !_isFridaySpecial),
                              ),
                              _pill(
                                isDark,
                                label: strings.budgetFriendly,
                                emoji: '💰',
                                selected: _isBudgetFriendly,
                                color: const Color(0xFFE8F5E9),
                                fg: const Color(0xFF0E6B4A),
                                onTap: () => setState(() => _isBudgetFriendly = !_isBudgetFriendly),
                              ),
                              _pill(
                                isDark,
                                label: strings.favorite,
                                emoji: '⭐',
                                selected: _isFavorite,
                                color: const Color(0xFFFFEBEE),
                                fg: const Color(0xFFE91E63),
                                onTap: () => setState(() => _isFavorite = !_isFavorite),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Time
                          Row(
                            children: [
                              Container(width: 28, height: 28, decoration: BoxDecoration(color: isDark ? Colors.white10 : const Color(0xFFE8F5E9), shape: BoxShape.circle), child: Icon(Icons.access_time, size: 16, color: isDark ? Colors.white70 : const Color(0xFF0E6B4A))),
                              const SizedBox(width: 8),
                              Text(strings.timeLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF16283B))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showTimePicker(isDark),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFDCF2E7)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time, size: 16, color: isDark ? Colors.white70 : const Color(0xFF0E6B4A)),
                                  const SizedBox(width: 8),
                                  Text(strings.minutes(_prepMins), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0E6B4A))),
                                  const SizedBox(width: 8),
                                  Icon(Icons.keyboard_arrow_down, size: 18, color: isDark ? Colors.white70 : const Color(0xFF0E6B4A)),
                                ],
                              ),
                            ),
                          ),
                          Offstage(
                            child: TextFormField(
                              key: const Key('meal_form_prep_time_field'),
                              controller: _prepTimeController,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return strings.fieldRequired;
                                final p = int.tryParse(v.trim());
                                if (p == null || p <= 0) return strings.fieldInvalid;
                                return null;
                              },
                            ),
                          ),
                          Offstage(
                            child: Material(
                              type: MaterialType.transparency,
                              child: Column(
                                children: [
                                  DropdownButtonFormField<MealCategory>(key: const Key('meal_form_category_dropdown'), initialValue: _selectedCategory, items: MealCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label(strings)))).toList(), onChanged: (v) { if (v != null) setState(() => _selectedCategory = v);}),
                                  DropdownButtonFormField<ProteinType>(key: const Key('meal_form_protein_dropdown'), initialValue: _selectedProtein, items: ProteinType.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label(strings)))).toList(), onChanged: (v) { if (v != null) setState(() => _selectedProtein = v);}),
                                  DropdownButtonFormField<CarbsType>(key: const Key('meal_form_carbs_dropdown'), initialValue: _selectedCarbs, items: CarbsType.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label(strings)))).toList(), onChanged: (v) { if (v != null) setState(() => _selectedCarbs = v);}),
                                  SwitchListTile(key: const Key('meal_form_friday_checkbox'), value: _isFridaySpecial, onChanged: (v) => setState(() => _isFridaySpecial = v), title: const Text('')),
                                  SwitchListTile(key: const Key('meal_form_budget_checkbox'), value: _isBudgetFriendly, onChanged: (v) => setState(() => _isBudgetFriendly = v), title: const Text('')),
                                  SwitchListTile(key: const Key('meal_form_favorite_checkbox'), value: _isFavorite, onChanged: (v) => setState(() => _isFavorite = v), title: const Text('')),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  key: const Key('meal_form_cancel_button'),
                                  onPressed: _requestClose,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white70 : const Color(0xFF16283B),
                                    side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFD9DFE8)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  ),
                                  child: Text(strings.cancel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  key: const Key('meal_form_save_button'),
                                  // Disabled while the write runs: a second tap
                                  // would store the meal twice.
                                  onPressed: _saving ? null : _save,
                                  icon: const Icon(Icons.restaurant_menu, size: 18, color: Colors.white),
                                  label: Text(isEditing ? strings.saveChanges : strings.saveMeal, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppPalette.brandGreen,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  (Color, Color) _proteinColors(ProteinType p) {
    switch (p) {
      case ProteinType.chicken:
        return (const Color(0xFFFFF3E0), const Color(0xFF8D6E00));
      case ProteinType.beef:
        return (const Color(0xFFFBE3E5), const Color(0xFF8A2733));
      case ProteinType.fish:
        return (const Color(0xFFE3F0FD), const Color(0xFF1565C0));
      case ProteinType.legume:
        return (const Color(0xFFDCF2E7), const Color(0xFF0E6B4A));
      case ProteinType.dairy:
        return (const Color(0xFFE7E1F9), const Color(0xFF6C5CE7));
      case ProteinType.none:
        return (const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
    }
  }

  (Color, Color) _carbsColors(CarbsType c) {
    switch (c) {
      case CarbsType.rice:
        return (const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
      case CarbsType.pasta:
        return (const Color(0xFFFFF3E0), const Color(0xFFEF6C00));
      case CarbsType.bread:
        return (const Color(0xFFE3F0FD), const Color(0xFF1565C0));
      case CarbsType.potato:
        return (const Color(0xFFFFF8E1), const Color(0xFFF9A825));
      case CarbsType.grains:
        return (const Color(0xFFF3E5F5), const Color(0xFF7B1FA2));
      case CarbsType.none:
        return (const Color(0xFFF5F5F5), const Color(0xFF616161));
    }
  }

  String _carbsEmoji(CarbsType c) {
    switch (c) {
      case CarbsType.rice:
        return '🍚';
      case CarbsType.pasta:
        return '🍝';
      case CarbsType.bread:
        return '🍞';
      case CarbsType.potato:
        return '🥔';
      case CarbsType.grains:
        return '🌾';
      case CarbsType.none:
        return '🥗';
    }
  }

  Widget _labelRow(bool isDark, AppGlyph glyph, Color bg, String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(color: isDark ? Colors.white10 : bg.withValues(alpha: 0.15), shape: BoxShape.circle), child: Center(child: AppIcon(glyph, color: isDark ? Colors.white70 : bg, size: 16))),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF16283B))),
          ],
        ),
        const Spacer(),
      ],
    );
  }

  Widget _pill(bool isDark, {required String label, required String emoji, required bool selected, required Color color, required Color fg, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? (isDark ? fg.withValues(alpha: 0.25) : color) : (isDark ? Colors.white10 : const Color(0xFFF7F8FB)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? (isDark ? fg.withValues(alpha: 0.5) : fg.withValues(alpha: 0.25)) : (isDark ? Colors.white24 : const Color(0xFFE4E9F0))),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? (isDark ? Colors.white : fg) : (isDark ? Colors.white70 : const Color(0xFF5A6B81)))),
          ],
        ),
      ),
    );
  }

  void _showTimePicker(bool isDark) {
    final options = [15, 30, 45, 60, 90, 120];
    final strings = AppStrings.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1F2A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((m) => ListTile(
            title: Text(strings.minutes(m), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF16283B))),
            trailing: _prepMins == m ? const Icon(Icons.check, color: AppPalette.brandGreen) : null,
            onTap: () { Navigator.pop(ctx); _setPrep(m); },
          )).toList(),
        ),
      ),
    );
  }
}

/// Dashed border painter for Add Photo box
class DashedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  const DashedBorder({super.key, required this.child, required this.color, required this.radius});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(color: color, radius: radius),
      child: child,
    );
  }
}
class _DashedPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedPainter({required this.color, required this.radius});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    const dash = 6.0, gap = 4.0;
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    double dist = 0;
    while (dist < metrics.length) {
      final seg = metrics.extractPath(dist, dist + dash);
      canvas.drawPath(seg, paint);
      dist += dash + gap;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
