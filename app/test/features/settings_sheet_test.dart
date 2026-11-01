import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/app/routes.dart';
import 'package:yazzoki/app/theme/app_theme.dart';
import 'package:yazzoki/core/services/app_state.dart';
import 'package:yazzoki/core/services/theme_controller.dart';
import 'package:yazzoki/core/widgets/app_state_scope.dart';
import 'package:yazzoki/features/auth/login/login_screen.dart';
import 'package:yazzoki/app/theme/app_palette.dart';
import 'package:yazzoki/features/profile/profile_screen.dart';
import 'package:yazzoki/features/themes/themes_screen.dart';

import '../helpers/fake_repositories.dart';

/// Settings bottom sheet (☰) accessible ONLY on the session user's own
/// profile: theme trio, logout with confirmation, and the destructive
/// account delete with nickname re-entry.
Future<void> pumpProfile(
  WidgetTester tester,
  AppState state, {
  String? nickname,
}) async {
  // Restore the session so screens relying on currentUser render content.
  await state.restoreSession();
  await state.loadFeed();
  await tester.pumpWidget(
    AppStateScope(
      state: state,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: ProfileScreen(nickname: nickname),
        onGenerateRoute: buildAppRoute,
      ),
    ),
  );
  // Route render + async profile load.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Finder settingsButton() =>
    find.widgetWithIcon(IconButton, Icons.menu_rounded);

void main() {
  testWidgets('☰ button exists ONLY on the own profile', (tester) async {
    final state = AppState(repositories: FakeRepositories());
    addTearDown(state.dispose);
    await pumpProfile(tester, state);
    expect(settingsButton(), findsOneWidget);

    // Another user's profile -> no settings entry.
    await pumpProfile(tester, state, nickname: 'joao');
    expect(settingsButton(), findsNothing);
  });

  testWidgets('opens the sheet with Temas + logout + delete entries',
      (tester) async {
    final state = AppState(repositories: FakeRepositories());
    addTearDown(state.dispose);
    await pumpProfile(tester, state);

    await tester.tap(settingsButton());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('CONFIGURAÇÕES'), findsOneWidget);
    // O seletor de tema saiu daqui e virou a tela "Temas" (entrada própria).
    expect(find.text('Temas'), findsOneWidget);
    expect(find.text('Escuro'), findsNothing);
    expect(find.text('Claro'), findsNothing);
    // O sistema de personalização foi removido do produto: a entrada não
    // existe mais no menu.
    expect(find.text('Personalizações'), findsNothing);
    expect(find.text('Sair da conta'), findsOneWidget);
    expect(find.text('Excluir conta'), findsOneWidget);

    // Closing the sheet keeps the profile.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('CONFIGURAÇÕES'), findsNothing);
  });

  testWidgets('a entrada "Temas" abre a tela de temas', (tester) async {
    final state = AppState(repositories: FakeRepositories());
    addTearDown(state.dispose);
    final controller = ThemeController.instance;
    addTearDown(() {
      controller.setMode(YazzokiThemeMode.dark);
      controller.setThemeId(kDefaultThemeId);
    });
    await pumpProfile(tester, state);
    await tester.tap(settingsButton());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Temas'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));

    // A tela abre com os três modos e o catálogo de temas.
    expect(find.byType(ThemesScreen), findsOneWidget);
    expect(find.text('MODO'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Escuro'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
    // O catálogo é longo: rola até o tema e até o botão de confirmar.
    await tester.scrollUntilVisible(find.text('Sakura'), 260,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Sakura'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('CONFIRMAR TEMA'), 260,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('CONFIRMAR TEMA'), findsOneWidget);

    // Escolher o brilho aplica na hora (é preferência local). Volta ao topo
    // antes de tocar (a rolagem acima levou os botões para fora da tela).
    await tester.scrollUntilVisible(find.text('MODO'), -260,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Claro'));
    await tester.pump();
    expect(controller.mode, YazzokiThemeMode.light);
  });

  testWidgets('logout asks for confirmation and then lands on login',
      (tester) async {
    final state = AppState(repositories: FakeRepositories());
    addTearDown(state.dispose);
    await pumpProfile(tester, state);
    await tester.tap(settingsButton());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Sair da conta'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sair da conta?'), findsOneWidget);

    // Cancel keeps the session.
    await tester.tap(find.text('Cancelar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.isAuthenticated, isTrue);

    // Confirm logs out and lands on the login screen.
    await tester.tap(find.text('Sair da conta'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Sair'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.isAuthenticated, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('delete requires a strong confirmation + nickname re-entry',
      (tester) async {
    final state = AppState(repositories: FakeRepositories());
    addTearDown(state.dispose);
    await pumpProfile(tester, state);
    await tester.tap(settingsButton());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Excluir conta'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Excluir conta?'), findsOneWidget);
    expect(find.textContaining('permanente'), findsOneWidget);

    // Cancel on the FIRST dialog keeps the account.
    await tester.tap(find.text('Cancelar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.isAuthenticated, isTrue);

    await tester.tap(find.text('Excluir conta'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Excluir minha conta'));
    await tester.pump(const Duration(milliseconds: 300));

    // Second dialog: nickname re-entry. A WRONG nickname can't delete.
    expect(find.text('Digite seu nickname para confirmar'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'outra-pessoa');
    await tester.tap(find.text('Excluir'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.isAuthenticated, isTrue);

    // Correct nickname -> hard delete + back to login.
    await tester.tap(find.text('Excluir conta'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Excluir minha conta'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).last, 'leonardo');
    await tester.tap(find.text('Excluir'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.isAuthenticated, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
