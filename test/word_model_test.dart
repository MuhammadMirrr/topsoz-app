import 'package:flutter_test/flutter_test.dart';
import 'package:topsoz/data/models/word.dart';

void main() {
  group('stripHtml', () {
    test('bo\'sh yoki HTML yo\'q matn o\'zgarmaydi', () {
      expect(stripHtml(''), '');
      expect(stripHtml('simple text'), 'simple text');
      expect(stripHtml('oblast, province'), 'oblast, province');
    });

    test('asosiy teglarni olib tashlaydi', () {
      expect(stripHtml('<i>noun</i>'), 'noun');
      expect(stripHtml('<b>bold</b>'), 'bold');
      expect(stripHtml('<span class="x">text</span>'), 'text');
    });

    test('<br> teglarini yangi qatorga aylantiradi', () {
      expect(stripHtml('line1<br>line2'), 'line1\nline2');
      expect(stripHtml('a<br/>b<br />c'), 'a\nb\nc');
    });

    test('<li> elementlarini • bilan aylantiradi', () {
      final result = stripHtml('<li>item1</li><li>item2</li>');
      expect(result.contains('•'), isTrue);
      expect(result.contains('item1'), isTrue);
      expect(result.contains('item2'), isTrue);
    });

    test('murakkab vuizur formati to\'g\'ri tozalanadi', () {
      final input = '<i>noun</i><br><ol><li>oblast, province</li></ol>';
      final result = stripHtml(input);
      expect(result.contains('<'), isFalse);
      expect(result.contains('>'), isFalse);
      expect(result.contains('noun'), isTrue);
      expect(result.contains('oblast, province'), isTrue);
    });

    test('HTML entitylarini dekod qiladi', () {
      expect(stripHtml('&amp;'), '&');
      expect(stripHtml('&lt;tag&gt;'), '<tag>');
      expect(stripHtml('&quot;text&quot;'), '"text"');
      expect(stripHtml('&#39;hello&#39;'), "'hello'");
      expect(stripHtml('a&nbsp;b'), 'a b');
    });

    test('raqamli entitylarni dekod qiladi', () {
      expect(stripHtml('&#65;'), 'A');
      expect(stripHtml('&#x41;'), 'A');
    });

    test('ko\'p bo\'sh qatorlarni siqadi', () {
      expect(stripHtml('a<br><br><br>b'), 'a\nb');
    });

    test('bosh va oxirgi bo\'shliqni tozalaydi', () {
      expect(stripHtml('  text  '), 'text');
      expect(stripHtml('<p>text</p>'), 'text');
    });

    test('xavfsiz: buzuq HTML ni ham ishlay oladi', () {
      expect(stripHtml('<unclosed tag'), '<unclosed tag');
      expect(stripHtml('text > here'), 'text > here');
    });
  });
}
