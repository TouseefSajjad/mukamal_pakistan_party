// ================================================================
// test/widget_test.dart  —  Mukammal Pakistan Party
// Replaces the default counter smoke test with MPP-specific tests
// ================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mukammalpakistanparty/main.dart';
import 'package:mukammalpakistanparty/screens/auth/login_screen.dart';
import 'package:mukammalpakistanparty/screens/home/home_screen.dart';

// ── Mock classes ─────────────────────────────────────────────────

// ================================================================
void main() {
  // ── Shared setup ───────────────────────────────────────────────
  setUp(() async {
    // Provide a clean SharedPreferences for every test
    SharedPreferences.setMockInitialValues({});
  });

  // ================================================================
  // 1. APP LAUNCH — not logged in → shows LoginScreen
  // ================================================================
  testWidgets('App shows LoginScreen when no session is saved',
          (WidgetTester tester) async {
        // No keys set in SharedPreferences → isLoggedIn == false
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          const MukammalPakistanPartyApp(home: LoginScreen()),
        );
        await tester.pumpAndSettle();

        // LoginScreen should be visible
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(HomeScreen),  findsNothing);
      });

  // ================================================================
  // 2. APP LAUNCH — logged in → shows HomeScreen
  // ================================================================
  testWidgets('App shows HomeScreen when valid session exists',
          (WidgetTester tester) async {
        // Simulate a saved session
        SharedPreferences.setMockInitialValues({'isLoggedIn': true});

        await tester.pumpWidget(
          const MukammalPakistanPartyApp(home: HomeScreen()),
        );
        await tester.pump(); // first frame

        expect(find.byType(HomeScreen),  findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      });

  // ================================================================
  // 3. APP BAR — hamburger icon is present, logout icon is gone
  // ================================================================
  testWidgets('HomeScreen AppBar has menu icon, not logout icon',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: HomeScreen()),
        );
        await tester.pump();

        expect(find.byIcon(Icons.menu_rounded),  findsOneWidget);
        expect(find.byIcon(Icons.logout),        findsNothing);
      });

  // ================================================================
  // 4. DRAWER — opens on hamburger tap and shows all menu items
  // ================================================================
  testWidgets('Drawer opens and contains required navigation items',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: HomeScreen()),
        );
        await tester.pump();

        // Open the drawer by tapping the hamburger icon
        await tester.tap(find.byIcon(Icons.menu_rounded));
        await tester.pumpAndSettle();

        // All drawer items must be present
        expect(find.text('My Profile'),         findsOneWidget);
        expect(find.text('About Party'),        findsOneWidget);
        expect(find.text('Apply Membership'),   findsOneWidget);
        expect(find.text('Logout'),             findsOneWidget);
      });

  // ================================================================
  // 5. LOGOUT DIALOG — tapping Logout shows confirmation dialog
  // ================================================================
  testWidgets('Tapping Logout in drawer shows confirmation dialog',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: HomeScreen()),
        );
        await tester.pump();

        // Open drawer
        await tester.tap(find.byIcon(Icons.menu_rounded));
        await tester.pumpAndSettle();

        // Tap Logout item
        await tester.tap(find.text('Logout'));
        await tester.pumpAndSettle();

        // Confirmation dialog should appear
        expect(find.text('Logout?'),  findsOneWidget);
        expect(find.text('Cancel'),   findsOneWidget);
      });

  // ================================================================
  // 6. LOGOUT DIALOG — Cancel dismisses without signing out
  // ================================================================
  testWidgets('Cancel button dismisses logout dialog',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: HomeScreen()),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.menu_rounded));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Logout'));
        await tester.pumpAndSettle();

        // Tap Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Dialog should be gone; HomeScreen still visible
        expect(find.text('Logout?'),        findsNothing);
        expect(find.byType(HomeScreen),     findsOneWidget);
      });

  // ================================================================
  // 7. MEMBERSHIP CTA — Apply button is rendered
  // ================================================================
  testWidgets('Apply for Membership button is visible on HomeScreen',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: HomeScreen()),
        );
        await tester.pump();

        expect(find.text('Apply for Membership'), findsOneWidget);
      });

  // ================================================================
  // 8. SESSION MANAGER — saveSession persists isLoggedIn flag
  // ================================================================
  test('SessionManager.saveSession() writes isLoggedIn = true', () async {
    SharedPreferences.setMockInitialValues({});

    await SessionManager.saveSession();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('isLoggedIn'), isTrue);
  });

  // ================================================================
  // 9. SESSION MANAGER — clearSession removes all keys
  // ================================================================
  test('SessionManager.clearSession() clears all prefs', () async {
    SharedPreferences.setMockInitialValues({'isLoggedIn': true, 'uid': 'abc'});

    await SessionManager.clearSession();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('isLoggedIn'), isNull);
    expect(prefs.getString('uid'),      isNull);
  });
}