import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/app/theme/app_colors.dart';
import 'package:yazzoki/app/theme/app_palette.dart';
import 'package:yazzoki/core/services/app_state.dart';
import 'package:yazzoki/core/services/theme_controller.dart';
import 'package:yazzoki/core/widgets/local_palette.dart';
import 'package:yazzoki/features/profile/profile_screen.dart';

import '../helpers/fake_repositories.dart';
import '../helpers/test_app.dart';

/// Tema de PERFIL publicado: só o CABEÇALHO de outro usuário veste o tema do
/// dono; o resto do app fica no tema de quem olha, e o brilho (claro/escuro)
/// é SEMPRE do espectador.
void main() {
  testWidgets('o perfil de OUTRO usuário usa o tema que ele publicou',
      (tester) async {
    final repos = FakeRepositories();
    // João publicou o tema 'sakura'.
    final joao = repos.store.users['u2']!;
    repos.store.users['u2'] = joao.copyWith(
      profileThemeId: () => 'sakura',
    );
    final state = AppState(repositories: repos);
    addTearDown(state.dispose);

    final controller = ThemeController.instance;
    controller.setThemeId('washi'); // o espectador usa washi
    controller.setMode(YazzokiThemeMode.dark);
    addTearDown(() {
      controller.setThemeId(kDefaultThemeId);
      controller.setMode(YazzokiThemeMode.dark);
    });

    await pumpYazzokiApp(
      tester,
      const ProfileScreen(nickname: 'joao'),
      state: state,
    );
    await tester.pump(const Duration(milliseconds: 500));

    // O cabeçalho é embrulhado no LocalPalette com a paleta do DONO (sakura).
    final local = tester.widgetList<LocalPalette>(find.byType(LocalPalette));
    expect(local, isNotEmpty, reason: 'o cabeçalho deveria estar tematizado');
    expect(local.first.palette, themeById('sakura').dark);

    // O brilho é o do ESPECTADOR (dark), não uma escolha do dono.
    expect(local.first.palette, isNot(themeById('sakura').light));

    // O app por fora continua no tema do espectador.
    expect(AppColors.activePalette, themeById('washi').dark);
  });

  testWidgets('o PRÓPRIO perfil NÃO se auto-tematiza', (tester) async {
    final repos = FakeRepositories();
    final state = AppState(repositories: repos);
    addTearDown(state.dispose);

    await pumpYazzokiApp(tester, const ProfileScreen(), state: state);
    await tester.pump(const Duration(milliseconds: 500));

    // Nenhum LocalPalette: o próprio perfil usa o tema do app.
    expect(find.byType(LocalPalette), findsNothing);
  });

  testWidgets('sem tema publicado, outro perfil usa o tema do espectador',
      (tester) async {
    final repos = FakeRepositories();
    final state = AppState(repositories: repos);
    addTearDown(state.dispose);

    await pumpYazzokiApp(
      tester,
      const ProfileScreen(nickname: 'joao'),
      state: state,
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LocalPalette), findsNothing);
  });
}
