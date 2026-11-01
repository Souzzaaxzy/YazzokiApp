import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/features/chat/media_picker_sheet.dart';

import '../helpers/fake_gallery_source.dart';

/// A regra de seleção, exercitada na GRADE de verdade (com uma galeria falsa).
///
/// Múltipla (álbum) só no privado/grupo. Em post/story/avatar/banner o toque
/// SUBSTITUI a escolha em vez de acumular — assim nunca existe o beco sem
/// saída de "escolhi uma e não consigo trocar".
void main() {
  Future<void> openWith(
    WidgetTester tester,
    MediaPickerMode mode, {
    int count = 3,
  }) async {
    final assets = [
      for (var i = 0; i < count; i++) fakeAsset(id: 'a$i'),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaPickerSheet(
          mode: mode,
          source: FakeGallerySource(assets: assets),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Toca a célula [i] da grade (as células são os GestureDetector do grid).
  Future<void> tapCell(WidgetTester tester, int i) async {
    final grid = find.byType(GridView);
    final cells = find.descendant(
      of: grid,
      matching: find.byType(GestureDetector),
    );
    await tester.tap(cells.at(i), warnIfMissed: false);
    await tester.pump();
  }

  testWidgets('no CHAT dá para selecionar várias (vira álbum)', (tester) async {
    await openWith(tester, MediaPickerMode.chat);
    await tapCell(tester, 0);
    await tapCell(tester, 1);
    await tapCell(tester, 2);
    // O contador do cabeçalho confirma as três escolhidas.
    expect(find.text('3 selecionadas'), findsOneWidget);
    expect(find.text('ENVIAR 3 MÍDIAS'), findsOneWidget);
  });

  testWidgets('no modo SINGLE a segunda escolha SUBSTITUI a primeira',
      (tester) async {
    await openWith(tester, MediaPickerMode.single);
    await tapCell(tester, 0);
    await tapCell(tester, 1);
    // Continua sendo UMA — nunca acumula, e o botão não vira "ENVIAR 2".
    expect(find.text('ENVIAR 2 MÍDIAS'), findsNothing);
    expect(find.text('USAR ESTA MÍDIA'), findsOneWidget);
  });

  testWidgets('no STORY também é uma só', (tester) async {
    await openWith(tester, MediaPickerMode.story);
    await tapCell(tester, 0);
    await tapCell(tester, 1);
    expect(find.text('ENVIAR 2 MÍDIAS'), findsNothing);
    expect(find.text('PUBLICAR NO STORY'), findsOneWidget);
  });
}
