import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom-navigation branch indices, mirroring the branch order declared in
/// `app_router.dart` (`StatefulShellRoute.indexedStack`).
class NavBranch {
  const NavBranch._();

  static const int home = 0;
  static const int vault = 1;
  static const int history = 2;
  static const int settings = 3;
}

/// The bottom-nav branch currently shown to the user.
///
/// `StatefulShellRoute.indexedStack` keeps every branch **alive**, which is what
/// makes the meal vault keep its scroll position — but it also means Home,
/// History and Settings would keep their scroll offsets and expanded panels
/// forever. This provider is the single, explicit signal those screens use to
/// know they were re-entered so they can reset **UI-only** state.
///
/// It carries *no* data: nothing here ever invalidates a database provider, so
/// settings, history entries and vault contents survive untouched and no
/// loading flicker is introduced.
final activeNavBranchProvider = StateProvider<int>((ref) => NavBranch.home);

/// Gives a screen living inside a bottom-nav branch a reliable
/// "the user came back to this tab" callback.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends ConsumerState<MyScreen>
///     with NavBranchReentry {
///   @override
///   int get navBranchIndex => NavBranch.home;
///
///   @override
///   void resetTransientUi() => _scrollController.jumpTo(0);
///
///   @override
///   Widget build(BuildContext context) {
///     watchNavReentry(); // must be the first statement of build
///     ...
///   }
/// }
/// ```
mixin NavBranchReentry<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// The branch this screen belongs to — see [NavBranch].
  int get navBranchIndex;

  /// Reset ephemeral interface state here: scroll offsets, open menus,
  /// expanded panels, local search boxes.
  ///
  /// Do **not** invalidate data providers from here — persisted state must be
  /// preserved (that is the whole point of separating UI state from data).
  void resetTransientUi();

  /// Registers the re-entry listener. Must be called from `build` because
  /// `ref.listen` is only allowed there.
  void watchNavReentry() {
    ref.listen<int>(activeNavBranchProvider, (previous, next) {
      final reentered = next == navBranchIndex && previous != navBranchIndex;
      if (!reentered) return;
      // Defer one frame: the shell has just swapped the visible branch, so let
      // it finish laying out before we move scroll positions around.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) resetTransientUi();
      });
    });
  }

  /// Snaps a scrollable back to its initial offset, tolerating a controller
  /// that is not attached yet (branch never laid out, or empty state shown).
  void resetScroll(ScrollController? controller) {
    if (controller == null || !controller.hasClients) return;
    if (controller.offset == 0) return;
    controller.jumpTo(0);
  }
}
