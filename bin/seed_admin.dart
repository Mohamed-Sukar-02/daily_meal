import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:daily_meal/features/admin/data/admin_security_service.dart';

/// Executable script to seed admin email into Firestore `/admins` collection.
///
/// Usage:
///   dart bin/seed_admin.dart [email]
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  stdout.writeln('Initializing Firebase...');
  try {
    await Firebase.initializeApp();
  } catch (e) {
    stdout.writeln('Firebase initialization notice: $e');
  }

  const defaultEmail = 'mohamedsukar88@gmail.com';
  final targetEmail = args.isNotEmpty ? args.first : defaultEmail;

  stdout.writeln('Seeding admin: $targetEmail into Firestore /admins collection...');
  final securityService = AdminSecurityService(FirebaseFirestore.instance);
  await securityService.seedAdmin(email: targetEmail);

  stdout.writeln('Admin "$targetEmail" successfully seeded into /admins collection.');
}
