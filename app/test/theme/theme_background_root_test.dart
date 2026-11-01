import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/app/app.dart';
import 'package:yazzoki/app/theme/app_palette.dart';
import 'package:yazzoki/core/services/theme_controller.dart';
import 'package:yazzoki/core/widgets/theme_pattern_background.dart';

/// O fundo do tema (cor + ícones) mora na RAIZ do app, atrás do Navigator.
///
/// Assim TODA rota — aba ou tela empurrada — é transparente sobre o mesmo
/// fundo. Antes ele ficava só no shell do Home, e uma rota EMPURRADA (perfil
/// de outro usuário, editar perfil, post…) ficava transparente sobre o canvas
/// cru: um retângulo preto em vez da cor do tema.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a raiz pinta a cor do tema atrás de qualquer rota',
      (tester) async {
    final controller = ThemeController.instance;
    addTearDown(() {
      controller.setThemeId(kDefaultThemeId);
      controller.setMode(YazzokiThemeMode.dark);
    });

    // Sem `await`: `setThemeId` persiste no armazenamento seguro, que trava
    // fora de um aparelho. O estado em memória já basta para o teste.
    controller.setThemeId('sakura');
    await tester.pumpWidget(const YazzokiApp());
    await tester.pump();

    // A cor base fica ABAIXO do conteúdo, dentro do builder do MaterialApp.
    final root = find.descendant(
      of: find.byType(MaterialApp),
      matching: find.byType(ColoredBox),
    );
    expect(root, findsWidgets,
        reason: 'a raiz precisa pintar a cor do tema atrás do Navigator');
    final colors = tester
        .widgetList<ColoredBox>(root)
        .map((w) => w.color)
        .toList();
    expect(colors, contains(themeById('sakura').dark.scaffold),
        reason: 'a cor base tem que ser a do tema ativo');

    // E o padrão de ícones vive na raiz, não dentro de uma aba.
    expect(
      find.ancestor(
        of: find.byType(ThemePatternBackground),
        matching: find.byType(MaterialApp),
      ),
      findsOneWidget,
    );
  });
}
