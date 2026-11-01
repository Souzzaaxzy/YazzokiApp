import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/data/local/chat_message_codec.dart';
import 'package:yazzoki/models/conversation.dart';

/// O histórico do chat vive no APARELHO (local-first): a mensagem é gravada
/// no SQLite e relida dali. Qualquer campo que o codec não grave some
/// silenciosamente na releitura — foi o que fez a VISUALIZAÇÃO ÚNICA voltar
/// como foto comum e a LEGENDA nunca aparecer.
///
/// Este teste trava o contrato: o que entra no codec tem que voltar igual.
void main() {
  test('ida e volta preserva legenda, visualização única e álbum', () {
    final original = ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      senderId: 'u1',
      content: '🖼️ Álbum (2)',
      createdAt: DateTime(2026, 1, 1, 12),
      mine: true,
      type: 'album',
      caption: 'olha essas fotos',
      viewOnce: true,
      viewedAt: DateTime(2026, 1, 1, 13),
      mediaWithheld: true,
      album: const [
        AlbumItem(kind: 'image', url: '/a.png'),
        AlbumItem(kind: 'video', url: '/v.mp4', thumbUrl: '/v.jpg'),
      ],
    );

    final back = ChatMessageCodec.decode(ChatMessageCodec.encode(original));

    expect(back.caption, 'olha essas fotos');
    expect(back.viewOnce, isTrue);
    expect(back.viewedAt, DateTime(2026, 1, 1, 13));
    expect(back.mediaWithheld, isTrue);
    expect(back.album, hasLength(2));
    expect(back.album![1].kind, 'video');
    expect(back.album![1].thumbUrl, '/v.jpg');
  });

  test('visualização única NÃO some (o bug relatado)', () {
    final m = ChatMessage(
      id: 'm2',
      conversationId: 'c1',
      senderId: 'u1',
      content: '🔒 Foto',
      createdAt: DateTime(2026, 1, 1),
      mine: false,
      type: 'image',
      imageUrl: '/static/segredo.png',
      viewOnce: true,
    );
    final back = ChatMessageCodec.decode(ChatMessageCodec.encode(m));
    expect(back.viewOnce, isTrue,
        reason: 'se isto falhar, a mídia abre como foto comum de novo');
    expect(back.isViewOnceConsumed, isFalse,
        reason: 'ainda não foi aberta, então continua disponível');
  });

  test('mensagem comum continua redonda (nada inventado no caminho)', () {
    final m = ChatMessage(
      id: 'm3',
      conversationId: 'c1',
      senderId: 'u1',
      content: 'oi',
      createdAt: DateTime(2026, 1, 1),
      mine: true,
    );
    final back = ChatMessageCodec.decode(ChatMessageCodec.encode(m));
    expect(back.content, 'oi');
    expect(back.caption, isNull);
    expect(back.viewOnce, isFalse);
    expect(back.album, isNull);
  });
}
