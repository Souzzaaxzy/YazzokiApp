import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/core/services/theme_controller.dart';
import 'package:yazzoki/core/widgets/theme_pattern_background.dart';
import 'package:yazzoki/data/theme_store.dart';

/// In-memory store: os testes nunca tocam o armazenamento seguro (que trava
/// fora de um aparelho).
class _MemoryStore implements ThemeStore {
  String themeId = '';
  String mode = '';
  bool apply = false;
  bool icons = true;

  @override
  Future<SavedTheme> readAll() async => SavedTheme(
        themeId: themeId,
        mode: YazzokiThemeMode.dark,
        applyToProfile: apply,
        showIcons: icons,
      );

  @override
  Future<void> writeAll({
    required String themeId,
    required YazzokiThemeMode mode,
    required bool applyToProfile,
    required bool showIcons,
  }) async {
    this.themeId = themeId;
    this.mode = mode.name;
    apply = applyToProfile;
    icons = showIcons;
  }
}

/// O fundo de ícones: o tema escolhe QUAL ícone, a opção "Ícones" liga/desliga,
/// e o widget nunca captura toque (é decoração, não interface).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: SizedBox(width: 400, height: 800, child: child)),
      );

  test('cada tema aponta para o SEU arquivo de ícone', () {
    // O asset é derivado do id: um arquivo por tema, sem tabela paralela que
    // possa sair de sincronia com o catálogo.
    expect(themeIconAsset('sakura'), 'assets/icons/theme_sakura.png');
    expect(themeIconAsset('yuki'), 'assets/icons/theme_yuki.png');
  });

  testWidgets('com os ícones DESLIGADOS não monta o painter', (tester) async {
    final controller = ThemeController.debug(_MemoryStore());
    await controller.setShowIcons(false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
        host(ThemePatternBackground(controller: controller)));
    await tester.pump();

    final patterns = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((w) => w.painter.runtimeType.toString().contains('Pattern'));
    expect(patterns, isEmpty,
        reason: 'desligado = só as cores do tema, sem ícones no fundo');
  });

  testWidgets('é decoração: o toque atravessa para o conteúdo', (tester) async {
    var tapped = false;
    final controller = ThemeController.debug(_MemoryStore());
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(
      Stack(
        children: [
          Positioned.fill(
              child: ThemePatternBackground(controller: controller)),
          Positioned.fill(
            child: GestureDetector(
              key: const Key('conteudo'),
              behavior: HitTestBehavior.opaque,
              onTap: () => tapped = true,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    ));

    // Um toque em qualquer ponto cai no conteúdo, nunca no fundo decorativo.
    await tester.tapAt(const Offset(200, 400));
    await tester.pump();
    expect(tapped, isTrue,
        reason: 'o fundo não pode engolir o toque do conteúdo por cima');

    // E o fundo de fato se declara ignorante a toques.
    expect(
      find.ancestor(
        of: find.byType(CustomPaint),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
  });
}
