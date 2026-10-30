import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/core/services/app_state.dart';
import 'package:yazzoki/core/widgets/grid_icon.dart';
import 'package:yazzoki/core/widgets/repost_icon.dart';
import 'package:yazzoki/features/feed/feed_screen.dart';
import 'package:yazzoki/features/profile/profile_screen.dart';

import '../helpers/fake_repositories.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('repost button sits BETWEEN like and comment in the feed',
      (tester) async {
    await pumpYazzokiApp(tester, const FeedScreen());
    await tester.pump(const Duration(milliseconds: 400));

    // The DRAWN repost mark is present (never a Material glyph).
    expect(find.byType(RepostIcon), findsWidgets);

    // Order inside the actions Row: heart → repost → comment.
    final heart = tester.getCenter(find.byIcon(Icons.favorite_border_rounded).first);
    final repost = tester.getCenter(find.byType(RepostIcon).first);
    final comment =
        tester.getCenter(find.byIcon(Icons.chat_bubble_outline_rounded).first);
    expect(repost.dx, greaterThan(heart.dx));
    expect(repost.dx, lessThan(comment.dx));
  });

  testWidgets('tapping repost toggles the state (active ↔ inactive)',
      (tester) async {
    final repos = FakeRepositories();
    final state = AppState(repositories: repos);
    await state.restoreSession();
    await state.loadFeed();
    addTearDown(state.dispose);

    await pumpYazzokiApp(tester, const FeedScreen(), state: state);
    await tester.pump(const Duration(milliseconds: 400));

    final post = state.posts.first;
    expect(post.reposted, isFalse);

    await tester.tap(find.byType(RepostIcon).first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.posts.firstWhere((p) => p.id == post.id).reposted, isTrue);
    expect(repos.store.reposts.contains('u0>${post.id}'), isTrue);

    // Tapping again removes it (the toggle loops).
    await tester.tap(find.byType(RepostIcon).first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.posts.firstWhere((p) => p.id == post.id).reposted, isFalse);
    expect(repos.store.reposts.contains('u0>${post.id}'), isFalse);
  });

  testWidgets('profile shows the Posts/Reposts tabs and the reposts grid',
      (tester) async {
    final repos = FakeRepositories();
    // Seed a repost by the session user (u0) of an existing post.
    final target = repos.store.posts.first;
    repos.store.reposts.add('u0>${target.id}');
    final state = AppState(repositories: repos);
    await state.restoreSession();
    await state.loadFeed();
    addTearDown(state.dispose);

    await pumpYazzokiApp(tester, const ProfileScreen(), state: state);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(GridIcon), findsOneWidget);
    expect(find.byType(RepostIcon), findsOneWidget);

    // Swipe to the Reposts tab (horizontal) and the reposted tile shows.
    await tester.drag(find.byType(TabBarView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    // The reposted post is cached for the profile (the grid renders it).
    expect(state.repostsFor(state.currentUser!.id).length, 1);
    expect(state.repostsFor(state.currentUser!.id).first.id, target.id);
  });
}
