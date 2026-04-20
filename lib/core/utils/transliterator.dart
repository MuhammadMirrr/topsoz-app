/// O'zbek tili uchun Lotin <-> Kirill transliteratsiya.
class UzbekTransliterator {
  UzbekTransliterator._();

  /// Undosh harflar (kontekstga qarab "e" ni to'g'ri aylantirish uchun)
  static const _consonants = <String>{
    'b', 'B', 'd', 'D', 'f', 'F', 'g', 'G', 'h', 'H',
    'j', 'J', 'k', 'K', 'l', 'L', 'm', 'M', 'n', 'N',
    'p', 'P', 'q', 'Q', 'r', 'R', 's', 'S', 't', 'T',
    'v', 'V', 'x', 'X', 'y', 'Y', 'z', 'Z',
  };

  static const _latinToCyrillic = [
    // Digraflar birinchi
    ('SH', '\u0428'), ('Sh', '\u0428'), ('sh', '\u0448'),
    ('CH', '\u0427'), ('Ch', '\u0427'), ('ch', '\u0447'),
    ('NG', '\u041D\u0413'), ('Ng', '\u041D\u0433'), ('ng', '\u043D\u0433'),
    ("O'", '\u040E'), ("o'", '\u045E'), ('O\u02BB', '\u040E'), ('o\u02BB', '\u045E'),
    ('O`', '\u040E'), ('o`', '\u045E'),
    ("G'", '\u0492'), ("g'", '\u0493'), ('G\u02BB', '\u0492'), ('g\u02BB', '\u0493'),
    ('G`', '\u0492'), ('g`', '\u0493'),
    ('YO', '\u0401'), ('Yo', '\u0401'), ('yo', '\u0451'),
    ('YU', '\u042E'), ('Yu', '\u042E'), ('yu', '\u044E'),
    ('YA', '\u042F'), ('Ya', '\u042F'), ('ya', '\u044F'),
    ('YE', '\u0415'), ('Ye', '\u0415'), ('ye', '\u0435'),
    ('TS', '\u0426'), ('Ts', '\u0426'), ('ts', '\u0446'),
    // Yakka harflar (E/e alohida — kontekstga qarab boshqariladi)
    ('A', '\u0410'), ('a', '\u0430'),
    ('B', '\u0411'), ('b', '\u0431'),
    ('D', '\u0414'), ('d', '\u0434'),
    ('F', '\u0424'), ('f', '\u0444'),
    ('G', '\u0413'), ('g', '\u0433'),
    ('H', '\u04B2'), ('h', '\u04B3'),
    ('I', '\u0418'), ('i', '\u0438'),
    ('J', '\u0416'), ('j', '\u0436'),
    ('K', '\u041A'), ('k', '\u043A'),
    ('L', '\u041B'), ('l', '\u043B'),
    ('M', '\u041C'), ('m', '\u043C'),
    ('N', '\u041D'), ('n', '\u043D'),
    ('O', '\u041E'), ('o', '\u043E'),
    ('P', '\u041F'), ('p', '\u043F'),
    ('Q', '\u049A'), ('q', '\u049B'),
    ('R', '\u0420'), ('r', '\u0440'),
    ('S', '\u0421'), ('s', '\u0441'),
    ('T', '\u0422'), ('t', '\u0442'),
    ('U', '\u0423'), ('u', '\u0443'),
    ('V', '\u0412'), ('v', '\u0432'),
    ('X', '\u0425'), ('x', '\u0445'),
    ('Y', '\u0419'), ('y', '\u0439'),
    ('Z', '\u0417'), ('z', '\u0437'),
    ("'", '\u044A'), ('`', '\u044A'), ('\u02BC', '\u044A'),
  ];

