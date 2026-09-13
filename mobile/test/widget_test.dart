import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_ai/ui/response.dart';

void main() {
  testWidgets('response displays markdown and copyable code', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResponseText('Hello\n\n```dart\nvoid main() {}\n```'),
          ),
        ),
      ),
    );
    expect(find.text('Hello'), findsOneWidget);
    expect(find.byTooltip('Copy code'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy code'));
    await tester.pump();
    expect(tester.takeException(), null);
  });
}
