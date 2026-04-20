"""
Barcha manbalarni birlashtirb SQLite baza yaratish.
Natija: saved_database/topsoz.db
"""
import html
import os
import re
import sys
import sqlite3

# Parsers va transliterate modullarini import qilish
sys.path.insert(0, os.path.dirname(__file__))
from transliterate import latin_to_cyrillic, is_cyrillic

# HTML tozalash uchun regexlar
_RE_BR = re.compile(r"<\s*br\s*/?\s*>", re.IGNORECASE)
_RE_LI_OPEN = re.compile(r"<\s*li\s*[^>]*>", re.IGNORECASE)
_RE_BLOCK_CLOSE = re.compile(r"<\s*/\s*(p|div|ol|ul|li)\s*>", re.IGNORECASE)
_RE_TAG = re.compile(r"<[^>]+>")
_RE_MULTINEWLINE = re.compile(r"\n\s*\n+")
_RE_MULTISPACE = re.compile(r"[ \t]+")


def clean_html(text):
    """HTML teglarini olib tashlaydi, entitylarni dekod qiladi.

    Masalan:
        "<i>noun</i><br><ol><li>oblast, province</li></ol>"
        → "noun\n• oblast, province"
    """
    if not text:
        return text
    if "<" not in text and "&" not in text:
        return text

    result = _RE_BR.sub("\n", text)
    result = _RE_LI_OPEN.sub("\n• ", result)
    result = _RE_BLOCK_CLOSE.sub("\n", result)
    result = _RE_TAG.sub("", result)
    result = html.unescape(result)
    result = _RE_MULTINEWLINE.sub("\n", result)
    result = _RE_MULTISPACE.sub(" ", result)
    return result.strip()
from search_index import DB_VERSION, rebuild_search_index
from parsers.parse_kaikki import parse_kaikki
from parsers.parse_vuizur import parse_vuizur
from parsers.parse_compact import parse_compact
from parsers.parse_herve import parse_herve
from parsers.parse_uzwordnet import parse_uzwordnet
from parsers.parse_kodchi import parse_kodchi
from parsers.parse_common import parse_common
from parsers.parse_nurullon import parse_nurullon
from parsers.parse_knightss27 import parse_knightss27
from parsers.parse_essential import parse_essential

PROJECT_DIR = os.path.join(os.path.dirname(__file__), "..")
DB_PATH = os.path.join(PROJECT_DIR, "saved_database", "topsoz.db")


