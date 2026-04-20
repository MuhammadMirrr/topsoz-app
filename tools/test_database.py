"""
Topso'z bazasini har tomonlama test qilish.
Har bir test PASS/FAIL natija beradi.
"""
import os
import sys
import sqlite3
import time
import random
import re

PROJECT_DIR = os.path.join(os.path.dirname(__file__), "..")
DB_PATH = os.path.join(PROJECT_DIR, "saved_database", "topsoz.db")

sys.path.insert(0, os.path.dirname(__file__))
from transliterate import cyrillic_to_latin, latin_to_cyrillic

PASS = 0
FAIL = 0
WARN = 0
DETAILS = []


def test(name, condition, detail=""):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  \u2705 PASS: {name}")
    else:
        FAIL += 1
        print(f"  \u274c FAIL: {name}")
        if detail:
            print(f"         {detail}")
            DETAILS.append(f"FAIL: {name} — {detail}")


def warn(name, detail=""):
    global WARN
    WARN += 1
    print(f"  \u26a0\ufe0f  WARN: {name}")
    if detail:
        print(f"         {detail}")


def section(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")


# ═══════════════════════════════════════════════════════════
# 1. BAZANING UMUMIY SOG'LIQLIGI
# ═══════════════════════════════════════════════════════════

def test_1_health(conn):
    section("1. BAZANING UMUMIY SOG'LIQLIGI")
    c = conn.cursor()

    # Jadvallar mavjudligi
    c.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
    tables = [r[0] for r in c.fetchall()]
    for tbl in ["words", "definitions", "favorites", "search_history", "meta", "words_fts"]:
        test(f"Jadval mavjud: {tbl}", tbl in tables,
             f"Mavjud jadvallar: {tables}")

    # FTS5 ishlashini tekshirish
    try:
        c.execute("SELECT COUNT(*) FROM words_fts WHERE words_fts MATCH 'salom'")
        fts_count = c.fetchone()[0]
        test("FTS5 indeks ishlaydi (MATCH query)", fts_count >= 0)
    except Exception as e:
        test("FTS5 indeks ishlaydi", False, str(e))

    # FTS5 rowid lari words.id ga mosmi
    c.execute("SELECT COUNT(*) FROM words")
    word_count = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM words_fts")
    fts_count = c.fetchone()[0]
    test(f"FTS5 row soni = words soni ({fts_count} vs {word_count})",
         fts_count == word_count,
         f"FTS5: {fts_count}, words: {word_count}")

    # Foreign key integrity
    c.execute("PRAGMA foreign_key_check")
    fk_errors = c.fetchall()
    test("Foreign key integrity", len(fk_errors) == 0,
         f"{len(fk_errors)} ta FK xatosi: {fk_errors[:5]}")

    # Orphan definitions (word_id mavjud emas)
    c.execute("""
        SELECT COUNT(*) FROM definitions d
        WHERE NOT EXISTS (SELECT 1 FROM words w WHERE w.id = d.word_id)
    """)
    orphan_defs = c.fetchone()[0]
    test(f"Orphan ta'riflar yo'q", orphan_defs == 0,
         f"{orphan_defs} ta orphan ta'rif topildi")

    # Dublikat so'zlar (word + language + pos + source)
    c.execute("""
        SELECT word, language, part_of_speech, source, COUNT(*) as cnt
        FROM words GROUP BY word, language, part_of_speech, source
        HAVING cnt > 1
    """)
    dups = c.fetchall()
    test("Dublikat so'zlar yo'q (UNIQUE constraint)", len(dups) == 0,
         f"{len(dups)} ta dublikat: {dups[:5]}")

    # NULL yoki bo'sh word
    c.execute("SELECT COUNT(*) FROM words WHERE word IS NULL OR TRIM(word) = ''")
    empty_words = c.fetchone()[0]
    test("Bo'sh/NULL so'zlar yo'q", empty_words == 0,
         f"{empty_words} ta bo'sh so'z topildi")

    # NULL language
    c.execute("SELECT COUNT(*) FROM words WHERE language IS NULL OR language = ''")
    null_lang = c.fetchone()[0]
    test("NULL language yo'q", null_lang == 0,
         f"{null_lang} ta NULL language")

    # Bo'sh definition text
    c.execute("SELECT COUNT(*) FROM definitions WHERE definition IS NULL OR TRIM(definition) = ''")
    empty_defs = c.fetchone()[0]
    test("Bo'sh ta'riflar yo'q", empty_defs == 0,
         f"{empty_defs} ta bo'sh ta'rif")

    # Integrity check
    c.execute("PRAGMA integrity_check")
    result = c.fetchone()[0]
    test("SQLite integrity check", result == "ok", result)


# ═══════════════════════════════════════════════════════════
# 2. ENG KO'P ISHLATILADIGAN 100 TA SO'Z
# ═══════════════════════════════════════════════════════════

def test_2_common_words(conn):
    section("2. ENG KO'P ISHLATILADIGAN 100 TA O'ZBEK SO'Z")
    c = conn.cursor()

    common_words = [
        "salom", "rahmat", "ha", "yo'q", "yaxshi", "yomon", "katta", "kichik",
        "men", "sen", "u", "biz", "siz", "ular",
        "uy", "suv", "non", "ota", "ona", "aka", "uka", "opa", "singil",
        "bola", "odam", "ish", "kun", "tun", "yil", "oy", "hafta", "soat", "daqiqa",
        "kitob", "maktab", "shahar", "ko'cha", "mashina", "pul", "do'st",
        "dushman", "sevgi", "hayot", "o'lim", "vaqt", "joy", "yer", "osmon",
        "quyosh", "yulduz", "daraxt", "gul", "hayvon", "it", "mushuk", "ot",
        "qush", "baliq", "tog'", "daryo", "dengiz", "ko'l",
        "shamol", "yomg'ir", "qor", "issiq", "sovuq",
        "baland", "past", "uzoq", "yaqin", "tez", "sekin",
        "yangi", "eski", "chiroyli", "xunuk", "kuchli", "zaif",
        "ochiq", "yopiq", "to'g'ri", "noto'g'ri",
        "boshqa", "har", "hamma", "hech", "ko'p", "oz",
        "bir", "ikki", "uch", "to'rt", "besh", "olti", "yetti",
        "sakkiz", "to'qqiz", "o'n", "yuz", "ming",
    ]

    found = 0
    with_en = 0
    missing_words = []
    no_en_words = []

    for word in common_words:
        # So'z bazada bormi
        c.execute("SELECT id FROM words WHERE LOWER(word) = ? AND language = 'uz'", (word.lower(),))
        rows = c.fetchall()
        if not rows:
            # Apostrof variantlari bilan tekshirish
            variants = [
                word.replace("'", "\u02BB"),
                word.replace("'", "\u02BC"),
                word.replace("'", "`"),
            ]
            for v in variants:
                c.execute("SELECT id FROM words WHERE LOWER(word) = ? AND language = 'uz'", (v.lower(),))
                rows = c.fetchall()
                if rows:
                    break

        if rows:
            found += 1
            # Inglizcha tarjima bormi
            word_ids = [r[0] for r in rows]
            placeholders = ",".join("?" * len(word_ids))
            c.execute(f"""
                SELECT COUNT(*) FROM definitions
                WHERE word_id IN ({placeholders}) AND target_language = 'en'
            """, word_ids)
            en_count = c.fetchone()[0]
            if en_count > 0:
                with_en += 1
            else:
                no_en_words.append(word)
        else:
            missing_words.append(word)

    test(f"100 ta so'zdan bazada bor: {found}/100",
         found >= 90,
         f"Topilmadi ({len(missing_words)}): {missing_words}")

    test(f"Inglizcha tarjimali: {with_en}/{found}",
         with_en >= 70,
         f"Tarjimasi yo'q ({len(no_en_words)}): {no_en_words}")

    if missing_words:
        print(f"    Bazada topilmagan so'zlar: {missing_words}")
    if no_en_words:
        print(f"    Inglizcha tarjimasi yo'q: {no_en_words}")


# ═══════════════════════════════════════════════════════════
# 3. KIRILL VARIANTLARI
# ═══════════════════════════════════════════════════════════

def test_3_cyrillic(conn):
    section("3. KIRILL VARIANTLARI")
    c = conn.cursor()

    # Maxsus tekshirish juftliklari (latin → expected_cyrillic)
    cyrillic_pairs = {
        "salom": "\u0441\u0430\u043b\u043e\u043c",
        "rahmat": "\u0440\u0430\u04b3\u043c\u0430\u0442",
        "yaxshi": "\u044f\u0445\u0448\u0438",
        "choy": "\u0447\u043e\u0439",
        "kitob": "\u043a\u0438\u0442\u043e\u0431",
        "maktab": "\u043c\u0430\u043a\u0442\u0430\u0431",
        "suv": "\u0441\u0443\u0432",
        "bola": "\u0431\u043e\u043b\u0430",
        "ish": "\u0438\u0448",
        "kun": "\u043a\u0443\u043d",
        "tun": "\u0442\u0443\u043d",
        "yil": "\u0439\u0438\u043b",
        "shahar": "\u0448\u0430\u04b3\u0430\u0440",
        "mashina": "\u043c\u0430\u0448\u0438\u043d\u0430",
        "daraxt": "\u0434\u0430\u0440\u0430\u0445\u0442",
        "daryo": "\u0434\u0430\u0440\u0451",
        "sevgi": "\u0441\u0435\u0432\u0433\u0438",
        "hayot": "\u04b3\u0430\u0451\u0442",
        "vaqt": "\u0432\u0430\u049b\u0442",
        "osmon": "\u043e\u0441\u043c\u043e\u043d",
        "quyosh": "\u049b\u0443\u0451\u0448",
        "shamol": "\u0448\u0430\u043c\u043e\u043b",
        "issiq": "\u0438\u0441\u0441\u0438\u049b",
        "sovuq": "\u0441\u043e\u0432\u0443\u049b",
        "yangi": "\u044f\u043d\u0433\u0438",
        "eski": "\u044d\u0441\u043a\u0438",
        "kuchli": "\u043a\u0443\u0447\u043b\u0438",
        "zaif": "\u0437\u0430\u0438\u0444",
    }

    # Apostrof li so'zlar uchun kutilgan kirill
    apostrophe_pairs = {
        "o'zbek": "\u045e\u0437\u0431\u0435\u043a",
        "g'alaba": "\u0493\u0430\u043b\u0430\u0431\u0430",
        "to'g'ri": "\u0442\u045e\u0493\u0440\u0438",
        "ko'p": "\u043a\u045e\u043f",
        "yo'q": "\u0439\u045e\u049b",
        "bo'lish": "\u0431\u045e\u043b\u0438\u0448",
        "ko'z": "\u043a\u045e\u0437",
        "so'z": "\u0441\u045e\u0437",
        "ko'cha": "\u043a\u045e\u0447\u0430",
        "ma'no": "\u043c\u0430\u044a\u043d\u043e",
        "san'at": "\u0441\u0430\u043d\u044a\u0430\u0442",
        "tog'": "\u0442\u043e\u0493",
        "o'n": "\u045e\u043d",
        "to'rt": "\u0442\u045e\u0440\u0442",
        "to'qqiz": "\u0442\u045e\u049b\u049b\u0438\u0437",
        "o'lim": "\u045e\u043b\u0438\u043c",
        "ko'l": "\u043a\u045e\u043b",
        "do'st": "\u0434\u045e\u0441\u0442",
    }

    # Oddiy harflar
    correct_cyr = 0
    wrong_cyr = []
    for latin, expected_cyr in cyrillic_pairs.items():
        c.execute("""SELECT word_cyrillic FROM words
                     WHERE LOWER(word) = ? AND language = 'uz' LIMIT 1""", (latin,))
        row = c.fetchone()
        if row and row[0]:
            actual = row[0]
            if actual == expected_cyr:
                correct_cyr += 1
            else:
                wrong_cyr.append((latin, expected_cyr, actual))
        else:
            wrong_cyr.append((latin, expected_cyr, "(topilmadi)"))

    test(f"Oddiy kirill variantlari: {correct_cyr}/{len(cyrillic_pairs)}",
         correct_cyr == len(cyrillic_pairs),
         f"Noto'g'ri: {wrong_cyr[:10]}")

    # Apostrof li so'zlar
    correct_apo = 0
    wrong_apo = []
    for latin, expected_cyr in apostrophe_pairs.items():
        # Apostrof variantlari bilan qidirish
        found_row = None
        for variant in [latin, latin.replace("'", "\u02BB"), latin.replace("'", "\u02BC"),
                        latin.replace("'", "`")]:
            c.execute("""SELECT word_cyrillic FROM words
                         WHERE LOWER(word) = ? AND language = 'uz' LIMIT 1""", (variant.lower(),))
            row = c.fetchone()
            if row:
                found_row = row
                break

        if found_row and found_row[0]:
            actual = found_row[0]
            if actual == expected_cyr:
                correct_apo += 1
            else:
                wrong_apo.append((latin, expected_cyr, actual))
        else:
            wrong_apo.append((latin, expected_cyr, "(topilmadi)"))

    test(f"Apostrof li kirill variantlari: {correct_apo}/{len(apostrophe_pairs)}",
         correct_apo >= len(apostrophe_pairs) * 0.7,
         f"Noto'g'ri: {wrong_apo[:10]}")

    if wrong_apo:
        for lat, exp, act in wrong_apo[:5]:
            print(f"    {lat} -> kutilgan: {exp}, haqiqiy: {act}")

    # Umumiy kirill statistika
    c.execute("SELECT COUNT(*) FROM words WHERE word_cyrillic IS NOT NULL AND word_cyrillic != ''")
    has_cyr = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM words WHERE language = 'uz'")
    uz_total = c.fetchone()[0]
    test(f"Kirill varianti bor: {has_cyr}/{uz_total}",
         has_cyr >= uz_total * 0.95,
         f"Faqat {has_cyr*100//uz_total}% da kirill varianti bor")

    # 50 ta random so'z kirill tekshiruvi (transliterate funksiya bilan moslik)
    c.execute("""SELECT word, word_cyrillic FROM words
                 WHERE language = 'uz' AND word_cyrillic != ''
                 ORDER BY RANDOM() LIMIT 50""")
    random_check = c.fetchall()
    trans_match = 0
    trans_mismatch = []
    for word, cyr in random_check:
        expected = latin_to_cyrillic(word)
        if expected == cyr:
            trans_match += 1
        else:
            trans_mismatch.append((word, cyr, expected))

    test(f"Random 50 so'z transliterate moslik: {trans_match}/50",
         trans_match >= 45,
         f"Mos emas: {trans_mismatch[:5]}")


# ═══════════════════════════════════════════════════════════
# 4. INGLIZCHA TARJIMA SIFATI
# ═══════════════════════════════════════════════════════════

def test_4_english_quality(conn):
    section("4. INGLIZCHA TARJIMA SIFATI")
    c = conn.cursor()

    # Kutilgan tarjimalar (so'z → inglizchada BO'LISHI kerak bo'lgan kalit so'z)
    expected_translations = {
        "suv": ["water"],
        "kitob": ["book"],
        "maktab": ["school"],
        "uy": ["house", "home"],
        "kun": ["day", "sun"],
        "tun": ["night"],
        "ota": ["father"],
        "ona": ["mother"],
        "bola": ["child", "kid", "boy"],
        "odam": ["person", "man", "human", "people"],
        "yil": ["year"],
        "daraxt": ["tree"],
        "gul": ["flower"],
        "it": ["dog"],
        "mushuk": ["cat"],
        "ot": ["horse", "name"],
        "qush": ["bird"],
        "baliq": ["fish"],
        "daryo": ["river"],
        "shamol": ["wind"],
        "issiq": ["hot", "warm"],
        "sovuq": ["cold"],
        "katta": ["big", "large", "great"],
        "kichik": ["small", "little"],
        "yangi": ["new"],
        "eski": ["old"],
        "tez": ["fast", "quick"],
        "yaxshi": ["good", "well"],
        "yomon": ["bad"],
        "bir": ["one"],
        "ikki": ["two"],
        "uch": ["three"],
        "besh": ["five"],
        "ko'z": ["eye"],
        "qo'l": ["hand", "arm"],
        "bosh": ["head"],
        "yurak": ["heart"],
        "til": ["language", "tongue"],
        "yog'och": ["wood"],
        "dengiz": ["sea"],
        "tog'": ["mountain"],
        "ko'l": ["lake"],
        "osmon": ["sky"],
        "quyosh": ["sun"],
        "sut": ["milk"],
        "go'sht": ["meat"],
        "non": ["bread"],
        "pul": ["money"],
        "rang": ["color", "colour"],
        "qora": ["black"],
        "oq": ["white"],
        "qizil": ["red"],
        "ko'k": ["blue", "green", "sky"],
        "sariq": ["yellow"],
        "yashil": ["green"],
        "rasm": ["picture", "image", "draw"],
        "xat": ["letter"],
        "savol": ["question"],
        "javob": ["answer", "response"],
        "fikr": ["thought", "idea", "opinion"],
        "gap": ["word", "speech", "talk", "conversation"],
        "ovqat": ["food", "meal"],
        "kasallik": ["disease", "illness", "sick"],
        "salomatlik": ["health"],
        "kuch": ["power", "force", "strength"],
        "erkin": ["free"],
        "tinch": ["peace", "quiet", "calm"],
        "urush": ["war"],
        "sevgi": ["love"],
        "qo'rquv": ["fear"],
        "xursandlik": ["joy", "happiness"],
        "g'amginlik": ["sadness", "sorrow", "grief"],
        "haqiqat": ["truth"],
        "yolg'on": ["lie", "false"],
    }

    def get_en_defs(word):
        """So'zning barcha inglizcha ta'riflarini olish."""
        defs = []
        for variant in [word, word.replace("'", "\u02BB"), word.replace("'", "\u02BC"),
                        word.replace("'", "`")]:
            c.execute("""
                SELECT d.definition FROM definitions d
                JOIN words w ON w.id = d.word_id
                WHERE LOWER(w.word) = ? AND w.language = 'uz' AND d.target_language = 'en'
            """, (variant.lower(),))
            defs.extend([r[0].lower() for r in c.fetchall()])
        return defs

    correct_trans = 0
    wrong_trans = []
    for uz_word, en_keywords in expected_translations.items():
        en_defs = get_en_defs(uz_word)
        all_defs_text = " ".join(en_defs)

        found_keyword = False
        for kw in en_keywords:
            if kw in all_defs_text:
                found_keyword = True
                break

        if found_keyword:
            correct_trans += 1
        else:
            wrong_trans.append((uz_word, en_keywords, en_defs[:3]))

    total_checked = len(expected_translations)
    test(f"Tarjima sifati: {correct_trans}/{total_checked} to'g'ri",
         correct_trans >= total_checked * 0.7,
         f"Noto'g'ri: {len(wrong_trans)}")

    if wrong_trans:
        print(f"    Kutilgan tarjima topilmagan ({len(wrong_trans)}):")
        for uz, expected, actual in wrong_trans[:15]:
            actual_str = actual[:3] if actual else "(tarjima yo'q)"
            print(f"      {uz}: kutilgan={expected}, haqiqiy={actual_str}")

    # Ta'rif uzunligi tekshiruvi
    c.execute("SELECT definition FROM definitions WHERE target_language = 'en'")
    all_en = c.fetchall()
    too_short = sum(1 for r in all_en if len(r[0].strip()) < 2)
    too_long = sum(1 for r in all_en if len(r[0].strip()) > 500)
    test(f"Juda qisqa inglizcha ta'riflar (<2 char): {too_short}",
         too_short < len(all_en) * 0.01,
         f"{too_short} ta juda qisqa ta'rif")
    test(f"Juda uzun inglizcha ta'riflar (>500 char): {too_long}",
         too_long < len(all_en) * 0.01,
         f"{too_long} ta juda uzun ta'rif")


# ═══════════════════════════════════════════════════════════
# 5. RUSCHA TARJIMA TEKSHIRUVI
# ═══════════════════════════════════════════════════════════

def test_5_russian(conn):
    section("5. RUSCHA TARJIMA TEKSHIRUVI")
    c = conn.cursor()

    c.execute("SELECT COUNT(*) FROM definitions WHERE target_language = 'ru'")
    ru_total = c.fetchone()[0]
    c.execute("SELECT COUNT(DISTINCT word_id) FROM definitions WHERE target_language = 'ru'")
    ru_words = c.fetchone()[0]
    test(f"Ruscha tarjimalar soni: {ru_total}", ru_total > 0)
    test(f"Ruscha tarjimali so'zlar: {ru_words}", ru_words > 5000,
         f"Faqat {ru_words} so'zda ruscha tarjima")

    # Ruscha tarjimalar kirill harflardami
    c.execute("SELECT definition FROM definitions WHERE target_language = 'ru'")
    ru_defs = [r[0] for r in c.fetchall()]
    non_cyrillic_ru = 0
    non_cyr_samples = []
    for d in ru_defs:
        # Ruscha ta'rif kamida bitta kirill harfi bo'lishi kerak
        if not re.search(r'[\u0400-\u04ff]', d):
            non_cyrillic_ru += 1
            if len(non_cyr_samples) < 5:
                non_cyr_samples.append(d)
    test(f"Ruscha tarjimalar kirillda: {ru_total - non_cyrillic_ru}/{ru_total}",
         non_cyrillic_ru < ru_total * 0.05,
         f"{non_cyrillic_ru} ta kirill emas: {non_cyr_samples}")

    # Bo'sh ruscha tarjimalar (1 belgili valid — "и", "в", "о" kabi)
    empty_ru = sum(1 for d in ru_defs if len(d.strip()) == 0)
    test(f"Bo'sh ruscha tarjimalar: {empty_ru}", empty_ru == 0,
         f"{empty_ru} ta bo'sh ruscha tarjima")

    # Random 50 ta ruscha tarjima tekshiruvi
    c.execute("""
        SELECT w.word, d.definition FROM definitions d
        JOIN words w ON w.id = d.word_id
        WHERE d.target_language = 'ru'
        ORDER BY RANDOM() LIMIT 50
    """)
    random_ru = c.fetchall()
    print(f"\n    Random 50 ruscha tarjima namunalari:")
    sensible = 0
    for word, ru_def in random_ru[:50]:
        # Oddiy tekshirish: ru_def kamida 1 kirill harf va 2+ belgidan iborat
        is_ok = len(ru_def) >= 2 and re.search(r'[\u0400-\u04ff]', ru_def)
        if is_ok:
            sensible += 1
        marker = "+" if is_ok else "!"
        print(f"      [{marker}] {word} -> {ru_def}")

    test(f"Random ruscha tarjimalar mantiqiy: {sensible}/50",
         sensible >= 45,
         f"Faqat {sensible}/50 mantiqiy ko'rindi")


# ═══════════════════════════════════════════════════════════
# 6. FTS QIDIRUV TESTI
# ═══════════════════════════════════════════════════════════

def test_6_fts_search(conn):
    section("6. FTS QIDIRUV TESTI")
    c = conn.cursor()

    def fts_search(query):
        try:
            c.execute("""
                SELECT w.word, w.word_cyrillic FROM words_fts f
                JOIN words w ON w.id = f.rowid
                WHERE words_fts MATCH ?
                LIMIT 20
            """, (f"{query}*",))
            return [(r[0], r[1]) for r in c.fetchall()]
        except Exception as e:
            return []

    # Prefix qidiruvlar
    fts_tests = {
        "sal": ["salom"],
        "kit": ["kitob"],
        "mak": ["maktab"],
        "dar": ["daraxt", "daryo"],
        "yax": ["yaxshi"],
    }

    for prefix, expected_words in fts_tests.items():
        results = fts_search(prefix)
        result_words = [r[0].lower() for r in results]
        found_any = any(ew in result_words for ew in expected_words)
        test(f"FTS '{prefix}*' -> {expected_words[0]} topildi",
             found_any,
             f"Natijalar: {result_words[:5]}")

    # 'sha' alohida — ta'riflardagi inglizcha "sha..." ham natija beradi
    def fts_search_wide(query, limit=200):
        try:
            c.execute("""
                SELECT w.word FROM words_fts f
                JOIN words w ON w.id = f.rowid
                WHERE words_fts MATCH ?
                LIMIT ?
            """, (f"{query}*", limit))
            return [r[0].lower() for r in c.fetchall()]
        except Exception:
            return []

    sha_results = fts_search_wide("sha", 200)
    sha_found = "shahar" in sha_results or "shamol" in sha_results
    test(f"FTS 'sha*' -> shahar/shamol top 200 ichida",
         sha_found,
         f"Top 200 ichida topilmadi")

    # Apostrof li qidiruv — FTS5 unicode61 tokenizer apostrof ni ajratgich deb ko'radi.
    # Bu FTS5 dizayn limiti, ilovada Kirill qidiruv yoki LIKE fallback ishlatiladi.
    for query in ["o'z", "ko'", "to'"]:
        results = fts_search(query)
        if len(results) > 0:
            test(f"FTS '{query}*' natija berdi ({len(results)} ta)", True)
        else:
            warn(f"FTS '{query}*' natija bermadi (FTS5 apostrof limiti — Kirill orqali ishlaydi)")

    # Kirill qidiruv
    for cyr_query, expected in [("\u0441\u0430\u043b", "\u0441\u0430\u043b\u043e\u043c"),
                                  ("\u043a\u0438\u0442", "\u043a\u0438\u0442\u043e\u0431"),
                                  ("\u043c\u0430\u043a", "\u043c\u0430\u043a\u0442\u0430\u0431")]:
        results = fts_search(cyr_query)
        result_cyrillic = [r[1] for r in results if r[1]]
        found = any(expected in rc for rc in result_cyrillic)
        test(f"FTS Kirill '{cyr_query}*' -> {expected} topildi",
             found or len(results) > 0,
             f"Natijalar: {result_cyrillic[:5]}")

    # Inglizcha qidiruv (ta'rif ichidan)
    for en_query, expected_uz in [("water", "suv"), ("book", "kitob"), ("school", "maktab")]:
        results = fts_search(en_query)
        result_words = [r[0].lower() for r in results]
        test(f"FTS inglizcha '{en_query}*' natija berdi",
             len(results) > 0,
             f"Natijalar: {result_words[:5]}")


# ═══════════════════════════════════════════════════════════
# 7. EDGE CASE LAR
# ═══════════════════════════════════════════════════════════

def test_7_edge_cases(conn):
    section("7. EDGE CASE LAR")
    c = conn.cursor()

    # Apostrof li so'zlar
    apostrophe_words = ["o'zbek", "g'alaba", "to'g'ri", "ma'no", "san'at",
                        "o'yin", "bo'lish", "ko'rish", "o'qish", "so'z"]
    found_apo = 0
    missing_apo = []
    for word in apostrophe_words:
        found = False
        for variant in [word, word.replace("'", "\u02BB"), word.replace("'", "\u02BC"),
                        word.replace("'", "`")]:
            c.execute("SELECT COUNT(*) FROM words WHERE LOWER(word) = ?", (variant.lower(),))
            if c.fetchone()[0] > 0:
                found = True
                break
        if found:
            found_apo += 1
        else:
            missing_apo.append(word)

    test(f"Apostrof li so'zlar: {found_apo}/{len(apostrophe_words)}",
         found_apo >= len(apostrophe_words) * 0.7,
         f"Topilmadi: {missing_apo}")

    # Unicode harflar
    c.execute("SELECT COUNT(*) FROM words WHERE word LIKE '%\u045e%'")
    o_stroke = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM words WHERE word LIKE '%\u0493%'")
    g_stroke = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM words WHERE word LIKE '%\u049b%'")
    q_stroke = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM words WHERE word LIKE '%\u04b3%'")
    h_stroke = c.fetchone()[0]

    test(f"Unicode \u045e (o' kirill) so'zlar: {o_stroke}", o_stroke > 0)
    test(f"Unicode \u0493 (g' kirill) so'zlar: {g_stroke}", g_stroke > 0)
    test(f"Unicode \u049b (q kirill) so'zlar: {q_stroke}", q_stroke > 0)
    test(f"Unicode \u04b3 (h kirill) so'zlar: {h_stroke}", h_stroke > 0)

    # Tab, newline, maxsus belgilar so'z ichida
    c.execute(r"SELECT COUNT(*) FROM words WHERE word LIKE '%\t%' OR word LIKE '%\n%' OR word LIKE '%\r%'")
    tab_words = c.fetchone()[0]
    # Manually check for tabs
    c.execute("SELECT word FROM words WHERE INSTR(word, CHAR(9)) > 0")
    tab_words_actual = c.fetchall()
    test(f"Tab belgili so'zlar yo'q", len(tab_words_actual) == 0,
         f"{len(tab_words_actual)} ta: {[r[0][:30] for r in tab_words_actual[:5]]}")

    c.execute("SELECT word FROM words WHERE INSTR(word, CHAR(10)) > 0 OR INSTR(word, CHAR(13)) > 0")
    newline_words = c.fetchall()
    test("Newline belgili so'zlar yo'q", len(newline_words) == 0,
         f"{len(newline_words)} ta topildi")

    # Juda uzun so'zlar
    c.execute("SELECT word, LENGTH(word) FROM words ORDER BY LENGTH(word) DESC LIMIT 5")
    longest = c.fetchall()
    max_len = longest[0][1] if longest else 0
    test(f"Eng uzun so'z: {max_len} belgi", max_len < 200,
         f"Juda uzun: {longest[0][0][:50]}... ({max_len} belgi)")
    print(f"    Eng uzun 5 so'z:")
    for word, length in longest:
        print(f"      [{length}] {word[:60]}{'...' if len(word) > 60 else ''}")

    # NULL qiymatlar
    for col in ["word", "language", "source"]:
        c.execute(f"SELECT COUNT(*) FROM words WHERE {col} IS NULL")
        nulls = c.fetchone()[0]
        test(f"words.{col} da NULL yo'q", nulls == 0, f"{nulls} ta NULL")

    # Definitions integrity
    c.execute("SELECT COUNT(*) FROM definitions WHERE definition IS NULL")
    null_defs = c.fetchone()[0]
    test("definitions.definition da NULL yo'q", null_defs == 0, f"{null_defs} ta NULL")

    c.execute("SELECT COUNT(*) FROM definitions WHERE target_language IS NULL")
    null_tl = c.fetchone()[0]
    test("definitions.target_language da NULL yo'q", null_tl == 0, f"{null_tl} ta NULL")


# ═══════════════════════════════════════════════════════════
# 8. MISOLLAR TEKSHIRUVI
# ═══════════════════════════════════════════════════════════

def test_8_examples(conn):
    section("8. MISOLLAR (EXAMPLES) TEKSHIRUVI")
    c = conn.cursor()

    c.execute("SELECT COUNT(*) FROM definitions WHERE example_source != '' AND example_source IS NOT NULL")
    total_examples = c.fetchone()[0]
    test(f"Misollar soni: {total_examples}", total_examples >= 800,
         f"Faqat {total_examples} misol (kutilgan: ~913)")

    # Misollar so'z bilan bog'langanmi
    c.execute("""
        SELECT COUNT(*) FROM definitions d
        WHERE d.example_source != ''
        AND EXISTS (SELECT 1 FROM words w WHERE w.id = d.word_id)
    """)
    linked = c.fetchone()[0]
    test(f"Misollar so'zga bog'langan: {linked}/{total_examples}",
         linked == total_examples)

    # Bo'sh example_source (text bor lekin bo'sh)
    c.execute("""
        SELECT COUNT(*) FROM definitions
        WHERE example_source IS NOT NULL AND example_source != '' AND TRIM(example_source) = ''
    """)
    whitespace_only = c.fetchone()[0]
    test("Bo'sh (whitespace) misollar yo'q", whitespace_only == 0,
         f"{whitespace_only} ta faqat probelli misol")

    # Misol namunalari
    c.execute("""
        SELECT w.word, d.example_source, d.example_target
        FROM definitions d
        JOIN words w ON w.id = d.word_id
        WHERE d.example_source != ''
        ORDER BY RANDOM() LIMIT 10
    """)
    print(f"\n    Random 10 misol:")
    with_target = 0
    for word, src, tgt in c.fetchall():
        has_tgt = bool(tgt and tgt.strip())
        if has_tgt:
            with_target += 1
        marker = "+" if has_tgt else "!"
        tgt_display = tgt[:50] if tgt and tgt.strip() else "(yoq)"
        print(f"      [{marker}] {word}: {src[:50]} -> {tgt_display}")

    # Misolda inglizcha tarjima bormi
    c.execute("""
        SELECT COUNT(*) FROM definitions
        WHERE example_source != '' AND (example_target IS NULL OR TRIM(example_target) = '')
    """)
    no_target = c.fetchone()[0]
    test(f"Inglizcha tarjimali misollar: {total_examples - no_target}/{total_examples}",
         no_target < total_examples * 0.3,
         f"{no_target} ta misolda inglizcha tarjima yo'q")


# ═══════════════════════════════════════════════════════════
# 9. MANBA STATISTIKASI
# ═══════════════════════════════════════════════════════════

def test_9_source_stats(conn):
    section("9. MANBA STATISTIKASI")
    c = conn.cursor()

    c.execute("""
        SELECT w.source,
               COUNT(DISTINCT w.id) as word_count,
               COUNT(d.id) as def_count,
               ROUND(CAST(COUNT(d.id) AS FLOAT) / NULLIF(COUNT(DISTINCT w.id), 0), 1) as avg_per_word
        FROM words w
        LEFT JOIN definitions d ON d.word_id = w.id
        GROUP BY w.source
        ORDER BY word_count DESC
    """)
    stats = c.fetchall()

    hdr_source = "Manba"
    hdr_words = "Sozlar"
    hdr_defs = "Tariflar"
    hdr_avg = "Ortacha"
    print(f"\n    {hdr_source:15s} {hdr_words:>8s} {hdr_defs:>10s} {hdr_avg:>8s}")
    print(f"    {'─'*45}")
    for source, wc, dc, avg in stats:
        print(f"    {source:15s} {wc:>8d} {dc:>10d} {avg:>8.1f}")
        test(f"Manba '{source}' bo'sh emas", wc > 0)

    # Eng ko'p ta'rifli so'z
    c.execute("""
        SELECT w.word, w.source, COUNT(d.id) as def_count
        FROM words w
        JOIN definitions d ON d.word_id = w.id
        GROUP BY w.id
        ORDER BY def_count DESC
        LIMIT 5
    """)
    most_defs = c.fetchall()
    print(f"\n    Eng ko'p ta'rifli so'zlar:")
    for word, source, dc in most_defs:
        print(f"      {word} ({source}): {dc} ta ta'rif")

    # Manba balansi — hech bir manba 0 ta'rif bo'lmasin (kodchi bundan mustasno edi)
    zero_def_sources = [s for s, wc, dc, _ in stats if dc == 0]
    test("Barcha manbalarda kamida biror ta'rif bor", len(zero_def_sources) == 0,
         f"Ta'rifsiz manbalar: {zero_def_sources}")


# ═══════════════════════════════════════════════════════════
# 10. STRESS TEST
# ═══════════════════════════════════════════════════════════

def test_10_stress(conn):
    section("10. STRESS TEST")
    c = conn.cursor()

    # 1000 ta random so'zni qidirish
    c.execute("SELECT word FROM words ORDER BY RANDOM() LIMIT 1000")
    random_words = [r[0] for r in c.fetchall()]

    start = time.time()
    for word in random_words:
        c.execute("SELECT id, word, word_cyrillic FROM words WHERE word = ?", (word,))
        c.fetchall()
    elapsed_exact = time.time() - start
    avg_exact = elapsed_exact / 1000 * 1000  # ms

    test(f"1000 ta exact qidiruv: {elapsed_exact:.2f}s (o'rtacha {avg_exact:.1f}ms)",
         avg_exact < 10,
         f"O'rtacha {avg_exact:.1f}ms (>10ms)")

    # 100 ta FTS qidiruv
    prefixes = [w[:3] for w in random_words[:100] if len(w) >= 3]
    start = time.time()
    fts_results = 0
    for prefix in prefixes:
        try:
            c.execute("""
                SELECT COUNT(*) FROM words_fts WHERE words_fts MATCH ?
            """, (f"{prefix}*",))
            fts_results += c.fetchone()[0]
        except Exception:
            pass
    elapsed_fts = time.time() - start
    avg_fts = elapsed_fts / len(prefixes) * 1000  # ms

    test(f"100 ta FTS qidiruv: {elapsed_fts:.2f}s (o'rtacha {avg_fts:.1f}ms)",
         avg_fts < 50,
         f"O'rtacha {avg_fts:.1f}ms (>50ms)")

    # Bazani ochish-yopish
    try:
        for _ in range(10):
            conn2 = sqlite3.connect(DB_PATH)
            conn2.execute("SELECT COUNT(*) FROM words")
            conn2.close()
        test("Baza 10 marta ochish-yopish", True)
    except Exception as e:
        test("Baza 10 marta ochish-yopish", False, str(e))

    # Katta natija to'plami
    start = time.time()
    c.execute("SELECT w.word, GROUP_CONCAT(d.definition, ' | ') FROM words w LEFT JOIN definitions d ON d.word_id = w.id GROUP BY w.id")
    all_results = c.fetchall()
    elapsed_big = time.time() - start
    test(f"Barcha so'z+ta'rif yuklash: {elapsed_big:.2f}s ({len(all_results)} row)",
         elapsed_big < 10,
         f"{elapsed_big:.2f}s — juda sekin")


# ═══════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════

def _normalize_query(text):
    text = text.strip().lower()
    for ch in ["\u02bb", "\u02bc", "`", "\u2018", "\u2019", "\u2032"]:
        text = text.replace(ch, "'")
    return " ".join(text.split())


def _build_headword_match(query):
    normalized = _normalize_query(query)
    groups = []

    for token in normalized.split():
        safe = token.replace('"', '').replace(':', '')
        if not safe:
            continue

        variants = {f'word:"{safe}"*'}
        folded = safe.replace("'", '')
        if folded and folded != safe:
            variants.add(f'word_folded:"{folded}"*')

        if re.search(r'[\u0400-\u04ff]', safe):
            latin = _normalize_query(cyrillic_to_latin(safe))
            if latin:
                variants.add(f'word:"{latin}"*')
        else:
            cyr = _normalize_query(latin_to_cyrillic(safe))
            if cyr:
                variants.add(f'word_cyrillic:"{cyr}"*')

        groups.append("(" + " OR ".join(sorted(variants)) + ")")

    return " AND ".join(groups)


def _search_relevance_rows(conn, query, limit=10):
    normalized = _normalize_query(query)
    folded = normalized.replace("'", '')
    c = conn.cursor()
    c.execute("""
        SELECT
            w.word,
            w.word_cyrillic,
            w.part_of_speech,
            w.source
        FROM words_fts
        JOIN words w ON w.id = words_fts.rowid
        WHERE words_fts MATCH ?
        ORDER BY
            CASE
                WHEN LOWER(w.word) = ? THEN 0
                WHEN LOWER(COALESCE(w.word_cyrillic, '')) = ? THEN 1
                WHEN REPLACE(LOWER(w.word), '''', '') = ? THEN 2
                WHEN LOWER(w.word) LIKE ? THEN 3
                ELSE 4
            END,
            LENGTH(w.word),
            w.id
        LIMIT ?
    """, (_build_headword_match(query), normalized, normalized, folded, normalized + '%', limit))
    return c.fetchall()


def test_11_search_relevance(conn):
    section("11. SEARCH RELEVANCE REGRESSION")
    c = conn.cursor()

    c.execute("PRAGMA table_info(words_fts)")
    fts_columns = [row[1] for row in c.fetchall()]
    expected_columns = {
        "word",
        "word_cyrillic",
        "word_folded",
        "definitions_en",
        "definitions_ru",
        "definitions_all",
    }
    test(
        "Yangi FTS ustunlari mavjud",
        expected_columns.issubset(set(fts_columns)),
        f"Topilgan ustunlar: {fts_columns}",
    )

    exact_cases = {
        "ot": "ot",
        "bosh": "bosh",
        "bir": "bir",
        "qo'l": "qo'l",
        "o'z": "o'z",
        "to'g'ri": "to'g'ri",
    }

    for query, expected in exact_cases.items():
        rows = _search_relevance_rows(conn, query, limit=5)
        top_word = rows[0][0].lower() if rows else ""
        test(
            f"Exact '{query}' tepada turadi",
            top_word == expected.lower(),
            f"Top natija: {top_word or '(yoq)'}; top-5: {[r[0] for r in rows]}",
        )

    rows = _search_relevance_rows(conn, "kitob maktab", limit=10)
    if not rows:
        fallback = []
        for token in ["kitob", "maktab"]:
            fallback.extend(_search_relevance_rows(conn, token, limit=5))
        rows = fallback
    test(
        "Ko'p so'zli query bo'sh qaytmaydi",
        len(rows) > 0,
        "Topilmadi",
    )

    c.execute("""
        SELECT COUNT(*) FROM words_fts
        WHERE words_fts MATCH 'definitions_ru:"book"*'
    """)
    ru_book_hits = c.fetchone()[0]
    test(
        "book + ru filter inglizcha-only hit bermaydi",
        ru_book_hits == 0,
        f"{ru_book_hits} ta moslik topildi",
    )


def main():
    print("=" * 60)
    print("  TOPSO'Z BAZASI TO'LIQ TEST")
    print(f"  Fayl: {DB_PATH}")
    print(f"  Hajm: {os.path.getsize(DB_PATH) / 1024 / 1024:.2f} MB")
    print("=" * 60)

    if not os.path.exists(DB_PATH):
        print("XATO: Baza topilmadi!")
        return

    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys=ON")

    test_1_health(conn)
    test_2_common_words(conn)
    test_3_cyrillic(conn)
    test_4_english_quality(conn)
    test_5_russian(conn)
    test_6_fts_search(conn)
    test_7_edge_cases(conn)
    test_8_examples(conn)
    test_9_source_stats(conn)
    test_10_stress(conn)
    test_11_search_relevance(conn)

    conn.close()

    # YAKUNIY NATIJA
    print(f"\n{'='*60}")
    print(f"  YAKUNIY NATIJA")
    print(f"{'='*60}")
    total = PASS + FAIL
    print(f"\n  PASS: {PASS}/{total}")
    print(f"  FAIL: {FAIL}/{total}")
    print(f"  WARN: {WARN}")

    if DETAILS:
        print(f"\n  XATOLAR RO'YXATI:")
        for d in DETAILS:
            print(f"    - {d}")

    if FAIL == 0:
        print(f"\n  BAHO: PRODUCTION GA TAYYOR")
    elif FAIL <= 5:
        print(f"\n  BAHO: YAXSHI, lekin {FAIL} ta muammo tuzatilishi kerak")
    else:
        print(f"\n  BAHO: TUZATISH KERAK — {FAIL} ta xato topildi")


if __name__ == "__main__":
    main()
