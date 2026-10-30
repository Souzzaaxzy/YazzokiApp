import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/core/services/app_state.dart';
import 'package:yazzoki/core/utils/profile_navigation.dart';
import 'package:yazzoki/core/widgets/yazzoki_card.dart';
import 'package:yazzoki/core/widgets/user_avatar.dart';
import 'package:yazzoki/features/home/home_screen.dart';
import 'package:yazzoki/features/profile/edit_profile_screen.dart';
import 'package:yazzoki/features/profile/follow_list_sheet.dart';
import 'package:yazzoki/features/profile/profile_screen.dart';
import 'package:yazzoki/models/post.dart';

import '../helpers/fake_repositories.dart';
import '../helpers/test_app.dart';

void main() {
      testWidgets('renders own profile: avatar, nickname, edit button, FAB', (tester) async {
    await pumpYazzokiApp(tester, const ProfileScreen());

    expect(find.text('PERFIL'), findsOneWidget);
    expect(find.textContaining('leonardo', findRichText: true), findsOneWidget);
    expect(find.text('PUBLICAÇÕES'), findsOneWidget);
    expect(find.text('EDITAR PERFIL'), findsOneWidget);
    // Own profile has the floating "+" and no friendship button.
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.text('SEGUIR'), findsNothing);
    expect(find.text('SEGUINDO'), findsNothing);
  });

  testWidgets('other user profile: shows Seguir, no edit, no FAB', (tester) async {
    await pumpYazzokiApp(tester, const ProfileScreen(nickname: 'joao'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('joao', findRichText: true), findsOneWidget);
    expect(find.text('SEGUIR'), findsOneWidget);
    expect(find.text('EDITAR PERFIL'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    // Their posts keep rendering on their profile — with the NEUTRAL
    // counter icon, never a filled heart (a filled heart means "I liked
    // it", which is only true on the detail screen).
    expect(find.byIcon(Icons.favorite_border_rounded), findsWidgets);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });

  testWidgets('tapping Seguir follows instantly and shows Seguindo',
      (tester) async {
    await pumpYazzokiApp(tester, const ProfileScreen(nickname: 'joao'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('SEGUIR'), findsOneWidget);

    await tester.tap(find.text('SEGUIR'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('SEGUINDO'), findsOneWidget);
  });

  testWidgets('tapping Seguindo again unfollows (back to Seguir)',
      (tester) async {
    await pumpYazzokiApp(tester, const ProfileScreen(nickname: 'joao'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('SEGUIR'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SEGUINDO'), findsOneWidget);

    // The same button unfollows — no confirmation dialog.
    await tester.tap(find.text('SEGUINDO'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('SEGUIR'), findsOneWidget);
  });

  testWidgets('shows SEGUIR DE VOLTA when they follow you but you do not',
      (tester) async {
    final repos = FakeRepositories();
    // joao (u2) follows leonardo (u0), but leonardo does not follow back.
    repos.store.follows.add('u2>u0');
    final state = AppState(repositories: repos);
    await state.restoreSession();
    await state.loadFeed();
    await pumpYazzokiApp(tester, const ProfileScreen(nickname: 'joao'),
        state: state);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('SEGUIR DE VOLTA'), findsOneWidget);
  });

  testWidgets('shows current user posts in the grid', (tester) async {
    await pumpYazzokiApp(tester, const ProfileScreen());

    // The mock feed ships at least one post authored by leonardo (p1, p4).
    // The grid shows the neutral like COUNTER, not a liked-state heart.
    expect(find.byIcon(Icons.favorite_border_rounded), findsWidgets);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });

  group('profile counters and follow sheets', () {
    testWidgets('shows the real Amigos/Posts counters from the server',
        (tester) async {
      final repos = FakeRepositories();
      repos.store.follows.add('u0>u2');
    repos.store.follows.add('u2>u0');
      final state = AppState(repositories: repos);
      await pumpYazzokiApp(tester, const ProfileScreen(), state: state);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Seguidores'), findsOneWidget);
      expect(find.text('Seguindo'), findsOneWidget);
      expect(find.text('Curtidas'), findsOneWidget);
      expect(find.text('Posts'), findsOneWidget);
      // Leonardo: 1 follower + 1 following + 1 post all read "1".
      expect(find.text('1'), findsNWidgets(3));
    });

    testWidgets('viewed profile shows THAT user counters, not the session',
        (tester) async {
      await pumpYazzokiApp(tester, const ProfileScreen(nickname: 'joao'));
      await tester.pump(const Duration(milliseconds: 400));

      // The four counters render for the VIEWED user (João), not leonardo.
      expect(find.text('Seguidores'), findsOneWidget);
      expect(find.text('Seguindo'), findsOneWidget);
      expect(find.text('Curtidas'), findsOneWidget);
      expect(find.text('Posts'), findsOneWidget);
    });

    testWidgets(
        'Amigos opens the friends bottom sheet with the real list, and the '
        'item opens that friend profile', (tester) async {
      final repos = FakeRepositories();
      repos.store.follows.add('u0>u2');
    repos.store.follows.add('u2>u0');
      final state = AppState(repositories: repos);
      await pumpYazzokiApp(tester, const ProfileScreen(), state: state);
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Seguidores'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(FollowListSheet), findsOneWidget);
      expect(find.textContaining('SEGUIDORES DE'), findsOneWidget);
      expect(find.text('joao'), findsOneWidget);

      await tester.tap(find.text('joao'));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 800));

      // The followed user's profile opened — the button reflects Following.
      expect(find.text('SEGUINDO'), findsOneWidget);

      // Going back must restore the own profile — never the friend data.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.textContaining('leonardo', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('joao', findRichText: true), findsNothing);
    });
  });

  group('profile navigation bug regression', () {
    testWidgets(
        'search → viewed profile → back → own profile shows the session '
        'user, never the viewed user', (tester) async {
      await pumpYazzokiApp(tester, const HomeScreen());
      await tester.pump(const Duration(milliseconds: 400));

      // Buscar tab, query for another user.
      await tester.tap(find.text('Buscar'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'joao');
      await tester.pump(const Duration(milliseconds: 400));

      // Open the viewed profile (loaded in its own keyed slot).
      await tester.tap(find.ancestor(
        of: find.textContaining('joao', findRichText: true),
        matching: find.byType(YazzokiCard),
      ));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('SEGUIR'), findsOneWidget);

      // Back to the shell, then open the own profile tab.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Perfil'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // The session user's profile renders immediately — no residue of the
      // previously viewed profile, no need for a manual refresh.
      expect(
        find.textContaining('leonardo', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('joao', findRichText: true), findsNothing);
    });
  });

  group('EditProfileScreen', () {
    testWidgets('loads current user data into fields', (tester) async {
      await pumpYazzokiApp(tester, const EditProfileScreen());

      expect(find.text('EDITAR PERFIL'), findsOneWidget);
      // Nickname field is pre-filled with the session nickname.
      expect(find.widgetWithText(TextField, 'leonardo'), findsOneWidget);
    });

    testWidgets('validates required nickname', (tester) async {
      await pumpYazzokiApp(tester, const EditProfileScreen());

      // Clear the nickname field.
      await tester.enterText(find.byType(TextField).at(0), '');

      // The form now also contains the banner section, so the save button can
      // sit below the (short) test viewport — scroll it into view first.
      await tester.ensureVisible(find.text('SALVAR'));
      await tester.tap(find.text('SALVAR'));
      await tester.pump();

      expect(find.text('Nickname obrigatório'), findsOneWidget);
    });

    testWidgets('saves updated profile remotely', (tester) async {
      final state = await seededAppState();
      await pumpYazzokiApp(tester, const EditProfileScreen(), state: state);

      await tester.enterText(find.byType(TextField).at(0), 'Neo');
      await tester.enterText(find.byType(TextField).at(1), 'The one');
      await tester.ensureVisible(find.text('SALVAR'));
      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      expect(state.currentUser!.nickname, 'Neo');
      expect(state.currentUser!.bio, 'The one');
    });

    testWidgets('shows the banner section and the current cover state',
        (tester) async {
      await pumpYazzokiApp(tester, const EditProfileScreen());

      // The new banner control is present…
      expect(find.text('ALTERAR BANNER'), findsOneWidget);
      // …and, with no banner set, it offers the default look (no REMOVER).
      expect(find.text('SEM BANNER'), findsOneWidget);
      expect(find.text('REMOVER'), findsNothing);
    });

    testWidgets('offers REMOVER only when a banner is set', (tester) async {
      final state = await seededAppState();
      await pumpYazzokiApp(tester, const EditProfileScreen(), state: state);

      // Set the banner AFTER pumping: pumpYazzokiApp restores the session,
      // which would overwrite a banner set beforehand.
      await state.updateProfile(bannerUrl: '/static/banner-x.png');
      await tester.pumpAndSettle();
      expect(state.currentUser!.bannerUrl, '/static/banner-x.png');

      expect(find.text('ALTERAR BANNER'), findsOneWidget);
      expect(find.text('REMOVER'), findsOneWidget);
    });
  });

  group('profile grid like state', () {
    testWidgets(
        'grid shows a FILLED heart when the current user liked the post',
        (tester) async {
      // Seed a post authored by joao that leonardo (the session user) liked.
      final repos = FakeRepositories();
      repos.store.posts.add(Post(
        id: 'p9',
        authorId: 'u2',
        authorNickname: 'joao',
        text: 'Post curtido pelo viewer',
        createdAt: DateTime(2024, 1, 5),
        liked: true,
        likes: 1,
      ));
      repos.store.likedPostIds.add('p9');
      final state = AppState(repositories: repos);
      await pumpYazzokiApp(
        tester,
        const ProfileScreen(nickname: 'joao'),
        state: state,
      );
      await tester.pump(const Duration(milliseconds: 400));

      // The heart the viewer liked is filled; the unliked one is empty.
      expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
      expect(find.byIcon(Icons.favorite_border_rounded), findsWidgets);
    });
  });

  group('profile photo long press', () {
    setUp(() => resetProfileTracking());

    testWidgets('long-press on ANOTHER user avatar opens the zoom dialog',
        (tester) async {
      await pumpYazzokiApp(tester, const ProfileScreen(nickname: 'joao'));
      await tester.pump(const Duration(milliseconds: 400));

      // Press and hold ~2s to trigger the zoom, then release.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(UserAvatar).first),
      );
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pumpAndSettle();

      // The enlarged, circular view-only dialog is shown.
      expect(find.byType(ClipOval), findsWidgets);
    });

    testWidgets('long-press on OWN avatar does nothing (no zoom)',
        (tester) async {
      await pumpYazzokiApp(tester, const ProfileScreen());
      await tester.pump(const Duration(milliseconds: 400));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(UserAvatar).first),
      );
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pumpAndSettle();

      // No enlarged photo dialog opens on the own profile.
      expect(find.byType(UserAvatar), findsOneWidget);
      expect(find.byType(ClipOval), findsNothing);
    });

    testWidgets('tapping OUTSIDE the enlarged photo closes the zoom dialog',
        (tester) async {
      await pumpYazzokiApp(tester, const ProfileScreen(nickname: 'joao'));
      await tester.pump(const Duration(milliseconds: 400));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(UserAvatar).first),
      );
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(ClipOval), findsWidgets);

      // Tap the barrier (outside the circle) → closes.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(ClipOval), findsNothing);
    });
  });

  group('existing follow (SEGUINDO)', () {
    // Builds an AppState where leonardo (u0) already FOLLOWS joao (u2), so
    // the profile button renders SEGUINDO. Returns both so tests can inspect
    // the fake server store (server is the source of truth).
    Future<({AppState state, FakeRepositories repos})> followingState() async {
      final repos = FakeRepositories();
      repos.store.follows.add('u0>u2');
      final state = AppState(repositories: repos);
      await state.restoreSession();
      await state.loadFeed();
      return (state: state, repos: repos);
    }

    testWidgets('shows SEGUINDO and unfollows on tap (no dialog)',
        (tester) async {
      final seeded = await followingState();
      await pumpYazzokiApp(
          tester, const ProfileScreen(nickname: 'joao'), state: seeded.state);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('SEGUINDO'), findsOneWidget);

      await tester.tap(find.text('SEGUINDO'));
      await tester.pumpAndSettle();

      // The follow row is gone on the server and the button returns to SEGUIR.
      expect(seeded.repos.store.follows.contains('u0>u2'), isFalse);
      expect(find.text('SEGUIR'), findsOneWidget);
    });
  });

  group('video tiles in the profile grid', () {
    Future<AppState> seededVideoPost({
      String? thumbnailUrl,
      String? videoUrl = 'https://fake.yazzoki.app/v/legacy.mp4',
    }) async {
      final repos = FakeRepositories();
      repos.store.posts = [
        Post(
          id: 'v1',
          authorId: 'u0',
          authorNickname: 'leonardo',
          text: 'meu vídeo',
          createdAt: DateTime(2024, 1, 1),
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl,
          likes: 1,
          liked: false,
          comments: const [],
        ),
      ];
      final state = AppState(repositories: repos);
      await state.restoreSession();
      await state.loadFeed();
      return state;
    }

    testWidgets(
        'old video without cover: shows the video placeholder (never a blank frame)',
        (tester) async {
      final state = await seededVideoPost();
      await pumpYazzokiApp(
          tester, const ProfileScreen(), state: state);
      await tester.pump(const Duration(milliseconds: 400));

      // The tile is clearly identified as a video even without a cover.
      expect(find.text('VÍDEO'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
      // The play affordance stays coherent with the rest of the app.
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('new video with cover: uses the persisted thumbnail',
        (tester) async {
      final state = await seededVideoPost(
        videoUrl: 'https://fake.yazzoki.app/v/new.mp4',
        thumbnailUrl: '/static/capa_v1.jpg',
      );
      await pumpYazzokiApp(
          tester, const ProfileScreen(), state: state);
      await tester.pump(const Duration(milliseconds: 400));

      // The server cover is preferred and the play affordance remains.
      expect(find.byType(CachedNetworkImage), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
    });
  });
}
