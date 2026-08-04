import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parallel/app/parallel_app.dart';

void main() {
  testWidgets('Desert scene renders', (tester) async {
    await tester.pumpWidget(const ParallelApp());
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
