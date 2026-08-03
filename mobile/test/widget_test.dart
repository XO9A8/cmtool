import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cmtool_mobile/main.dart';

void main() {
  testWidgets('App renders auth screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EFootballApp()));
    await tester.pump(const Duration(milliseconds: 100));
    
    // Verify top-level app widget rendered
    expect(find.byType(MaterialApp), findsOneWidget);

    // Cancel pending infinite animations before test tearDown
    await tester.pumpWidget(const SizedBox());
  });
}
