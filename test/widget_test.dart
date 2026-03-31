
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stempo/pages/home_page.dart';
import 'package:stempo/ui/theme/app_theme.dart';

void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const HomePage(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> openSearchTab(WidgetTester tester) async {
    await tester.tap(find.text('Search'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('search tab swaps the main content', (tester) async {
    await pumpHome(tester);

    expect(find.text('Daily steps'), findsOneWidget);
    expect(find.text('Browse by use case'), findsNothing);

    await openSearchTab(tester);

    expect(find.text('Match my pace'), findsOneWidget);
    expect(find.text('Browse by use case'), findsOneWidget);
    expect(find.text('Recent searches / Jump back in'), findsOneWidget);
  });

  testWidgets('match my pace turns browse into pace-fit results', (tester) async {
    await pumpHome(tester);
    await openSearchTab(tester);

    await tester.tap(find.text('Match my pace'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Best pace-fit'), findsOneWidget);
    expect(find.text('Night Tempo Walk'), findsWidgets);
  });

  testWidgets('typing a query shows grouped hybrid search results', (tester) async {
    await pumpHome(tester);
    await openSearchTab(tester);

    await tester.enterText(
      find.byKey(const ValueKey('search-field')),
      'night',
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Best pace-fit'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Tracks'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);
  });

  testWidgets('filter sheet exposes the expected controls', (tester) async {
    await pumpHome(tester);
    await openSearchTab(tester);

    await tester.tap(find.byKey(const ValueKey('search-filter-button')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tune your search'), findsOneWidget);
    expect(find.text('Use case'), findsWidgets);
    expect(find.text('Mood'), findsWidgets);
    expect(find.text('Duration'), findsWidgets);
    expect(find.text('Apply filters'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);
  });

  testWidgets('use-case selection moves search into filtered results', (
    tester,
  ) async {
    await pumpHome(tester);
    await openSearchTab(tester);

    await tester.tap(find.text('Focus').first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Use case: Focus'), findsOneWidget);
    expect(find.text('Best pace-fit'), findsOneWidget);
    expect(find.text('Circuit Bloom'), findsWidgets);
  });

  testWidgets('empty state offers recovery paths instead of a blank page', (
    tester,
  ) async {
    await pumpHome(tester);
    await openSearchTab(tester);

    await tester.enterText(
      find.byKey(const ValueKey('search-field')),
      'zzz',
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No close matches yet'), findsOneWidget);
    expect(find.text('Clear filters and search again'), findsOneWidget);
    expect(find.text('Night walk'), findsWidgets);
  });
}
