import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/features/chat/media_picker_sheet.dart';

/// O seletor é a MESMA grade em todo lugar; o que muda por contexto é quantas
/// mídias cabem e quais recursos de conversa aparecem.
///
/// Regra do produto: seleção MÚLTIPLA (álbum) só no privado/grupo. Post, story,
/// avatar e banner escolhem UMA mídia — e só o chat tem legenda e visualização
/// única.
void main() {
  Widget host(MediaPickerMode mode) => MaterialApp(
        home: Scaffold(body: MediaPickerSheet(mode: mode)),
      );

  Future<void> pumpSheet(WidgetTester tester, MediaPickerMode mode) async {
    await tester.pumpWidget(host(mode));
    await tester.pump();
  }

  group('legenda e visualização única são só do CHAT', () {
    testWidgets('no chat o campo de legenda aparece', (tester) async {
      await pumpSheet(tester, MediaPickerMode.chat);
      expect(find.text('Escreva uma legenda...'), findsOneWidget);
    });

    testWidgets('no story NÃO aparece legenda', (tester) async {
      await pumpSheet(tester, MediaPickerMode.story);
      expect(find.text('Escreva uma legenda...'), findsNothing);
    });

    testWidgets('no modo single (post/avatar/banner) NÃO aparece legenda',
        (tester) async {
      await pumpSheet(tester, MediaPickerMode.single);
      expect(find.text('Escreva uma legenda...'), findsNothing);
    });
  });

  group('o texto do botão confirma o contexto', () {
    testWidgets('chat pede ENVIAR', (tester) async {
      await pumpSheet(tester, MediaPickerMode.chat);
      expect(find.text('ENVIAR'), findsOneWidget);
    });

    testWidgets('story pede PUBLICAR NO STORY', (tester) async {
      await pumpSheet(tester, MediaPickerMode.story);
      expect(find.text('PUBLICAR NO STORY'), findsOneWidget);
    });

    testWidgets('single pede USAR ESTA MÍDIA', (tester) async {
      await pumpSheet(tester, MediaPickerMode.single);
      expect(find.text('USAR ESTA MÍDIA'), findsOneWidget);
    });
  });

  testWidgets('só o chat anuncia o limite de álbum', (tester) async {
    await pumpSheet(tester, MediaPickerMode.chat);
    expect(find.textContaining('Escolha até'), findsOneWidget);
    await pumpSheet(tester, MediaPickerMode.single);
    expect(find.textContaining('Escolha até'), findsNothing);
  });
}
