import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/app/theme/app_colors.dart';
import 'package:yazzoki/app/theme/app_palette.dart';
import 'package:yazzoki/core/services/app_state.dart';
import 'package:yazzoki/core/widgets/glow_container.dart';
import 'package:yazzoki/features/profile/profile_screen.dart';

import '../helpers/fake_repositories.dart';
import '../helpers/test_app.dart';

/// O "+" do PRÓPRIO perfil tem que seguir a cor do tema ativo.
///
/// Ele lê `AppColors.primaryBlue`, um getter ESTÁTICO, e leitura estática não
/// cria dependência de herança. Sem o ThemeWatcher o Scaffold (que cacheia o
/// FAB) mantinha a cor do tema ANTERIOR depois de trocar de tema — por isso o
/// teste TROCA o tema com a tela já montada.
void main() {
  GlowContainer fab(WidgetTester tester) => tester.widget<GlowContainer>(
        find.ancestor(
          of: find.byIcon(Icons.add_rounded),
          matching: find.byType(GlowContainer),
        ),
      );

  testWidgets('o "+" acompanha a troca de tema com a tela aberta',
      (tester) async {
    final state = AppState(repositories: FakeRepositories());
    addTearDown(state.dispose);
    addTearDown(() => AppColors.setActive(themeById('washi').dark));

    // 1) A tela abre no tema Washi.
    AppColors.setActive(themeById('washi').dark);
    await pumpYazzokiApp(tester, const ProfileScreen(), state: state);
    await tester.pump(const Duration(milliseconds: 400));
    expect(fab(tester).background, themeById('washi').dark.accent);

    // 2) O usuário troca para Sakura SEM sair do perfil. O app re-resolve a
    //    paleta e reconstrói a árvore (é o que o app.dart faz).
    AppColors.setActive(themeById('sakura').dark);
    await tester.pumpWidget(
      MaterialApp(home: const SizedBox.shrink()),
    );
    await tester.pump();
    await pumpYazzokiApp(tester, const ProfileScreen(), state: state);
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      fab(tester).background,
      themeById('sakura').dark.accent,
      reason: 'o "+" tem que usar o acento do tema ativo',
    );
    expect(
      fab(tester).background,
      isNot(themeById('washi').dark.accent),
      reason: 'não pode ficar preso no acento do tema anterior',
    );
  });
}
