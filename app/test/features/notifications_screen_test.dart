import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/features/notifications/notifications_screen.dart';
import 'package:yazzoki/models/yazzoki_notification.dart';

import '../helpers/test_app.dart';

YazzokiNotification _notification({
  required String id,
  required String type,
  String? postId,
  String? commentId,
  bool read = false,
}) {
  return YazzokiNotification(
    id: id,
    type: type,
    read: read,
    createdAt: DateTime(2024, 1, 10, 12),
    actorId: 'u2',
    actorNickname: 'joao',
    postId: postId,
    commentId: commentId,
  );
}

void main() {
  testWidgets('shows the ALL CLEAR empty state without notifications', (tester) async {
    await pumpYazzokiApp(tester, const NotificationsScreen());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('ATIVIDADES'), findsOneWidget);
    expect(find.text('ALL CLEAR'), findsOneWidget);
  });

  testWidgets(
      'follow shows the actor nickname (without "@") and opens the '
      'profile on tap', (tester) async {
    final state = await seededAppStateWithSocial(notifications: [
      _notification(id: 'n9', type: 'FOLLOW', read: false),
    ]);
    await pumpYazzokiApp(tester, const NotificationsScreen(), state: state);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('começou a seguir você.', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('joao', findRichText: true), findsWidgets);

    final message = find.textContaining('começou a seguir você.', findRichText: true);
    await tester.tap(message);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));

    // Opens the follower's profile (respecting currentUser ≠ viewedUser).
    expect(find.text('SEGUIR'), findsOneWidget);
    expect(find.textContaining('joao', findRichText: true), findsWidgets);
  });

  testWidgets('renders like notification with actor, description and unread state', (tester) async {
    final state = await seededAppStateWithSocial(notifications: [
      _notification(id: 'n1', type: 'LIKE', postId: 'p1'),
    ]);
    await pumpYazzokiApp(tester, const NotificationsScreen(), state: state);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('joao', findRichText: true), findsOneWidget);
    expect(find.textContaining('curtiu sua publicação.', findRichText: true), findsOneWidget);
    expect(find.text('há'), findsNothing); // relative time shows "há 2 min"-style
    expect(state.unreadNotifications, 1);
  });

  testWidgets('follow notification renders as a plain tile', (tester) async {
    final state = await seededAppStateWithSocial(
      notifications: [
        _notification(id: 'n2', type: 'FOLLOW'),
      ],
    );
    await pumpYazzokiApp(tester, const NotificationsScreen(), state: state);
    await tester.pump(const Duration(milliseconds: 400));

    // A follow notification is informational — no Aceitar/Recusar buttons.
    expect(find.text('ACEITAR'), findsNothing);
    expect(find.text('RECUSAR'), findsNothing);
    expect(state.unreadNotifications, 1);
  });

  testWidgets('mark-all-read clears the unread counter', (tester) async {
    final state = await seededAppStateWithSocial(notifications: [
      _notification(id: 'n4', type: 'LIKE', postId: 'p1'),
    ]);
    await pumpYazzokiApp(tester, const NotificationsScreen(), state: state);
    await tester.pump(const Duration(milliseconds: 400));

    expect(state.unreadNotifications, 1);

    await tester.tap(find.byIcon(Icons.checklist_rounded));
    await tester.pump(const Duration(milliseconds: 400));

    expect(state.unreadNotifications, 0);
  });

  testWidgets('tapping a comment notification opens the post detail', (tester) async {
    final state = await seededAppStateWithSocial(notifications: [
      _notification(id: 'n5', type: 'COMMENT', postId: 'p1', commentId: 'c1'),
    ]);
    await pumpYazzokiApp(tester, const NotificationsScreen(), state: state);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.textContaining('comentou na sua publicação.', findRichText: true));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));

    // Post detail header.
    expect(find.text('PUBLICAÇÃO'), findsOneWidget);
    // Opening the notification marks it as read.
    expect(state.unreadNotifications, 0);
  });
}
