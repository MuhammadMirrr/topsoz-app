"""
O'zbek tili uchun Lotin <-> Kirill transliteratsiya moduli.
Reference: O'zbekiston Respublikasi qonunchiligiga asoslangan.
"""

# Digraflar birinchi tekshiriladi (uzunroq → qisqaroq)
LATIN_TO_CYRILLIC_MAP = [
    ("sh", "ш"), ("Sh", "Ш"), ("SH", "Ш"),
    ("ch", "ч"), ("Ch", "Ч"), ("CH", "Ч"),
    ("ng", "нг"), ("Ng", "Нг"), ("NG", "НГ"),
    ("o'", "ў"), ("O'", "Ў"), ("o`", "ў"), ("O`", "Ў"),
    ("oʻ", "ў"), ("Oʻ", "Ў"), ("oʼ", "ў"), ("Oʼ", "Ў"),
    ("o\u2018", "ў"), ("O\u2018", "Ў"), ("o\u2019", "ў"), ("O\u2019", "Ў"),
    ("o\u2032", "ў"), ("O\u2032", "Ў"),
    ("g'", "ғ"), ("G'", "Ғ"), ("g`", "ғ"), ("G`", "Ғ"),
    ("gʻ", "ғ"), ("Gʻ", "Ғ"), ("gʼ", "ғ"), ("Gʼ", "Ғ"),
    ("g\u2018", "ғ"), ("G\u2018", "Ғ"), ("g\u2019", "ғ"), ("G\u2019", "Ғ"),
    ("g\u2032", "ғ"), ("G\u2032", "Ғ"),
    ("ye", "е"), ("Ye", "Е"), ("YE", "Е"),
    ("yo", "ё"), ("Yo", "Ё"), ("YO", "Ё"),
    ("yu", "ю"), ("Yu", "Ю"), ("YU", "Ю"),
    ("ya", "я"), ("Ya", "Я"), ("YA", "Я"),
    ("ts", "ц"), ("Ts", "Ц"), ("TS", "Ц"),
    ("a", "а"), ("A", "А"),
    ("b", "б"), ("B", "Б"),
    ("d", "д"), ("D", "Д"),
    ("e", "э"), ("E", "Э"),
    ("f", "ф"), ("F", "Ф"),
    ("g", "г"), ("G", "Г"),
    ("h", "ҳ"), ("H", "Ҳ"),
    ("i", "и"), ("I", "И"),
    ("j", "ж"), ("J", "Ж"),
    ("k", "к"), ("K", "К"),
    ("l", "л"), ("L", "Л"),
    ("m", "м"), ("M", "М"),
    ("n", "н"), ("N", "Н"),
    ("o", "о"), ("O", "О"),
    ("p", "п"), ("P", "П"),
    ("q", "қ"), ("Q", "Қ"),
    ("r", "р"), ("R", "Р"),
    ("s", "с"), ("S", "С"),
    ("t", "т"), ("T", "Т"),
    ("u", "у"), ("U", "У"),
    ("v", "в"), ("V", "В"),
    ("x", "х"), ("X", "Х"),
    ("y", "й"), ("Y", "Й"),
    ("z", "з"), ("Z", "З"),
    ("'", "ъ"), ("`", "ъ"), ("ʼ", "ъ"),
]

