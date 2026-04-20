import 'package:flutter_test/flutter_test.dart';
import 'package:topsoz/core/utils/transliterator.dart';

void main() {
  group('UzbekTransliterator', () {
    test('Lotin -> Kirill konvertatsiya', () {
      expect(UzbekTransliterator.toCyrillic('kitob'), contains('\u043A'));
      expect(UzbekTransliterator.toCyrillic('shaxar'), contains('\u0448'));
    });

    test('Kirill aniqlash', () {
      expect(UzbekTransliterator.isCyrillic('\u043A\u0438\u0442\u043E\u0431'), true);
      expect(UzbekTransliterator.isCyrillic('kitob'), false);
    });
  });
}