def create_schema(conn):
    """Baza sxemasini yaratish."""
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL,
            word_cyrillic TEXT,
            language TEXT NOT NULL CHECK(language IN ('uz','en','ru')),
            part_of_speech TEXT DEFAULT '',
            pronunciation TEXT DEFAULT '',
            etymology TEXT DEFAULT '',
            source TEXT NOT NULL DEFAULT '',
            UNIQUE(word, language, part_of_speech, source)
        );

        CREATE TABLE IF NOT EXISTS definitions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
            definition TEXT NOT NULL,
            target_language TEXT NOT NULL CHECK(target_language IN ('uz','en','ru','')),
            example_source TEXT DEFAULT '',
            example_target TEXT DEFAULT '',
            sort_order INTEGER DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS favorites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL UNIQUE REFERENCES words(id) ON DELETE CASCADE,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS search_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query TEXT NOT NULL,
            word_id INTEGER REFERENCES words(id),
            searched_at TEXT NOT NULL DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            value TEXT
        );
    """)


def create_indexes(conn):
    """Indekslar yaratish."""
    conn.executescript("""
        CREATE INDEX IF NOT EXISTS idx_words_lang ON words(language);
        CREATE INDEX IF NOT EXISTS idx_words_word ON words(word COLLATE NOCASE);
        CREATE INDEX IF NOT EXISTS idx_words_cyrillic ON words(word_cyrillic);
        CREATE INDEX IF NOT EXISTS idx_defs_word ON definitions(word_id);
        CREATE INDEX IF NOT EXISTS idx_defs_lang_word ON definitions(target_language, word_id);
        CREATE INDEX IF NOT EXISTS idx_fav_created ON favorites(created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_hist_searched ON search_history(searched_at DESC);
    """)


def insert_entries(conn, all_entries):
    """Yozuvlarni bazaga kiritish (deduplikatsiya bilan)."""
    cursor = conn.cursor()
    word_count = 0
    def_count = 0
    skipped = 0

    for entry in all_entries:
        word = entry["word"].strip()
        if not word:
            continue

        language = entry.get("language", "uz")
        pos = entry.get("pos", "")
        source = entry.get("source", "")
        pronunciation = entry.get("pronunciation", "")
        etymology = entry.get("etymology", "")

        # Kirill variant generatsiya (faqat o'zbek, lotin yozuvdagi so'zlar uchun)
        word_cyrillic = ""
        if language == "uz" and not is_cyrillic(word):
            word_cyrillic = latin_to_cyrillic(word)
        elif language == "uz" and is_cyrillic(word):
            word_cyrillic = word

        # So'zni kiritish
        try:
            cursor.execute("""
                INSERT INTO words (word, word_cyrillic, language, part_of_speech,
                                   pronunciation, etymology, source)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (word, word_cyrillic, language, pos, pronunciation, etymology, source))
            word_id = cursor.lastrowid
            word_count += 1
        except sqlite3.IntegrityError:
            # Dublikat — mavjud word_id ni olish
            cursor.execute("""
                SELECT id FROM words
                WHERE word = ? AND language = ? AND part_of_speech = ? AND source = ?
            """, (word, language, pos, source))
            row = cursor.fetchone()
            if row:
                word_id = row[0]
            else:
                skipped += 1
                continue

        # Ta'riflarni kiritish
        definitions = entry.get("definitions", [])
        target_lang = entry.get("target_language", "en")

        for i, defn in enumerate(definitions):
            defn = defn.strip() if isinstance(defn, str) else str(defn).strip()
            defn = clean_html(defn)
            if not defn:
                continue

            # Dublikat ta'rifni tekshirish
            cursor.execute("""
                SELECT id FROM definitions
                WHERE word_id = ? AND definition = ? AND target_language = ?
            """, (word_id, defn, target_lang))
            if cursor.fetchone():
                continue

            # Misol jumlalar
            examples = entry.get("examples", [])
            ex_src = ""
            ex_tgt = ""
            if i < len(examples):
                ex = examples[i]
                if isinstance(ex, (tuple, list)) and len(ex) >= 1:
                    ex_src = clean_html(ex[0])
                    ex_tgt = clean_html(ex[1]) if len(ex) > 1 else ""

            cursor.execute("""
                INSERT INTO definitions (word_id, definition, target_language,
                                         example_source, example_target, sort_order)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (word_id, defn, target_lang, ex_src, ex_tgt, i))
            def_count += 1

    conn.commit()
    return word_count, def_count, skipped


def build():
    """Bazani yaratish va to'ldirish."""
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

    # Mavjud bazani o'chirish
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute("PRAGMA foreign_keys=ON")

    print("=" * 60)
    print("TOPSO'Z LUG'AT BAZASI YARATILMOQDA")
    print("=" * 60)

    # 1. Sxema yaratish
    print("\n[1/6] Sxema yaratilmoqda...")
    create_schema(conn)

    # 2. Barcha manbalarni parse qilish
    print("\n[2/6] Manbalar parse qilinmoqda...")
    all_entries = []

    parsers = [
        ("Kaikki", parse_kaikki),
        ("Vuizur", parse_vuizur),
        ("UzWordnet", parse_uzwordnet),
        ("Herve-Guerin", parse_herve),
        ("Compact", parse_compact),
        ("Kodchi", parse_kodchi),
        ("Common Words", parse_common),
        ("Nurullon", parse_nurullon),
        ("Knightss27", parse_knightss27),
        ("Essential", parse_essential),
    ]

    for name, parser_fn in parsers:
        try:
            entries = parser_fn()
            all_entries.extend(entries)
            print(f"  {name}: {len(entries)} ta yozuv")
        except Exception as e:
            print(f"  {name}: XATO — {e}")

    print(f"\n  JAMI: {len(all_entries)} ta yozuv barcha manbalardan")

    # 3. Bazaga kiritish
    print("\n[3/6] Bazaga kiritilmoqda...")
    word_count, def_count, skipped = insert_entries(conn, all_entries)
    print(f"  So'zlar: {word_count}")
    print(f"  Ta'riflar: {def_count}")
    print(f"  O'tkazib yuborilgan: {skipped}")

    # 4. Indekslar
    print("\n[4/6] Indekslar yaratilmoqda...")
    create_indexes(conn)

    # 5. FTS5
    print("\n[5/6] FTS5 qidiruv indeksi yaratilmoqda...")
    rebuild_search_index(conn)

    # 6. Optimallashtirish
    print("\n[6/6] Optimallashtirish...")
    conn.execute("ANALYZE")
    conn.execute("VACUUM")

    # Meta ma'lumot
    import datetime
    conn.execute("INSERT OR REPLACE INTO meta VALUES ('version', ?)", (DB_VERSION,))
    conn.execute("INSERT OR REPLACE INTO meta VALUES ('built_at', ?)",
                 (datetime.datetime.now().isoformat(),))
    conn.execute("INSERT OR REPLACE INTO meta VALUES ('word_count', ?)", (str(word_count),))
    conn.execute("INSERT OR REPLACE INTO meta VALUES ('definition_count', ?)", (str(def_count),))
    conn.commit()

    # Statistika
    print("\n" + "=" * 60)
    print("YAKUNIY STATISTIKA")
    print("=" * 60)

    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM words")
    total_words = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM definitions")
    total_defs = cursor.fetchone()[0]
    cursor.execute("SELECT language, COUNT(*) FROM words GROUP BY language")
    by_lang = cursor.fetchall()
    cursor.execute("SELECT source, COUNT(*) FROM words GROUP BY source")
    by_source = cursor.fetchall()
    cursor.execute("SELECT COUNT(*) FROM words WHERE word_cyrillic != '' AND word_cyrillic IS NOT NULL")
    cyrillic_count = cursor.fetchone()[0]

    print(f"\n  Jami so'zlar: {total_words}")
    print(f"  Jami ta'riflar: {total_defs}")
    print(f"  Kirill varianti bor: {cyrillic_count}")
    print(f"\n  Tillar bo'yicha:")
    for lang, count in by_lang:
        print(f"    {lang}: {count}")
    print(f"\n  Manbalar bo'yicha:")
    for source, count in by_source:
        print(f"    {source}: {count}")

    db_size = os.path.getsize(DB_PATH)
    print(f"\n  Baza hajmi: {db_size / 1024 / 1024:.2f} MB")
    print(f"  Fayl: {DB_PATH}")

    conn.close()
    print("\nBaza muvaffaqiyatli yaratildi!")


if __name__ == "__main__":
    build()
