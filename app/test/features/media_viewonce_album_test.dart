import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/core/widgets/view_once_icon.dart';
import 'package:yazzoki/features/chat/album_bubble.dart';
import 'package:yazzoki/features/chat/chat_media_bubble.dart';
import 'package:yazzoki/models/conversation.dart';

/// As três regras das mídias novas, travadas onde elas são decididas.
void main() {
  ChatMessage msg({
    String type = 'image',
    String? imageUrl,
    String? caption,
    bool viewOnce = false,
    DateTime? viewedAt,
    bool mediaWithheld = false,
    bool mine = false,
    List<AlbumItem>? album,
  }) =>
      ChatMessage(
        id: 'm1',
        conversationId: 'c1',
        senderId: mine ? 'me' : 'other',
        content: '📷 Foto',
        createdAt: DateTime(2026, 1, 1),
        mine: mine,
        type: type,
        imageUrl: imageUrl,
        caption: caption,
        viewOnce: viewOnce,
        viewedAt: viewedAt,
        mediaWithheld: mediaWithheld,
        album: album,
      );

  group('visualização única', () {
    test('consumida quando o servidor retirou a mídia', () {
      final m = msg(viewOnce: true, mediaWithheld: true);
      expect(m.isViewOnceConsumed, isTrue);
    });

    test('consumida quando JÁ abri e não é minha', () {
      final m = msg(viewOnce: true, viewedAt: DateTime(2026, 1, 2));
      expect(m.isViewOnceConsumed, isTrue);
    });

    test('NÃO consumida antes de abrir', () {
      final m = msg(viewOnce: true, imageUrl: '/static/x.png');
      expect(m.isViewOnceConsumed, isFalse);
    });

    test('o REMETENTE nunca vê a própria mídia como consumida', () {
      // Ele mantém a cópia dele mesmo depois de o outro abrir.
      final m = msg(
        viewOnce: true,
        mine: true,
        viewedAt: DateTime(2026, 1, 2),
        imageUrl: '/static/x.png',
      );
      expect(m.isViewOnceConsumed, isFalse);
    });
  });

  group('álbum', () {
    test('duas ou mais mídias formam um álbum', () {
      final m = msg(
        type: 'album',
        album: const [
          AlbumItem(kind: 'image', url: '/a.png'),
          AlbumItem(kind: 'image', url: '/b.png'),
        ],
      );
      expect(m.isAlbum, isTrue);
    });

    test('uma mídia só NÃO é álbum', () {
      expect(msg(imageUrl: '/a.png').isAlbum, isFalse);
    });

    test('item de vídeo mostra a CAPA e marca o tipo', () {
      const v = AlbumItem(
          kind: 'video', url: '/v.mp4', thumbUrl: '/v.jpg');
      expect(v.isVideo, isTrue);
      expect(v.previewUrl, '/v.jpg');
      // Sem capa, cai no próprio arquivo (o player cuida do resto).
      const noCover = AlbumItem(kind: 'video', url: '/v.mp4');
      expect(noCover.previewUrl, '/v.mp4');
    });
  });

  group('renderização', () {
    testWidgets('visualização única selada NÃO mostra a mídia', (tester) async {
      final m = msg(viewOnce: true, imageUrl: '/static/segredo.png');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ChatMediaBubble(message: m)),
      ));
      await tester.pump();
      // Nada de imagem: só o cartão selado com o convite para abrir.
      expect(find.byType(Image), findsNothing);
      expect(find.text('Toque para abrir'), findsOneWidget);
      expect(find.byType(ViewOnceIcon), findsOneWidget);
    });

    testWidgets('visualização única já aberta vira um aviso, não uma imagem',
        (tester) async {
      final m = msg(
        viewOnce: true,
        mediaWithheld: true,
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ChatMediaBubble(message: m)),
      ));
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Visualização única já aberta'), findsOneWidget);
    });

    testWidgets('legenda aparece sob a mídia', (tester) async {
      final m = msg(imageUrl: '/static/x.png', caption: 'olha isso');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ChatMediaBubble(message: m)),
      ));
      await tester.pump();
      expect(find.text('olha isso'), findsOneWidget);
    });

    testWidgets('o álbum monta uma grade com um tile por mídia',
        (tester) async {
      final m = msg(
        type: 'album',
        album: const [
          AlbumItem(kind: 'image', url: '/a.png'),
          AlbumItem(kind: 'image', url: '/b.png'),
          AlbumItem(kind: 'image', url: '/c.png'),
        ],
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AlbumBubble(items: m.album!)),
      ));
      await tester.pump();
      expect(find.byType(AlbumBubble), findsOneWidget);
    });
  });
}
