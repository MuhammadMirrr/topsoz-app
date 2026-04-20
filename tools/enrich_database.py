"""
Bazani boyitish — mavjud so'zlarga inglizcha/ruscha tarjimalar va misollar qo'shish.
build_database.py dan KEYIN ishga tushiriladi.

Manbalar:
  1. English WordNet + UzWordnet — synset orqali ~20,000 so'zga inglizcha ta'rif
  2. Kaikki re-match — kodchi so'zlarni kaikki bilan moslashtirish
  3. Tatoeba — O'zbek-Ingliz juft gaplar (misollar)
  4. OpenRussian — Ruscha tarjimalar (inglizcha ko'prik orqali)
"""
import os
import sys
import csv
import json
import bz2
import tarfile
import io
import re
import sqlite3
import xml.etree.ElementTree as ET
from collections import defaultdict

sys.path.insert(0, os.path.dirname(__file__))
from transliterate import latin_to_cyrillic, is_cyrillic
from search_index import DB_VERSION, rebuild_search_index
from build_database import clean_html

PROJECT_DIR = os.path.join(os.path.dirname(__file__), "..")
RAW_DIR = os.path.join(PROJECT_DIR, "raw_data")
DB_PATH = os.path.join(PROJECT_DIR, "saved_database", "topsoz.db")

# ═════════════════════════════════════════════════════════════════
# 1. ENGLISH WORDNET — synset offset → inglizcha ta'rif
# ═════════════════════════════════════════════════════════════════

POS_FILE_MAP = {"n": "data.noun", "v": "data.verb", "a": "data.adj", "r": "data.adv", "s": "data.adj"}


