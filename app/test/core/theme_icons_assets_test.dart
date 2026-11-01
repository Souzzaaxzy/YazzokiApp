import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazzoki/app/theme/app_palette.dart';
import 'package:yazzoki/core/widgets/theme_pattern_background.dart';

/// Todo tema do catálogo precisa ter o SEU ícone empacotado.
///
/// É o que trava o par "catálogo ↔ assets": um tema novo sem o PNG (ou um
/// arquivo esquecido no pubspec) falha aqui, e não numa tela vazia em produção.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('o catálogo e os arquivos de ícone andam juntos', () async {
    expect(yazzokiThemes, isNotEmpty);
    for (final theme in yazzokiThemes) {
      final path = themeIconAsset(theme.id);
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0),
          reason: 'ícone vazio para o tema ${theme.id} ($path)');
    }
  });

  test('não há ícone órfão para tema que não existe', () async {
    // O inverso também importa: um PNG de um tema removido só engorda o APK.
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final icons = manifest
        .listAssets()
        .where((a) => a.startsWith('assets/icons/theme_'))
        .toSet();
    final expected = yazzokiThemes
        .map((t) => themeIconAsset(t.id))
        .toSet();
    expect(icons, equals(expected));
  });
}
