
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stempo/app/app_router.dart';
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

  Future<void> openLibraryTab(WidgetTester tester) async {
    await tester.tap(find.text('Library'));
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

  testWidgets('library tab shows the new tempo-first page', (tester) async {
    await pumpHome(tester);
    await openLibraryTab(tester);

    expect(find.text('Your Library'), findsOneWidget);
    expect(find.text('Tempo-ready playlists around 108 steps/min'), findsOneWidget);
    expect(find.text('Pinned for your pace'), findsOneWidget);
    expect(find.text('Start session'), findsOneWidget);
  });

  testWidgets('library filters refine the visible playlists', (tester) async {
    await pumpHome(tester);
    await openLibraryTab(tester);

    expect(find.text('Steady Asphalt'), findsWidgets);
    expect(find.text('Recovery Loop'), findsWidgets);

    await tester.tap(find.text('Running'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Steady Asphalt'), findsWidgets);
    expect(find.text('After Hours Tempo'), findsWidgets);
    expect(find.text('Recovery Loop'), findsNothing);
  });

  testWidgets('library cards expose bpm badges and fit labels', (tester) async {
    await pumpHome(tester);
    await openLibraryTab(tester);

    expect(find.text('110 BPM'), findsWidgets);
    expect(find.text('116 BPM'), findsWidgets);
    expect(find.text('Perfect fit'), findsWidgets);
    expect(find.text('Close'), findsWidgets);
  });

  testWidgets('tapping the mini-player opens the now playing page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: AppRouter.router,
      ),
    );
    AppRouter.router.go('/home');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Seremise'));
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('Tempo match'), findsOneWidget);
    expect(find.text('Start synced run'), findsOneWidget);
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
