import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/features/feed/responsive_post_image.dart';

/// O feed "pulava" ao voltar para o topo por causa da proporção da imagem.
///
/// O item que sai da tela é DESTRUÍDO e o que volta é construído do zero. Se o
/// widget novo não consultar a proporção já aprendida, ele nasce na proporção
/// do placeholder (4:3) e só assume a real um frame depois — o conteúdo empurra
/// e a lista treme. O teste mede a ALTURA renderizada, que é o que o usuário vê.
void main() {
  setUp(() => ResponsivePostImage.knownRatios.clear());
  tearDown(() => ResponsivePostImage.knownRatios.clear());

  var seq = 0;

  /// Monta o widget do ZERO (chave nova a cada vez) e devolve a altura
  /// renderizada. A chave é o que garante um State novo, como acontece quando
  /// a lista descarta e reconstrói o item.
  Future<double> freshHeight(WidgetTester tester, String url) async {
    seq++;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ResponsivePostImage(key: ValueKey(seq), imageUrl: url),
      ),
    ));
    await tester.pump();
    return tester.getSize(find.byType(ResponsivePostImage)).height;
  }

  testWidgets('a proporção já aprendida é usada JÁ na primeira montagem',
      (tester) async {
    const url = 'https://fake.yazzoki.app/p/foto.png';

    // Nada aprendido ainda: cai no placeholder 4:3.
    final placeholderHeight = await freshHeight(tester, url);
    expect(ResponsivePostImage.knownRatios[url], isNull);

    // A imagem decodificou e a proporção real (2:1, mais baixa que 4:3) é
    // conhecida. Agora o item é reconstruído do zero, como faz a lista.
    ResponsivePostImage.knownRatios[url] = 2.0;
    final knownHeight = await freshHeight(tester, url);

    expect(knownHeight, lessThan(placeholderHeight),
        reason: 'o widget reconstruído ignorou a proporção aprendida e voltou '
            'com a altura do placeholder — é isso que faz o feed pular');
  });

  testWidgets('urls diferentes não compartilham proporção', (tester) async {
    ResponsivePostImage.knownRatios['https://fake.yazzoki.app/a.png'] = 1.5;
    expect(ResponsivePostImage.knownRatios['https://fake.yazzoki.app/b.png'],
        isNull);
  });
}
