import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/core/services/app_state.dart';
import 'package:yazzoki/core/widgets/profile_views_icon.dart';
import 'package:yazzoki/features/profile/profile_screen.dart';
import 'package:yazzoki/features/profile/profile_views_sheet.dart';

import '../helpers/fake_repositories.dart';
import '../helpers/test_app.dart';

void main() {
  group('visualizações do perfil — botão e privacidade', () {
    testWidgets('o perfil PRÓPRIO mostra o botão de visualizações',
        (tester) async {
      await pumpYazzokiApp(tester, const ProfileScreen());
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ProfileViewsIcon), findsWidgets);
    });

    testWidgets(
        'perfil de OUTRO usuário: sem botão de views + setinha de voltar',
        (tester) async {
      await pumpYazzokiApp(tester, const ProfileScreen(nickname: 'joao'));
      await tester.pump(const Duration(milliseconds: 400));
      // Ninguém vê os visitantes de outro usuário…
      expect(find.byType(ProfileViewsIcon), findsNothing);
      // …e há uma setinha de voltar no canto esquerdo.
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('abre o mini menu com quem entrou e o tempo ("A N")',
        (tester) async {
      final repos = FakeRepositories();
      final me = repos.store.currentUser;
      // Two people visited MY profile.
      repos.store.profileViews.add('u2>${me.id}');
      repos.store.profileViews.add('u3>${me.id}');
      final state = AppState(repositories: repos);
      await state.restoreSession();
      await state.loadFeed();
      addTearDown(state.dispose);

      await pumpYazzokiApp(tester, const ProfileScreen(), state: state);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byType(ProfileViewsIcon).first);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(ProfileViewsSheet), findsOneWidget);
      expect(find.textContaining('QUEM VIU'), findsOneWidget);
      // Both visitors are listed with the visit count + when they came.
      expect(find.textContaining('Visualizou seu perfil'), findsWidgets);
      expect(find.textContaining('Última vez'), findsWidgets);
    });

    testWidgets('o perfil próprio NÃO registra auto-visita',
        (tester) async {
      final repos = FakeRepositories();
      final state = AppState(repositories: repos);
      await state.restoreSession();
      addTearDown(state.dispose);

      final me = state.currentUser!;
      await state.recordProfileView(me.id);
      expect(repos.store.profileViews, isEmpty);
    });
  });

  group('viewedAgo — texto do tempo', () {
    final now = DateTime(2026, 6, 10, 12);

    test('segundos / minutos / horas / dias / semanas / meses / anos', () {
      expect(viewedAgo(now.subtract(const Duration(seconds: 5)), now: now),
          'A poucos segundos');
      expect(viewedAgo(now.subtract(const Duration(minutes: 1)), now: now),
          'A 1 minuto');
      expect(viewedAgo(now.subtract(const Duration(minutes: 7)), now: now),
          'A 7 minutos');
      expect(viewedAgo(now.subtract(const Duration(hours: 1)), now: now),
          'A 1 hora');
      expect(viewedAgo(now.subtract(const Duration(days: 1)), now: now),
          'A 1 dia');
      expect(viewedAgo(now.subtract(const Duration(days: 3)), now: now),
          'A 3 dias');
      expect(viewedAgo(now.subtract(const Duration(days: 14)), now: now),
          'A 2 semanas');
      expect(viewedAgo(now.subtract(const Duration(days: 60)), now: now),
          'A 2 meses');
      expect(viewedAgo(now.subtract(const Duration(days: 400)), now: now),
          'A 1 ano');
    });
  });
}
