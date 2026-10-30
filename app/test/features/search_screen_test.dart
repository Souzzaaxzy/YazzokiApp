import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/core/widgets/yazzoki_card.dart';
import 'package:yazzoki/features/search/search_screen.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('shows the search header and hint', (tester) async {
    await pumpYazzokiApp(tester, const SearchScreen());

    expect(find.text('Yazzoki'), findsOneWidget);
    expect(find.text('Pesquisar por nickname ou #id...'), findsOneWidget);
  });

  testWidgets('filters users by nickname', (tester) async {
    await pumpYazzokiApp(tester, const SearchScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Leonardo');
    await tester.pumpAndSettle();

    // Only Leonardo matches — rendered WITHOUT the '@' prefix.
    expect(find.text('leonardo'), findsOneWidget);
  });

  testWidgets('tapping a result opens that user profile', (tester) async {
    await pumpYazzokiApp(tester, const SearchScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'joao');
    await tester.pumpAndSettle();

    // The RichText result (NOT the EditableText query field) is the target.
    final result = find.ancestor(
      of: find.textContaining('joao', findRichText: true),
      matching: find.byType(YazzokiCard),
    );
    expect(result, findsOneWidget);
    await tester.tap(result);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));

    // The profile screen loads with the searched user and the Solicitar button.
    expect(find.text('PERFIL'), findsOneWidget);
    expect(find.text('SOLICITAR'), findsOneWidget);
  });

  testWidgets('shows empty state when no user matches', (tester) async {
    await pumpYazzokiApp(tester, const SearchScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzznopezzz');
    await tester.pumpAndSettle();

    expect(find.text('NO RESULTS'), findsOneWidget);
  });
}
