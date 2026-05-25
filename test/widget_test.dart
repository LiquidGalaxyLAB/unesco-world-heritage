import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unesco_world_heritage/main.dart';

void main() {
  testWidgets('App renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(const HeritageApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
