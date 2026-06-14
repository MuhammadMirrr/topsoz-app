"""
Baza post-protsessing yordamchilari (build/enrich va mavjud bazani tozalash
uchun umumiy). Faqat `transliterate` (yengil) va `sqlite3` ga bog'liq —
shuning uchun og'ir parser bog'liqliklarini (bs4 va h.k.) tortib kelmaydi.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from transliterate import cyrillic_to_latin

_WHITESPACE_RE = re.compile(r"\s+")


def _has_cyrillic(text):
    return any("Ѐ" <= ch <= "ӿ" for ch in (text or ""))


def canonicalize_headwords(conn):
    """`word` ustunini kanonik shaklga keltiradi va dublikatlarni birlashtiradi.

    Ikki muammoni hal qiladi (ikkalasi ham qidiruvda DUBLIKAT natija keltiradi,
    chunki dedup `word` matni bo'yicha guruhlaydi):

    1. KIRILL `word`: ba'zi manbalar (ayniqsa kodchi) Lotin bo'lishi kerak
       bo'lgan `word` ustuniga Kirill so'zni yozadi (masalan "олтин").
       Kirillni Lotinga o'giramiz, asl Kirillni `word_cyrillic` ga ko'chiramiz.
    2. ORTIQCHA BO'SHLIQ: ko'p so'zli headword'larda ikki/chekka bo'shliq
       ("azob  bermoq") — siqib bitta bo'shliqqa keltiramiz (Dart-dagi
       _normalizeSearchText bilan parity uchun, getWord sibling-merge ishlashi
       uchun).

    UNIQUE(word, language, part_of_speech, source) to'qnashsa — ta'riflar
    mavjud qatorga ko'chiriladi, ortiqchasi o'chiriladi. Lotinda bo'shga
    aylanadigan yolg'iz belgilar (ь, ъ) butunlay o'chiriladi.

    Idempotent: ikkinchi marta ishga tushirilsa hech narsa o'zgartirmaydi.
    """
    cur = conn.cursor()
    # Deterministik tartib (id bo'yicha) — qayta ishga tushirilsa bir xil natija.
    rows = cur.execute(
        "SELECT id, word, COALESCE(word_cyrillic,''), COALESCE(language,'uz'), "
        "COALESCE(part_of_speech,''), COALESCE(source,'') FROM words ORDER BY id"
    ).fetchall()

    updated = 0
    merged = 0
    dropped = 0
    for wid, word, wcyr, lang, pos, source in rows:
        is_cyr = _has_cyrillic(word)
        latin = cyrillic_to_latin(word) if is_cyr else word
        new_word = _WHITESPACE_RE.sub(" ", latin).strip()
        # Kirill `word` bo'lsa, asl (bo'shlig'i siqilgan) Kirillni saqlaymiz.
        new_cyr = _WHITESPACE_RE.sub(" ", word if is_cyr else wcyr).strip()

        if new_word == word and new_cyr == wcyr:
            continue  # allaqachon kanonik (idempotentlik)

        # Lotinda mazmunsiz qoladigan yolg'iz belgilar (ь, ъ) — axlat.
        if not new_word.strip(" '"):
            cur.execute("DELETE FROM words WHERE id = ?", (wid,))
            dropped += 1
            continue

        # `word` o'zgargan bo'lsa: xuddi shu UNIQUE kalit bilan MAVJUD qator
        # bormi? Bo'lsa — ta'riflarni unga ko'chirib, joriy qatorni o'chiramiz.
        if new_word != word:
            target = cur.execute(
                "SELECT id FROM words WHERE word = ? AND COALESCE(language,'uz') = ? "
                "AND COALESCE(part_of_speech,'') = ? AND COALESCE(source,'') = ? "
                "AND id != ? LIMIT 1",
                (new_word, lang, pos, source, wid),
            ).fetchone()
            if target:
                cur.execute(
                    "UPDATE definitions SET word_id = ? WHERE word_id = ?",
                    (target[0], wid),
                )
                cur.execute("DELETE FROM words WHERE id = ?", (wid,))
                merged += 1
                continue

        cur.execute(
            "UPDATE words SET word = ?, word_cyrillic = ? WHERE id = ?",
            (new_word, new_cyr, wid),
        )
        updated += 1

    # Birlashtirishdan kelib chiqqan bir xil ta'riflarni olib tashlash.
    # MUHIM: misolli (example_source/target) qatorni afzal saqlaymiz —
    # aks holda Tatoeba misoli yo'qolishi mumkin (ikki bir xil ta'rifdan
    # faqat kattaroq id da misol bo'lsa). Shuning uchun MIN(id) emas, balki
    # avval misol borligi, keyin id bo'yicha tartiblab birinchisini qoldiramiz.
    cur.execute(
        "DELETE FROM definitions WHERE id NOT IN ("
        "  SELECT id FROM ("
        "    SELECT id, ROW_NUMBER() OVER ("
        "      PARTITION BY word_id, definition, target_language "
        "      ORDER BY ("
        "        CASE WHEN COALESCE(example_source,'') <> '' "
        "                  OR COALESCE(example_target,'') <> '' THEN 0 ELSE 1 END"
        "      ), id"
        "    ) AS rn FROM definitions"
        "  ) WHERE rn = 1)"
    )
    dedup = cur.rowcount
    conn.commit()
    print(
        f"  Headword kanonikalashtirish: {updated} tuzatildi, "
        f"{merged} to'qnashuv birlashtirildi, {dropped} bo'sh-translit o'chirildi, "
        f"{dedup} ortiqcha ta'rif o'chirildi"
    )
    return {
        "updated": updated,
        "merged": merged,
        "dropped": dropped,
        "dedup": dedup,
    }


def prune_definitionless_words(conn):
    """Ta'rifi bo'lmagan so'zlarni o'chiradi.

    Ilova ta'rifsiz so'zni ko'rsata olmaydi: qidiruv natijasida ular
    tashlanadi (bo'sh preview), "kun so'zi" ham ta'rif talab qiladi, va
    ularga navigatsiya yo'li yo'q. Shuning uchun ular faqat o'lik yuk —
    bazani va FTS indeksini behuda kattalashtiradi. Bu qadam barcha
    enrichmentdan KEYIN, FTS qayta qurishdan OLDIN ishlaydi.
    """
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM words")
    before = cur.fetchone()[0]
    cur.execute(
        "DELETE FROM words WHERE NOT EXISTS ("
        "  SELECT 1 FROM definitions d WHERE d.word_id = words.id)"
    )
    deleted = cur.rowcount
    conn.commit()
    cur.execute("SELECT COUNT(*) FROM words")
    after = cur.fetchone()[0]
    print(f"  Ta'rifsiz so'zlar o'chirildi: {deleted} ({before} -> {after})")
    return deleted