def load_wordnet_glosses():
    """Princeton WordNet data fayllaridan synset offset → gloss mapping."""
    wn_dir = os.path.join(RAW_DIR, "wordnet")
    glosses = {}  # (offset_int, pos) → gloss

    for pos_code, filename in [("n", "data.noun"), ("v", "data.verb"),
                                ("a", "data.adj"), ("r", "data.adv")]:
        filepath = os.path.join(wn_dir, filename)
        if not os.path.exists(filepath):
            print(f"  [OGOHLANTIRISH] {filepath} topilmadi")
            continue

        with open(filepath, "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("  "):  # Header/comment
                    continue
                # Format: offset lex_filenum ss_type w_cnt word ... | gloss
                pipe_idx = line.find("|")
                if pipe_idx < 0:
                    continue
                parts = line[:pipe_idx].split()
                if len(parts) < 4:
                    continue
                try:
                    offset = int(parts[0])
                except ValueError:
                    continue

                gloss = line[pipe_idx + 1:].strip()
                # Misollarni ajratish ("; " dan keyin "..." bor qism)
                gloss_clean = gloss.split(";")[0].strip() if ";" in gloss else gloss
                # Juda uzun glosslarni qisqartirish
                if len(gloss_clean) > 300:
                    gloss_clean = gloss_clean[:297] + "..."

                glosses[(offset, pos_code)] = gloss_clean

    print(f"  [WORDNET] {len(glosses)} ta synset ta'rifi yuklandi")
    return glosses


# ═════════════════════════════════════════════════════════════════
# 2. UZWORDNET — so'z → synset → inglizcha ta'rif
# ═════════════════════════════════════════════════════════════════

def parse_uzwordnet_synsets():
    """UzWordnet XML dan so'z-synset bog'lanishlarini va o'zbek ta'riflarni olish."""
    xml_path = os.path.join(RAW_DIR, "uzwordnet", "files", "uzwordnet.xml")
    if not os.path.exists(xml_path):
        print("  [XATO] uzwordnet.xml topilmadi")
        return {}, {}

    tree = ET.parse(xml_path)
    root = tree.getroot()

    # Synset ta'riflarini olish (o'zbek tilida)
    synset_uz_defs = {}  # synset_id → uz_definition
    for synset_elem in root.iter("Synset"):
        sid = synset_elem.get("id", "")
        for defn in synset_elem:
            if defn.tag == "Definition":
                text = defn.text
                if text:
                    synset_uz_defs[sid] = text.strip()
                break

    # So'z → synset mappinglar
    word_synsets = defaultdict(list)  # word → [(synset_id, pos)]
    for entry in root.iter("LexicalEntry"):
        lemma_el = entry.find("Lemma")
        if lemma_el is None:
            continue
        word = lemma_el.get("writtenForm", "").strip()
        pos = lemma_el.get("partOfSpeech", "")
        if not word:
            continue

        for sense in entry.iter("Sense"):
            synset_ref = sense.get("synset", "")
            if synset_ref:
                word_synsets[word.lower()].append((synset_ref, pos))

    print(f"  [UZWORDNET] {len(word_synsets)} so'z, {len(synset_uz_defs)} synset ta'rifi")
    return word_synsets, synset_uz_defs


def extract_offset_pos(synset_id):
    """'uzwordnet-1740-n' → (1740, 'n')"""
    m = re.match(r"uzwordnet-(\d+)-([nvasr])", synset_id)
    if m:
        return int(m.group(1)), m.group(2)
    return None, None


# ═════════════════════════════════════════════════════════════════
# 3. KAIKKI RE-MATCH — ta'rifsiz so'zlarni kaikki bilan moslashtirish
# ═════════════════════════════════════════════════════════════════

def load_kaikki_definitions():
    """Kaikki JSONL dan so'z → ta'riflar lug'ati."""
    filepath = os.path.join(RAW_DIR, "kaikki-uzbek.jsonl")
    if not os.path.exists(filepath):
        return {}

    word_defs = defaultdict(list)  # word_lower → [(definition, pos)]
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            word = obj.get("word", "").strip()
            if not word or obj.get("lang_code") != "uz":
                continue

            pos = obj.get("pos", "")
            for sense in obj.get("senses", []):
                for gloss in sense.get("glosses", []):
                    if gloss:
                        word_defs[word.lower()].append((gloss, pos))

    print(f"  [KAIKKI] {len(word_defs)} so'z ta'riflari yuklandi")
    return word_defs


# ═════════════════════════════════════════════════════════════════
# 4. TATOEBA — O'zbek-Ingliz juft gaplar
# ═════════════════════════════════════════════════════════════════

def load_tatoeba_sentences():
    """Tatoeba dan O'zbek va Ingliz gaplarni yuklash va bog'lash."""
    uzb_path = os.path.join(RAW_DIR, "tatoeba-uzb.tsv.bz2")
    eng_path = os.path.join(RAW_DIR, "tatoeba-eng.tsv.bz2")
    links_path = os.path.join(RAW_DIR, "tatoeba-links.tar.bz2")

    if not all(os.path.exists(p) for p in [uzb_path, eng_path, links_path]):
        print("  [XATO] Tatoeba fayllari topilmadi")
        return []

    # O'zbek gaplar
    uz_sentences = {}  # id → text
    with bz2.open(uzb_path, "rt", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) >= 3:
                uz_sentences[parts[0]] = parts[2]

    print(f"  [TATOEBA] {len(uz_sentences)} o'zbek gap yuklandi")
    uz_ids = set(uz_sentences.keys())

    # Links — faqat o'zbek gap ID lariga tegishli linklar
    uz_links = defaultdict(set)  # uz_id → {linked_id, ...}
    print("  [TATOEBA] links.csv qayta ishlanmoqda (katta fayl)...")
    with open(links_path, "rb") as f:
        with tarfile.open(fileobj=f, mode="r:bz2") as tar:
            for member in tar.getmembers():
                ef = tar.extractfile(member)
                if not ef:
                    continue
                for raw_line in ef:
                    line = raw_line.decode("utf-8", errors="ignore").strip()
                    parts = line.split("\t")
                    if len(parts) >= 2:
                        if parts[0] in uz_ids:
                            uz_links[parts[0]].add(parts[1])
                        elif parts[1] in uz_ids:
                            uz_links[parts[1]].add(parts[0])

    # Ingliz gaplar — faqat bizga kerak bo'lganlar
    needed_ids = set()
    for linked in uz_links.values():
        needed_ids.update(linked)

    print(f"  [TATOEBA] {len(needed_ids)} ingliz gap ID kerak")

    eng_sentences = {}
    with bz2.open(eng_path, "rt", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) >= 3 and parts[0] in needed_ids:
                eng_sentences[parts[0]] = parts[2]

    print(f"  [TATOEBA] {len(eng_sentences)} ingliz gap topildi")

    # Juft gaplar yaratish
    pairs = []
    for uz_id, uz_text in uz_sentences.items():
        for linked_id in uz_links.get(uz_id, []):
            if linked_id in eng_sentences:
                pairs.append((uz_text, eng_sentences[linked_id]))

    print(f"  [TATOEBA] {len(pairs)} juft gap topildi")
    return pairs


# ═════════════════════════════════════════════════════════════════
# 5. OPENRUSSIAN — Ruscha so'z → inglizcha tarjima
# ═════════════════════════════════════════════════════════════════

def load_openrussian():
    """OpenRussian CSV lardan ruscha-inglizcha tarjimalarni olish."""
    openrussian_dir = os.path.join(RAW_DIR, "openrussian")
    if not os.path.exists(openrussian_dir):
        print("  [XATO] OpenRussian papkasi topilmadi")
        return {}

    # en_word_lower → [(russian_word, pos)]
    en_to_ru = defaultdict(list)
    total = 0

    pos_map = {
        "nouns.csv": "noun",
        "verbs.csv": "verb",
        "adjectives.csv": "adj",
        "others.csv": "",
    }

    for csv_name, pos in pos_map.items():
        filepath = os.path.join(openrussian_dir, csv_name)
        if not os.path.exists(filepath):
            continue

        with open(filepath, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f, delimiter="\t")
            for row in reader:
                ru_word = row.get("bare", "").strip()
                en_trans = row.get("translations_en", "").strip()
                if not ru_word or not en_trans:
                    continue

                # Ingliz tarjimalar vergul bilan ajratilgan
                for en_part in en_trans.split(","):
                    en_part = en_part.strip().lower()
                    # Qavslar va izohlarni olib tashlash
                    en_part = re.sub(r"\s*\(.*?\)\s*", " ", en_part).strip()
                    en_part = re.sub(r"\s*\[.*?\]\s*", " ", en_part).strip()
                    if en_part and len(en_part) > 1:
                        en_to_ru[en_part].append((ru_word, pos))
                        total += 1

    print(f"  [OPENRUSSIAN] {len(en_to_ru)} inglizcha kalit, {total} jami bog'lanish")
    return en_to_ru


# ═════════════════════════════════════════════════════════════════
# ASOSIY ENRICHMENT
# ═════════════════════════════════════════════════════════════════

def add_definition(cursor, word_id, definition, target_language, source_tag="",
                   example_source="", example_target="", sort_order=0):
    """Yangi ta'rif qo'shish (HTML tozalab, dublikat tekshirish bilan)."""
    definition = clean_html(definition)
    if not definition:
        return False
    example_source = clean_html(example_source)
    example_target = clean_html(example_target)

    cursor.execute("""
        SELECT id FROM definitions
        WHERE word_id = ? AND definition = ? AND target_language = ?
    """, (word_id, definition, target_language))
    if cursor.fetchone():
        return False

    cursor.execute("""
        INSERT INTO definitions (word_id, definition, target_language,
                                 example_source, example_target, sort_order)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (word_id, definition, target_language, example_source, example_target, sort_order))
    return True


def enrich():
    if not os.path.exists(DB_PATH):
        print("[XATO] Baza topilmadi! Avval build_database.py ni ishga tushiring.")
        return

    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute("PRAGMA foreign_keys=ON")
    cursor = conn.cursor()

    print("=" * 60)
    print("TOPSO'Z BAZASI BOYITILMOQDA")
    print("=" * 60)

    # ─── Boshlang'ich statistika ───
    cursor.execute("SELECT COUNT(*) FROM words")
    total_words = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM definitions")
    initial_defs = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(DISTINCT word_id) FROM definitions")
    initial_with_defs = cursor.fetchone()[0]
    print(f"\nBoshlang'ich holat: {total_words} so'z, {initial_defs} ta'rif, "
          f"{initial_with_defs} so'zda ta'rif bor ({initial_with_defs*100//total_words}%)")

    # ─── Barcha so'zlarni yuklash ───
    cursor.execute("SELECT id, word, source, part_of_speech FROM words WHERE language = 'uz'")
    all_words = cursor.fetchall()
    word_lookup = defaultdict(list)  # word_lower → [(id, source, pos)]
    for wid, word, source, pos in all_words:
        word_lookup[word.lower()].append((wid, source, pos))

    # So'zlar ta'rifsiz
    cursor.execute("""
        SELECT w.id, w.word, w.source FROM words w
        WHERE w.language = 'uz'
        AND NOT EXISTS (SELECT 1 FROM definitions d WHERE d.word_id = w.id)
    """)
    words_without_defs = cursor.fetchall()
    no_def_lookup = defaultdict(list)  # word_lower → [(id, source)]
    for wid, word, source in words_without_defs:
        no_def_lookup[word.lower()].append((wid, source))

    print(f"Ta'rifsiz so'zlar: {len(words_without_defs)}")

    # ═══════════════════════════════════════════
    # QADAM 1: UzWordnet + English WordNet
    # ═══════════════════════════════════════════
    print(f"\n{'─'*60}")
    print("[1/4] UzWordnet + English WordNet orqali boyitish...")

    wn_glosses = load_wordnet_glosses()
    word_synsets, synset_uz_defs = parse_uzwordnet_synsets()

    en_added_wn = 0
    words_enriched_wn = set()

    for word_lower, synset_list in word_synsets.items():
        word_entries = word_lookup.get(word_lower, [])
        if not word_entries:
            continue

        for synset_id, pos in synset_list:
            offset, pos_code = extract_offset_pos(synset_id)
            if offset is None:
                continue

            # Inglizcha ta'rif
            en_gloss = wn_glosses.get((offset, pos_code), "")
            if not en_gloss:
                # Satellite adj -> regular adj
                if pos_code == "s":
                    en_gloss = wn_glosses.get((offset, "a"), "")
                if not en_gloss:
                    continue

            # Barcha mos so'zlarga qo'shish
            for wid, source, wpos in word_entries:
                if add_definition(cursor, wid, en_gloss, "en",
                                  sort_order=100):
                    en_added_wn += 1
                    words_enriched_wn.add(wid)

    conn.commit()
    print(f"  Natija: {en_added_wn} inglizcha ta'rif qo'shildi, "
          f"{len(words_enriched_wn)} so'z boyitildi")

    # ═══════════════════════════════════════════
    # QADAM 2: Kaikki re-match
    # ═══════════════════════════════════════════
    print(f"\n{'─'*60}")
    print("[2/4] Kaikki re-match (ta'rifsiz so'zlarni moslashtirish)...")

    kaikki_defs = load_kaikki_definitions()

    en_added_kaikki = 0
    words_enriched_kaikki = set()

    for word_lower, entries in no_def_lookup.items():
        if word_lower not in kaikki_defs:
            continue

        for defn, kaikki_pos in kaikki_defs[word_lower]:
            for wid, source in entries:
                if wid in words_enriched_wn:
                    continue  # Allaqachon WordNet dan boyitilgan
                if add_definition(cursor, wid, defn, "en",
                                  sort_order=50):
                    en_added_kaikki += 1
                    words_enriched_kaikki.add(wid)

    conn.commit()
    print(f"  Natija: {en_added_kaikki} ta'rif qo'shildi, "
          f"{len(words_enriched_kaikki)} so'z boyitildi")

    # ═══════════════════════════════════════════
    # QADAM 3: Tatoeba juft gaplar
    # ═══════════════════════════════════════════
    print(f"\n{'─'*60}")
    print("[3/4] Tatoeba juft gaplar (misollar)...")

    pairs = load_tatoeba_sentences()
    examples_added = 0
    words_with_examples = set()

    for uz_text, en_text in pairs:
        # O'zbek gapdagi so'zlarni aniqlash
        uz_words = re.findall(r"[a-zA-Zа-яА-ЯёЁғҒқҚҳҲўЎ\u02BB\u02BC'`ʻʼ]+", uz_text.lower())

        for uz_word in uz_words:
            if len(uz_word) < 3:
                continue
            word_entries = word_lookup.get(uz_word, [])
            for wid, source, pos in word_entries:
                # Mavjud ta'riflarga misol qo'shish yoki yangi ta'rif yaratish
                cursor.execute("""
                    SELECT id FROM definitions
                    WHERE word_id = ? AND example_source = ?
                """, (wid, uz_text))
                if cursor.fetchone():
                    continue

                # Mavjud ta'rifga misol qo'shish (birinchi misolsiz ta'rif)
                cursor.execute("""
                    SELECT id FROM definitions
                    WHERE word_id = ? AND example_source = ''
                    LIMIT 1
                """, (wid,))
                existing = cursor.fetchone()
                if existing:
                    cursor.execute("""
                        UPDATE definitions
                        SET example_source = ?, example_target = ?
                        WHERE id = ?
                    """, (uz_text, en_text, existing[0]))
                    examples_added += 1
                    words_with_examples.add(wid)
                else:
                    # Yangi definition sifatida qo'shish
                    if add_definition(cursor, wid, en_text, "en",
                                      example_source=uz_text,
                                      example_target=en_text,
                                      sort_order=200):
                        examples_added += 1
                        words_with_examples.add(wid)
                break  # Har bir so'z uchun bir marta

    conn.commit()
    print(f"  Natija: {examples_added} misol qo'shildi, "
          f"{len(words_with_examples)} so'zda yangi misol bor")

    # ═══════════════════════════════════════════
    # QADAM 4: OpenRussian — ruscha tarjimalar
    # ═══════════════════════════════════════════
    print(f"\n{'─'*60}")
    print("[4/4] OpenRussian ruscha tarjimalar (inglizcha ko'prik)...")

    en_to_ru = load_openrussian()

    # Bazadagi inglizcha ta'riflarni olish
    cursor.execute("""
        SELECT d.word_id, d.definition FROM definitions d
        JOIN words w ON w.id = d.word_id
        WHERE w.language = 'uz' AND d.target_language = 'en'
    """)
    en_definitions = cursor.fetchall()

    ru_added = 0
    words_with_ru = set()

    for word_id, en_def in en_definitions:
        # Inglizcha ta'rifni normalizatsiya
        en_lower = en_def.lower().strip()

        # To'g'ridan-to'g'ri moslik
        ru_matches = en_to_ru.get(en_lower, [])

        # Agar to'g'ri mos kelmasa, birinchi so'z/ibora bilan moslashtirish
        if not ru_matches:
            # "something; other thing" → "something"
            first_part = en_lower.split(";")[0].strip()
            ru_matches = en_to_ru.get(first_part, [])

        if not ru_matches:
            # Juda uzun ta'riflar uchun skip
            if len(en_lower) > 50:
                continue
            # Oddiy so'zlar uchun moslashtirish
            clean = re.sub(r"[^a-z\s]", "", en_lower).strip()
            ru_matches = en_to_ru.get(clean, [])

        if not ru_matches:
            continue

        # Eng ko'pi bilan 3 ta ruscha tarjima
        seen_ru = set()
        for ru_word, ru_pos in ru_matches[:3]:
            if ru_word in seen_ru:
                continue
            seen_ru.add(ru_word)
            if add_definition(cursor, word_id, ru_word, "ru",
                              sort_order=150):
                ru_added += 1
                words_with_ru.add(word_id)

    conn.commit()
    print(f"  Natija: {ru_added} ruscha tarjima qo'shildi, "
          f"{len(words_with_ru)} so'zda ruscha tarjima bor")

    # ═══════════════════════════════════════════
    # QADAM 5: Kodchi Cyrillic so'zlarni tozalash va cross-reference
    # ═══════════════════════════════════════════
    print(f"\n{'─'*60}")
    print("[5/5] Kodchi Cyrillic so'zlarni tozalash va Latin cross-reference...")

    from transliterate import cyrillic_to_latin

    # Kodchi ta'rifsiz so'zlarni olish
    cursor.execute("""
        SELECT w.id, w.word FROM words w
        WHERE w.source = 'kodchi'
        AND NOT EXISTS (SELECT 1 FROM definitions d WHERE d.word_id = w.id)
    """)
    kodchi_no_def = cursor.fetchall()

    kodchi_cleaned = 0
    kodchi_enriched = 0
    kodchi_enriched_set = set()

    # Ta'rifli so'zlar lookup: latin_lower → [defs]
    cursor.execute("""
        SELECT w.word, d.definition, d.target_language FROM words w
        JOIN definitions d ON d.word_id = w.id
        WHERE w.language = 'uz'
    """)
    latin_defs = defaultdict(list)  # word_lower → [(def, target_lang)]
    for w, d, tl in cursor.fetchall():
        latin_defs[w.lower()].append((d, tl))

    for wid, raw_word in kodchi_no_def:
        # Tab bilan ajratilgan formatni tozalash: "абад\tо,р" → "абад"
        clean_word = raw_word.split("\t")[0].strip()
        if clean_word.startswith("*") or not clean_word:
            continue

        # So'zni yangilash (bazada tozalash)
        if clean_word != raw_word:
            try:
                clean_cyrillic = clean_word if any('\u0400' <= ch <= '\u04ff' for ch in clean_word) else ""
                cursor.execute("""
                    UPDATE words SET word = ?, word_cyrillic = ?
                    WHERE id = ?
                """, (clean_word, clean_cyrillic, wid))
                kodchi_cleaned += 1
            except sqlite3.IntegrityError:
                # Dublikat — bu so'z allaqachon bor, shu entry ni o'chirish mumkin
                continue

        # Cyrillic → Latin transliteratsiya
        latin_form = cyrillic_to_latin(clean_word).lower()

        # Latin forma bilan ta'rif qidirish
        matched_defs = latin_defs.get(latin_form, [])
        if not matched_defs:
            # Apostrof variatsiyalari bilan ham tekshirish
            for variant in [latin_form.replace("'", "\u02BB"),
                           latin_form.replace("'", "\u02BC"),
                           latin_form.replace("'", "`")]:
                matched_defs = latin_defs.get(variant, [])
                if matched_defs:
                    break

        for defn, tl in matched_defs:
            if add_definition(cursor, wid, defn, tl, sort_order=120):
                kodchi_enriched += 1
                kodchi_enriched_set.add(wid)

    conn.commit()
    print(f"  Tozalangan so'zlar: {kodchi_cleaned}")
    print(f"  Natija: {kodchi_enriched} ta'rif qo'shildi, "
          f"{len(kodchi_enriched_set)} so'z boyitildi")

    # ═══════════════════════════════════════════
    # FTS5 QAYTA QURISH
    # ═══════════════════════════════════════════
    print(f"\n{'─'*60}")
    print("FTS5 indeksi qayta qurilmoqda...")

    rebuild_search_index(conn)

    # ═══════════════════════════════════════════
    # OPTIMALLASHTIRISH
    # ═══════════════════════════════════════════
    print("Optimallashtirish (ANALYZE, VACUUM)...")
    conn.execute("ANALYZE")
    conn.execute("VACUUM")

    # Meta yangilash
    import datetime
    cursor.execute("SELECT COUNT(*) FROM definitions")
    total_defs = cursor.fetchone()[0]
    conn.execute("INSERT OR REPLACE INTO meta VALUES ('enriched_at', ?)",
                 (datetime.datetime.now().isoformat(),))
    conn.execute("INSERT OR REPLACE INTO meta VALUES ('version', ?)", (DB_VERSION,))
    conn.execute("INSERT OR REPLACE INTO meta VALUES ('definition_count', ?)",
                 (str(total_defs),))
    conn.commit()

    # ═══════════════════════════════════════════
    # YAKUNIY STATISTIKA
    # ═══════════════════════════════════════════
    print(f"\n{'='*60}")
    print("YAKUNIY STATISTIKA")
    print(f"{'='*60}")

    cursor.execute("SELECT COUNT(*) FROM words")
    final_words = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM definitions")
    final_defs = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(DISTINCT word_id) FROM definitions")
    final_with_defs = cursor.fetchone()[0]

    cursor.execute("""SELECT COUNT(DISTINCT w.id) FROM words w
                      JOIN definitions d ON d.word_id = w.id
                      WHERE w.language='uz' AND d.target_language='en'""")
    with_en = cursor.fetchone()[0]

    cursor.execute("""SELECT COUNT(DISTINCT w.id) FROM words w
                      JOIN definitions d ON d.word_id = w.id
                      WHERE w.language='uz' AND d.target_language='ru'""")
    with_ru = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM definitions WHERE example_source != ''")
    with_examples = cursor.fetchone()[0]

    cursor.execute("SELECT target_language, COUNT(*) FROM definitions GROUP BY target_language")
    by_target = cursor.fetchall()

    print(f"\n  Jami so'zlar:          {final_words}")
    print(f"  Jami ta'riflar:        {final_defs} (oldin: {initial_defs}, "
          f"+{final_defs - initial_defs})")
    print(f"  Ta'rifli so'zlar:      {final_with_defs} / {final_words} "
          f"({final_with_defs*100//final_words}%)")
    print(f"  Inglizcha tarjimali:   {with_en}")
    print(f"  Ruscha tarjimali:      {with_ru}")
    print(f"  Misolli ta'riflar:     {with_examples}")
    print(f"\n  Target language bo'yicha:")
    for tl, cnt in by_target:
        label = tl if tl else "(bosh)"
        print(f"    {label}: {cnt}")

    db_size = os.path.getsize(DB_PATH)
    print(f"\n  Baza hajmi: {db_size / 1024 / 1024:.2f} MB")

    conn.close()
    print(f"\nBoyitish muvaffaqiyatli tugadi!")


if __name__ == "__main__":
    enrich()