  static const _cyrillicToLatin = [
    ('\u0448', 'sh'), ('\u0428', 'Sh'),
    ('\u0447', 'ch'), ('\u0427', 'Ch'),
    ('\u045E', "o'"), ('\u040E', "O'"),
    ('\u0493', "g'"), ('\u0492', "G'"),
    ('\u0451', 'yo'), ('\u0401', 'Yo'),
    ('\u044E', 'yu'), ('\u042E', 'Yu'),
    ('\u044F', 'ya'), ('\u042F', 'Ya'),
    ('\u0446', 'ts'), ('\u0426', 'Ts'),
    ('\u04B3', 'h'), ('\u04B2', 'H'),
    ('\u049B', 'q'), ('\u049A', 'Q'),
    ('\u044D', 'e'), ('\u042D', 'E'),
    ('\u0430', 'a'), ('\u0410', 'A'),
    ('\u0431', 'b'), ('\u0411', 'B'),
    ('\u0432', 'v'), ('\u0412', 'V'),
    ('\u0433', 'g'), ('\u0413', 'G'),
    ('\u0434', 'd'), ('\u0414', 'D'),
    ('\u0435', 'e'), ('\u0415', 'E'),
    ('\u0436', 'j'), ('\u0416', 'J'),
    ('\u0437', 'z'), ('\u0417', 'Z'),
    ('\u0438', 'i'), ('\u0418', 'I'),
    ('\u0439', 'y'), ('\u0419', 'Y'),
    ('\u043A', 'k'), ('\u041A', 'K'),
    ('\u043B', 'l'), ('\u041B', 'L'),
    ('\u043C', 'm'), ('\u041C', 'M'),
    ('\u043D', 'n'), ('\u041D', 'N'),
    ('\u043E', 'o'), ('\u041E', 'O'),
    ('\u043F', 'p'), ('\u041F', 'P'),
    ('\u0440', 'r'), ('\u0420', 'R'),
    ('\u0441', 's'), ('\u0421', 'S'),
    ('\u0442', 't'), ('\u0422', 'T'),
    ('\u0443', 'u'), ('\u0423', 'U'),
    ('\u0444', 'f'), ('\u0424', 'F'),
    ('\u0445', 'x'), ('\u0425', 'X'),
    ('\u044A', "'"), ('\u042A', "'"),
    ('\u044C', ''), ('\u042C', ''),
  ];

  /// Lotin -> Kirill (kontekstga qarab "e" boshqariladi)
  static String toCyrillic(String text) {
    final buf = StringBuffer();
    var i = 0;
    while (i < text.length) {
      var matched = false;
      // 2 belgili digraflarni tekshirish
      if (i + 1 < text.length) {
        final pair = text.substring(i, i + 2);
        for (final (lat, cyr) in _latinToCyrillic) {
          if (lat.length == 2 && pair == lat) {
            buf.write(cyr);
            i += 2;
            matched = true;
            break;
          }
        }
      }
      if (!matched) {
        final ch = text[i];
        // "e"/"E" ni kontekstga qarab boshqarish:
        // Undoshdan keyin → yumshoq е (U+0435/U+0415)
        // Boshqa holat (so'z boshi, unlidan keyin) → qattiq э (U+044D/U+042D)
        if (ch == 'e' || ch == 'E') {
          final prevChar = i > 0 ? text[i - 1] : '';
          if (_consonants.contains(prevChar)) {
            buf.write(ch == 'e' ? '\u0435' : '\u0415');
          } else {
            buf.write(ch == 'e' ? '\u044D' : '\u042D');
          }
        } else {
          var charMatched = false;
          for (final (lat, cyr) in _latinToCyrillic) {
            if (lat.length == 1 && ch == lat) {
              buf.write(cyr);
              charMatched = true;
              break;
            }
          }
          if (!charMatched) buf.write(ch);
        }
        i++;
      }
    }
    return buf.toString();
  }

  /// Kirill -> Lotin
  static String toLatin(String text) {
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      var matched = false;
      final ch = text[i];
      for (final (cyr, lat) in _cyrillicToLatin) {
        if (ch == cyr) {
          buf.write(lat);
          matched = true;
          break;
        }
      }
      if (!matched) buf.write(ch);
    }
    return buf.toString();
  }

  /// Matnda Kirill belgilar bormi?
  static bool isCyrillic(String text) {
    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x0400 && code <= 0x04FF) return true;
    }
    return false;
  }

  /// Matnda Lotin belgilar bormi?
  static bool isLatin(String text) {
    for (var i = 0; i < text.length; i++) {
      final ch = text.codeUnitAt(i);
      if ((ch >= 0x41 && ch <= 0x5A) || (ch >= 0x61 && ch <= 0x7A)) return true;
    }
    return false;
  }
}
