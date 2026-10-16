import 'package:flutter_test/flutter_test.dart';
import 'package:sheride_rider/app.dart';

void main() {
  testWidgets('SheRide Rider App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const SheRideRiderApp());
    expect(find.byType(SheRideRiderApp), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
