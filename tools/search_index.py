"""
Qidiruv indeksini qurish uchun umumiy yordamchilar.
"""
import re

DB_VERSION = "2.0.0"

_APOSTROPHE_RE = re.compile(r"[\u02BB\u02BC`\u2018\u2019\u2032]")
_WHITESPACE_RE = re.compile(r"\s+")


def normalize_apostrophes(text):
    """Barcha apostrof variantlarini bitta ko'rinishga keltirish."""
    if not text:
        return ""
    return _APOSTROPHE_RE.sub("'", text)


def normalize_search_text(text):
    """FTS uchun matnni tayyorlash: apostrof + bo'shliqlar + lowercase."""
    normalized = normalize_apostrophes(text)
    normalized = _WHITESPACE_RE.sub(" ", normalized).strip()
    return normalized.lower()


def fold_headword(text):
    """Apostrofsiz lemma shakli."""
    return normalize_search_text(text).replace("'", "")


def register_search_functions(conn):
    """SQLite ichida ishlatish uchun yordamchi funksiyalarni ro'yxatdan o'tkazish."""
    conn.create_function("normalize_search_text", 1, normalize_search_text)
    conn.create_function("fold_headword", 1, fold_headword)


def rebuild_search_index(conn):
    """Yangi FTS5 indeksini qayta qurish."""
    register_search_functions(conn)

    conn.execute("DROP TABLE IF EXISTS words_fts")
    conn.execute("""
        CREATE VIRTUAL TABLE words_fts USING fts5(
            word,
            word_cyrillic,
            word_folded,
            definitions_en,
            definitions_ru,
            definitions_all,
            tokenize='unicode61 remove_diacritics 2 tokenchars ''''',
            prefix='2 3 4'
        )
    """)

    conn.execute("""
        INSERT INTO words_fts(
            rowid,
            word,
            word_cyrillic,
            word_folded,
            definitions_en,
            definitions_ru,
            definitions_all
        )
        SELECT
            w.id,
            normalize_search_text(w.word),
            normalize_search_text(COALESCE(w.word_cyrillic, '')),
            fold_headword(w.word),
            COALESCE(
                GROUP_CONCAT(
                    CASE
                        WHEN d.target_language = 'en'
                        THEN normalize_search_text(d.definition)
                    END,
                    ' | '
                ),
                ''
            ),
            COALESCE(
                GROUP_CONCAT(
                    CASE
                        WHEN d.target_language = 'ru'
                        THEN normalize_search_text(d.definition)
                    END,
                    ' | '
                ),
                ''
            ),
            COALESCE(
                GROUP_CONCAT(normalize_search_text(d.definition), ' | '),
                ''
            )
        FROM words w
        LEFT JOIN definitions d ON d.word_id = w.id
        GROUP BY w.id
    """)
    conn.commit()
