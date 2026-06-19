// Breakpoint selection tests for ResponsiveLayout.
//
// Verifies the three御财 responsive breakpoints (design spec §6):
//   width <= 600  → Mobile
//   600 < width < 1200 → Tablet
//   width >= 1200 → Desktop
// Using MediaQuery-driven breakpoints, tested via MediaQuery test helpers
// (no real window required).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

void main() {
  group('Breakpoint.of', () {
    testWidgets('width=390 → mobile', (tester) async {
      late Breakpoint captured;
      await tester.pumpWidget(_Sized(
        width: 390,
        child: Builder(builder: (ctx) {
          captured = Breakpoints.of(ctx);
          return const SizedBox();
        }),
      ));
      expect(captured, Breakpoint.mobile);
    });

    testWidgets('width=1024 → tablet', (tester) async {
      late Breakpoint captured;
      await tester.pumpWidget(_Sized(
        width: 1024,
        child: Builder(builder: (ctx) {
          captured = Breakpoints.of(ctx);
          return const SizedBox();
        }),
      ));
      expect(captured, Breakpoint.tablet);
    });

    testWidgets('width=1440 → desktop', (tester) async {
      late Breakpoint captured;
      await tester.pumpWidget(_Sized(
        width: 1440,
        child: Builder(builder: (ctx) {
          captured = Breakpoints.of(ctx);
          return const SizedBox();
        }),
      ));
      expect(captured, Breakpoint.desktop);
    });

    testWidgets('boundary width=600 → mobile (inclusive lower bound)',
        (tester) async {
      late Breakpoint captured;
      await tester.pumpWidget(_Sized(
        width: 600,
        child: Builder(builder: (ctx) {
          captured = Breakpoints.of(ctx);
          return const SizedBox();
        }),
      ));
      expect(captured, Breakpoint.mobile);
    });

    testWidgets('boundary width=1200 → desktop (inclusive upper bound)',
        (tester) async {
      late Breakpoint captured;
      await tester.pumpWidget(_Sized(
        width: 1200,
        child: Builder(builder: (ctx) {
          captured = Breakpoints.of(ctx);
          return const SizedBox();
        }),
      ));
      expect(captured, Breakpoint.desktop);
    });

    testWidgets('width=601 → tablet (just above mobile upper bound)',
        (tester) async {
      late Breakpoint captured;
      await tester.pumpWidget(_Sized(
        width: 601,
        child: Builder(builder: (ctx) {
          captured = Breakpoints.of(ctx);
          return const SizedBox();
        }),
      ));
      expect(captured, Breakpoint.tablet);
    });

    testWidgets('width=1199 → tablet (just below desktop lower bound)',
        (tester) async {
      late Breakpoint captured;
      await tester.pumpWidget(_Sized(
        width: 1199,
        child: Builder(builder: (ctx) {
          captured = Breakpoints.of(ctx);
          return const SizedBox();
        }),
      ));
      expect(captured, Breakpoint.tablet);
    });
  });

  group('ResponsiveLayout builder selection', () {
    testWidgets('renders mobile builder at width=390', (tester) async {
      await tester.pumpWidget(_Sized(
        width: 390,
        child: const ResponsiveLayout(
          mobile: Text('M'),
          tablet: Text('T'),
          desktop: Text('D'),
        ),
      ));
      expect(find.text('M'), findsOneWidget);
      expect(find.text('T'), findsNothing);
      expect(find.text('D'), findsNothing);
    });

    testWidgets('renders tablet builder at width=1024', (tester) async {
      await tester.pumpWidget(_Sized(
        width: 1024,
        child: const ResponsiveLayout(
          mobile: Text('M'),
          tablet: Text('T'),
          desktop: Text('D'),
        ),
      ));
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('renders desktop builder at width=1440', (tester) async {
      await tester.pumpWidget(_Sized(
        width: 1440,
        child: const ResponsiveLayout(
          mobile: Text('M'),
          tablet: Text('T'),
          desktop: Text('D'),
        ),
      ));
      expect(find.text('D'), findsOneWidget);
    });
  });
}

/// Wraps [child] in a MediaQuery+Directionality with the given viewport width,
/// so breakpoint logic that reads `MediaQuery.of(context).size.width` sees the
/// intended width without depending on the host test window.
class _Sized extends StatelessWidget {
  const _Sized({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );
  }
}
