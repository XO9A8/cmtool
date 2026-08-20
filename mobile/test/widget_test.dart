import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cmtool_mobile/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://ypsrkdefgbghvluuyynm.supabase.co',
      publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlwc3JrZGVmZ2JnaHZsdXV5eW5tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3NjQ4MzEsImV4cCI6MjEwMTM0MDgzMX0.3ojq4TJBGoIM_QwDSzvbJY1VX4LBkpJ3DyDYYcKdLKg',
    );
  });

  testWidgets('App renders auth screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EFootballApp()));
    await tester.pump(const Duration(milliseconds: 100));
    
    // Verify top-level app widget rendered
    expect(find.byType(MaterialApp), findsOneWidget);

    // Cancel pending infinite animations before test tearDown
    await tester.pumpWidget(const SizedBox());
  });
}

