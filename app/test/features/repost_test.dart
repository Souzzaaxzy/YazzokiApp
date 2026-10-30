import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/core/services/app_state.dart';
import 'package:yazzoki/core/widgets/grid_icon.dart';
import 'package:yazzoki/core/widgets/repost_icon.dart';
import 'package:yazzoki/features/feed/feed_screen.dart';
import 'package:yazzoki/features/feed/post_card.dart';
import 'package:yazzoki/features/feed/reposters_sheet.dart';
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

    // The ACTION button's mark (size 19); the badge above uses size 13.
    final actionIcon = find.byWidgetPredicate(
      (w) => w is RepostIcon && w.size >= 19,
    );
    final post = state.posts.first;
    expect(post.reposted, isFalse);

    // Tap the ACTION button by its semantic label (the badge above also
    // contains a RepostIcon, so find.byType would be ambiguous).
    await tester.tap(actionIcon.first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.posts.firstWhere((p) => p.id == post.id).reposted, isTrue);
    expect(repos.store.reposts.contains('u0>${post.id}'), isTrue);

    // Tapping again removes it (the toggle loops).
    await tester.tap(actionIcon.first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.posts.firstWhere((p) => p.id == post.id).reposted, isFalse);
    expect(repos.store.reposts.contains('u0>${post.id}'), isFalse);
  });

  testWidgets('repost badge appears ABOVE the actions when reposted',
      (tester) async {
    final repos = FakeRepositories();
    final target = repos.store.posts.first;
    // Somebody (u2) reposted the first post → the badge must show.
    repos.store.reposts.add('u2>${target.id}');
    final state = AppState(repositories: repos);
    await state.restoreSession();
    await state.loadFeed();
    addTearDown(state.dispose);

    await pumpYazzokiApp(tester, const FeedScreen(), state: state);
    await tester.pump(const Duration(milliseconds: 400));

    // The badge text names the reposter.
    expect(find.textContaining('repostou'), findsWidgets);

    // …and, inside the SAME post card, it sits ABOVE the action row
    // (smaller y = higher on screen).
    final card = find.byType(PostCard).first;
    final badge = tester.getCenter(
      find.descendant(of: card, matching: find.textContaining('repostou')),
    );
    final action = tester.getCenter(
      find.descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (w) => w is RepostIcon && w.size >= 19,
        ),
      ),
    );
    expect(badge.dy, lessThan(action.dy));
  });

  testWidgets('tapping the badge opens the FULL reposters list', (tester) async {
    final repos = FakeRepositories();
    final target = repos.store.posts.first;
    // Three people reposted the same post (more than the badge shows).
    repos.store.reposts.add('u1>${target.id}');
    repos.store.reposts.add('u2>${target.id}');
    repos.store.reposts.add('u3>${target.id}');
    final state = AppState(repositories: repos);
    await state.restoreSession();
    await state.loadFeed();
    addTearDown(state.dispose);

    await pumpYazzokiApp(tester, const FeedScreen(), state: state);
    await tester.pump(const Duration(milliseconds: 400));

    // Tap the badge chip (it carries the repost text).
    await tester.tap(find.textContaining('repostaram').first);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    // The sheet lists every reposter (u1..u3 have seeded nicknames).
    expect(find.byType(RepostersSheet), findsOneWidget);
    expect(find.textContaining('QUEM REPOSTOU'), findsOneWidget);
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
