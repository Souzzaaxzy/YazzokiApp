import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/core/services/app_state.dart';
import 'package:yazzoki/features/feed/feed_screen.dart';
import 'package:yazzoki/models/post.dart';

import '../helpers/fake_repositories.dart';
import '../helpers/test_app.dart';

/// Repro for "a tela fica indo para cima e para baixo sozinha" on the Home
/// (feed) tab: after scrolling down and back up, the scroll offset must SETTLE
/// — it must not keep moving on its own.
void main() {
  testWidgets('feed scroll settles after down + up (no self-oscillation)',
      (tester) async {
    final repos = FakeRepositories();
    // Enough posts (with media, like the real feed) to actually scroll.
    for (var i = 0; i < 12; i++) {
      repos.store.posts.add(Post(
        id: 'osc$i',
        authorId: 'u2',
        authorNickname: 'joao',
        text: 'post $i',
        createdAt: DateTime(2024, 2, 1).add(Duration(minutes: i)),
        imageUrl: 'https://fake.yazzoki.app/p/osc$i.png',
        likes: i,
      ));
    }
    final state = AppState(repositories: repos);
    await state.restoreSession();
    await state.loadFeed();
    addTearDown(state.dispose);

    await pumpYazzokiApp(tester, const FeedScreen(), state: state);
    await tester.pump(const Duration(milliseconds: 400));

    final scrollable = find.byType(Scrollable).first;
    final position = tester.state<ScrollableState>(scrollable).position;

    // Down…
    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final afterDown = position.pixels;

    // …then UP.
    await tester.drag(scrollable, const Offset(0, 500));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final afterUp = position.pixels;

    // Let it settle with NO further input: the offset must not drift.
    await tester.pump(const Duration(seconds: 1));
    final settled1 = position.pixels;
    await tester.pump(const Duration(seconds: 1));
    final settled2 = position.pixels;

    expect(afterDown, greaterThan(0));
    expect(afterUp, lessThan(afterDown));
    // The killer assertion: nothing moves without the user touching it.
    expect(settled2, settled1,
        reason: 'o scroll continuou se movendo sozinho (oscilação)');
  });
}
