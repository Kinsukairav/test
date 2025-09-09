// Basic Flutter widget test for Windows Music Player
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:windows_music_player/main.dart';

void main() {
  testWidgets('Music Player App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MusicPlayerApp()));

    // Verify that the app loads without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Look for key UI elements that should be present
    expect(find.byType(Scaffold), findsOneWidget);
    
    // The app should render without throwing any exceptions
    await tester.pumpAndSettle();
  });

  testWidgets('Music Player has main navigation elements', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MusicPlayerApp()));
    await tester.pumpAndSettle();

    // Look for navigation or main UI elements
    // These tests can be expanded as the UI stabilizes
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
