import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_providers.dart';
import '../services/orphan_image_sweeper.dart';

final orphanSweepProvider = FutureProvider<void>((ref) async {
  final db = ref.read(appDatabaseProvider);
  await OrphanImageSweeper.sweepAtStartup(db);
});