CYRILLIC_TO_LATIN_MAP = [
    ("ш", "sh"), ("Ш", "Sh"),
    ("ч", "ch"), ("Ч", "Ch"),
    ("ў", "o'"), ("Ў", "O'"),
    ("ғ", "g'"), ("Ғ", "G'"),
    ("ё", "yo"), ("Ё", "Yo"),
    ("ю", "yu"), ("Ю", "Yu"),
    ("я", "ya"), ("Я", "Ya"),
    ("ц", "ts"), ("Ц", "Ts"),
    ("щ", "shch"), ("Щ", "Shch"),
    ("ҳ", "h"), ("Ҳ", "H"),
    ("қ", "q"), ("Қ", "Q"),
    ("э", "e"), ("Э", "E"),
    ("а", "a"), ("А", "A"),
    ("б", "b"), ("Б", "B"),
    ("в", "v"), ("В", "V"),
    ("г", "g"), ("Г", "G"),
    ("д", "d"), ("Д", "D"),
    ("е", "e"), ("Е", "E"),
    ("ж", "j"), ("Ж", "J"),
    ("з", "z"), ("З", "Z"),
    ("и", "i"), ("И", "I"),
    ("й", "y"), ("Й", "Y"),
    ("к", "k"), ("К", "K"),
    ("л", "l"), ("Л", "L"),
    ("м", "m"), ("М", "M"),
    ("н", "n"), ("Н", "N"),
    ("о", "o"), ("О", "O"),
    ("п", "p"), ("П", "P"),
    ("р", "r"), ("Р", "R"),
    ("с", "s"), ("С", "S"),
    ("т", "t"), ("Т", "T"),
    ("у", "u"), ("У", "U"),
    ("ф", "f"), ("Ф", "F"),
    ("х", "x"), ("Х", "X"),
    ("ъ", "'"), ("Ъ", "'"),
    ("ь", ""), ("Ь", ""),
]


_VOWELS = set("aeiouAEIOU")
_CONSONANTS = set("bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ")


def latin_to_cyrillic(text: str) -> str:
    """Lotin yozuvdagi o'zbek so'zni Kirill yozuvga o'giradi."""
    result = []
    i = 0
    while i < len(text):
        matched = False
        # Digraflarni tekshirish (2 belgili)
        if i + 1 < len(text):
            pair = text[i:i+2]
            for lat, cyr in LATIN_TO_CYRILLIC_MAP:
                if len(lat) == 2 and pair == lat:
                    result.append(cyr)
                    i += 2
                    matched = True
                    break
        if not matched:
            char = text[i]
            # "e/E" kontekstga qarab: undoshdan keyin "е", boshqa holatlarda "э"
            if char in ("e", "E"):
                prev_char = text[i - 1] if i > 0 else ""
                if prev_char in _CONSONANTS:
                    result.append("е" if char == "e" else "Е")
                else:
                    result.append("э" if char == "e" else "Э")
                i += 1
                continue
            for lat, cyr in LATIN_TO_CYRILLIC_MAP:
                if len(lat) == 1 and char == lat:
                    result.append(cyr)
                    matched = True
                    break
            if not matched:
                result.append(char)
            i += 1
    return "".join(result)


def cyrillic_to_latin(text: str) -> str:
    """Kirill yozuvdagi o'zbek so'zni Lotin yozuvga o'giradi."""
    result = []
    i = 0
    while i < len(text):
        matched = False
        char = text[i]
        for cyr, lat in CYRILLIC_TO_LATIN_MAP:
            if char == cyr:
                result.append(lat)
                matched = True
                break
        if not matched:
            result.append(char)
        i += 1
    return "".join(result)


def is_cyrillic(text: str) -> bool:
    """Matn Kirill yozuvda yozilganligini tekshiradi."""
    for ch in text:
        if '\u0400' <= ch <= '\u04FF':
            return True
    return False


def is_latin(text: str) -> bool:
    """Matn Lotin yozuvda yozilganligini tekshiradi."""
    for ch in text:
        if 'a' <= ch.lower() <= 'z':
            return True
    return False


if __name__ == "__main__":
    # Test
    tests = [
        ("kitob", "китоб"),
        ("o'zbek", "ўзбек"),
        ("g'alaba", "ғалаба"),
        ("shaxar", "шаҳар"),
        ("chiroyli", "чиройли"),
        ("Toshkent", "Тошкент"),
        ("sevgi", "севги"),
        ("eshik", "эшик"),
        ("kerak", "керак"),
    ]
    print("=== Transliteratsiya testi ===")
    for lat, expected_cyr in tests:
        cyr = latin_to_cyrillic(lat)
        back = cyrillic_to_latin(cyr)
        status = "\u2713" if cyr == expected_cyr else "\u2717"
        print(f"  {status} {lat} \u2192 {cyr} (kutilgan: {expected_cyr}) \u2192 {back}")
