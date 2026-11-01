import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/features/chat/media_picker_sheet.dart';
import 'package:yazzoki/features/create_post/create_post_screen.dart';

import '../helpers/test_app.dart';

/// O post abre a GRADE de galeria do app (o mesmo seletor do chat), no modo
/// `single`: uma mídia, sem legenda e sem visualização única — a legenda do
/// post é o campo de texto da própria tela.
///
/// Antes isto usava o seletor NATIVO; agora a tela abre a folha do app, e o
/// teste confirma o MODO com que ela é aberta (é o que muda o comportamento).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('o botão de galeria abre o seletor do app em modo single',
      (tester) async {
    await pumpYazzokiApp(tester, const CreatePostScreen());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('GALERIA'), findsOneWidget);

    await tester.tap(find.textContaining('GALERIA'));
    // Um pump só: o seletor monta e pede a galeria; não esperamos o aparelho.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final sheet = tester.widgetList<MediaPickerSheet>(
      find.byType(MediaPickerSheet),
    );
    expect(sheet, isNotEmpty, reason: 'a folha do app deveria abrir');
    expect(
      sheet.first.mode,
      MediaPickerMode.single,
      reason: 'post escolhe UMA mídia e não tem legenda/visualização única',
    );
  });

  testWidgets('cancelar mantém a tela do post intacta', (tester) async {
    await pumpYazzokiApp(tester, const CreatePostScreen());
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.textContaining('GALERIA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Fecha a folha sem escolher nada.
    Navigator.of(tester.element(find.byType(MediaPickerSheet))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('GALERIA'), findsOneWidget);
    expect(find.text('Remover imagem'), findsNothing);
  });
}
