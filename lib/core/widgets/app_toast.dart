import '../localization/app_strings.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// System-Style Capsule Toasts - unified toast system
/// 
/// Replaces wide SnackBar with floating pill-shaped capsules
/// - Informational: 1.5s auto dismiss
/// - Action/Undo: 4s with action button + countdown
/// - Positioned above bottom navigation, not covering FAB
/// - Supports dark/light mode
/// - Smooth slide + fade animations

enum AppToastType {
  info,
  success,
  warning,
  error,
  action,
}

class AppToast {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;
  static Timer? _countdownTimer;
  static bool _isShowing = false;

  /// Show informational toast - 1.5s
  static void show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(milliseconds: 1500),
    IconData? icon,
  }) {
    _show(
      context,
      message: message,
      type: type,
      duration: duration,
      icon: icon,
    );
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message: message, type: AppToastType.success, icon: Icons.check_rounded);
  }

  static void showError(BuildContext context, String message) {
    show(context, message: message, type: AppToastType.error, duration: const Duration(milliseconds: 2500), icon: Icons.error_outline_rounded);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message: message, type: AppToastType.info);
  }

  /// Show action toast with Undo - 4s + countdown
  static void showUndo(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    String? actionLabel,
    Duration duration = const Duration(seconds: 4),
    AppToastType type = AppToastType.action,
  }) {
    _show(
      context,
      message: message,
      type: type,
      duration: duration,
      // Default label resolved from the active locale instead of a hardcoded
      // literal default parameter.
      actionLabel: actionLabel ?? AppStrings.of(context).undo,
      onAction: onUndo,
      showCountdown: true,
    );
  }

  static void showAction(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      message: message,
      type: AppToastType.action,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      showCountdown: true,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required AppToastType type,
    required Duration duration,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    bool showCountdown = false,
  }) {
    // Hide current toast first
    _hideCurrent();

    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    final brightness = Theme.of(context).brightness;
    
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastOverlay(
        message: message,
        type: type,
        duration: duration,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        showCountdown: showCountdown,
        brightness: brightness,
        onDismiss: () {
          _hideEntry(entry);
        },
      ),
    );

    _currentEntry = entry;
    _isShowing = true;
    overlay.insert(entry);

    // Auto dismiss timer
    _dismissTimer = Timer(duration, () {
      _hideEntry(entry);
    });
  }

  static void _hideCurrent() {
    _dismissTimer?.cancel();
    _countdownTimer?.cancel();
    _dismissTimer = null;
    _countdownTimer = null;
    if (_currentEntry != null) {
      try {
        _currentEntry!.remove();
      } catch (_) {}
      _currentEntry = null;
    }
    _isShowing = false;
  }

  static void _hideEntry(OverlayEntry entry) {
    _dismissTimer?.cancel();
    _countdownTimer?.cancel();
    _dismissTimer = null;
    _countdownTimer = null;
    if (_currentEntry == entry) {
      _currentEntry = null;
    }
    try {
      entry.remove();
    } catch (_) {}
    _isShowing = false;
  }

  /// Hide toast manually
  static void hide() {
    _hideCurrent();
  }
}

class _ToastOverlay extends StatefulWidget {
  final String message;
  final AppToastType type;
  final Duration duration;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showCountdown;
  final Brightness brightness;
  final VoidCallback onDismiss;

