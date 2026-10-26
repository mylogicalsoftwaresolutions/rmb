import 'package:flutter_test/flutter_test.dart';
import 'package:rmb_connect_app/main.dart';
import 'package:rmb_connect_app/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('RMB Connect app renders login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const RMBConnectApp());

    // The app opens on the splash screen, which hands over to the login screen
    // from a 2 second Future.delayed in its initState. A single pumpWidget is
    // not enough: the login screen is not in the tree yet, so the assertion
    // used to run against a screen that had never been built.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('RMB'), findsWidgets);
    expect(find.text('Member Portal Sign In'), findsOneWidget);
  });
}