  const _ToastOverlay({
    required this.message,
    required this.type,
    required this.duration,
    this.icon,
    this.actionLabel,
    this.onAction,
    required this.showCountdown,
    required this.brightness,
    required this.onDismiss,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  double _progress = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
    );

    _controller.forward();

    if (widget.showCountdown) {
      _remainingSeconds = widget.duration.inSeconds;
      _progress = 1.0;
      // Update countdown every 100ms for smooth progress, but display seconds
      _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final elapsed = timer.tick * 100;
        final total = widget.duration.inMilliseconds;
        final remaining = (total - elapsed).clamp(0, total);
        setState(() {
          _progress = remaining / total;
          _remainingSeconds = (remaining / 1000).ceil();
        });
        if (remaining <= 0) {
          timer.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  void _handleAction() {
    widget.onAction?.call();
    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    // Position above bottom nav (62) + safe area + 16 margin = ~90-110
    final bottomOffset = 90.0 + bottomPadding;

    // Capsule colors - system style
    // Light mode: dark capsule, Dark mode: light capsule for contrast (inverted system toast)
    final Color backgroundColor;
    final Color textColor;
    final Color borderColor;
    final Color actionColor;
    final Color iconColor;

    if (isDark) {
      // Dark mode: light capsule with dark text (system style)
      backgroundColor = const Color(0xFFF2F2F7).withValues(alpha: 0.96);
      textColor = const Color(0xFF1C1C1E);
      borderColor = Colors.white.withValues(alpha: 0.2);
      actionColor = AppPalette.brandGreen;
      iconColor = _iconColorForType(widget.type, isDark: true);
    } else {
      // Light mode: dark capsule with light text
      backgroundColor = const Color(0xFF1C1C1E).withValues(alpha: 0.96);
      textColor = Colors.white;
      borderColor = Colors.white.withValues(alpha: 0.08);
      actionColor = AppPalette.brandGreen;
      iconColor = _iconColorForType(widget.type, isDark: false);
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomOffset,
      child: SafeArea(
        child: Center(
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: widget.showCountdown ? null : _dismiss,
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
                        _dismiss();
                      }
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 420,
                        minWidth: 120,
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.actionLabel != null ? 14 : 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: borderColor, width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.2),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon
                            if (widget.icon != null || _hasDefaultIcon(widget.type)) ...[
                              _buildIcon(iconColor, isDark),
                              const SizedBox(width: 10),
                            ],
                            // Message
                            Flexible(
                              child: Text(
                                widget.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                  color: textColor,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                            // Countdown
                            if (widget.showCountdown) ...[
                              const SizedBox(width: 12),
                              _buildCountdown(textColor, isDark),
                            ],
                            // Action button
                            if (widget.actionLabel != null && widget.onAction != null) ...[
                              const SizedBox(width: 10),
                              _buildActionButton(textColor, actionColor, isDark),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _hasDefaultIcon(AppToastType type) {
    return type == AppToastType.success || type == AppToastType.error || type == AppToastType.warning;
  }

  Widget _buildIcon(Color iconColor, bool isDark) {
    IconData iconData;
    if (widget.icon != null) {
      iconData = widget.icon!;
    } else {
      switch (widget.type) {
        case AppToastType.success:
          iconData = Icons.check_circle_rounded;
          break;
        case AppToastType.error:
          iconData = Icons.error_rounded;
          break;
        case AppToastType.warning:
          iconData = Icons.warning_rounded;
          break;
        case AppToastType.action:
          iconData = Icons.restaurant_rounded;
          break;
        case AppToastType.info:
        default:
          iconData = Icons.info_rounded;
          break;
      }
    }

    // Don't show info icon for plain info to keep minimal
    if (widget.type == AppToastType.info && widget.icon == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: isDark ? 0.15 : 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 16, color: iconColor),
    );
  }

  Widget _buildCountdown(Color textColor, bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Circular progress
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            value: _progress,
            strokeWidth: 2.2,
            backgroundColor: textColor.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.type == AppToastType.error ? const Color(0xFFFF3B30) : AppPalette.brandGreen,
            ),
          ),
        ),
        // Countdown text
        Text(
          '$_remainingSeconds',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(Color textColor, Color actionColor, bool isDark) {
    return Material(
      color: actionColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _handleAction,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            widget.actionLabel!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Color _iconColorForType(AppToastType type, {required bool isDark}) {
    switch (type) {
      case AppToastType.success:
        return AppPalette.brandGreen;
      case AppToastType.error:
        return const Color(0xFFFF3B30);
      case AppToastType.warning:
        return const Color(0xFFFF9500);
      case AppToastType.action:
        return AppPalette.brandGreen;
      case AppToastType.info:
      default:
        return isDark ? const Color(0xFF007AFF) : AppPalette.brandGreen;
    }
  }
}

/// Extension for easy usage via BuildContext
extension AppToastExtension on BuildContext {
  void showToast(String message, {AppToastType type = AppToastType.info}) {
    AppToast.show(this, message: message, type: type);
  }

  void showSuccessToast(String message) {
    AppToast.showSuccess(this, message);
  }

  void showErrorToast(String message) {
    AppToast.showError(this, message);
  }

  void showUndoToast(String message, {required VoidCallback onUndo, String? label}) {
    AppToast.showUndo(this, message: message, onUndo: onUndo, actionLabel: label);
  }
}
