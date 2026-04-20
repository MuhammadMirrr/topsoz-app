"""
Barcha ochiq manba lug'at ma'lumotlarini yuklab olish.
"""
import os
import sys
import subprocess
import requests
import zipfile
import io

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "raw_data")


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)


def download_file(url, dest_path, desc=""):
    """Faylni yuklab olish."""
    if os.path.exists(dest_path):
        print(f"  [MAVJUD] {desc or dest_path}")
        return True
    print(f"  [YUKLANMOQDA] {desc or url}")
    try:
        r = requests.get(url, timeout=120, stream=True)
        r.raise_for_status()
        with open(dest_path, "wb") as f:
            for chunk in r.iter_content(chunk_size=8192):
                f.write(chunk)
        print(f"  [OK] {os.path.getsize(dest_path) / 1024:.0f} KB")
        return True
    except Exception as e:
        print(f"  [XATO] {e}")
        return False


def clone_repo(url, dest_dir, desc=""):
    """Git reponi klonlash."""
    if os.path.exists(dest_dir) and os.listdir(dest_dir):
        print(f"  [MAVJUD] {desc or dest_dir}")
        return True
    print(f"  [KLONLANMOQDA] {desc or url}")
    try:
        subprocess.run(
            ["git", "clone", "--depth", "1", url, dest_dir],
            check=True, capture_output=True, text=True
        )
        print(f"  [OK]")
        return True
    except Exception as e:
        print(f"  [XATO] {e}")
        return False


def download_all():
    ensure_dir(RAW_DIR)

    print("\n=== 1. Kaikki.org Wiktionary Uzbek ===")
    download_file(
        "https://kaikki.org/dictionary/Uzbek/kaikki.org-dictionary-Uzbek.jsonl",
        os.path.join(RAW_DIR, "kaikki-uzbek.jsonl"),
        "Kaikki Uzbek JSONL"
    )

    print("\n=== 2. Vuizur Wiktionary Dictionaries ===")
    # TSV fayl — to'g'ridan-to'g'ri raw URL dan
    download_file(
        "https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Uzbek-English%20Wiktionary%20dictionary.tsv",
        os.path.join(RAW_DIR, "vuizur-uz-en.tsv"),
        "Vuizur Uzbek-English TSV"
    )

    print("\n=== 3. UzWordnet ===")
    uzwordnet_dir = os.path.join(RAW_DIR, "uzwordnet")
    clone_repo(
        "https://github.com/LDKR-Group/UzWordnet.git",
        uzwordnet_dir,
        "UzWordnet repo"
    )

    print("\n=== 4. Herve-Guerin Uzbek Glossary ===")
    herve_dir = os.path.join(RAW_DIR, "herve-glossary")
    clone_repo(
        "https://github.com/Herve-Guerin/uzbek-glossary.git",
        herve_dir,
        "Herve-Guerin glossary repo"
    )

    print("\n=== 5. Compact Dictionaries ===")
    download_file(
        "https://gitlab.com/tdulcet/compact-dictionary/-/raw/main/wiktionary/dictionary-uz.json",
        os.path.join(RAW_DIR, "compact-uz.json"),
        "Compact Dictionary Uzbek JSON"
    )

    print("\n=== 6. kodchi/uzbek-words ===")
    kodchi_dir = os.path.join(RAW_DIR, "kodchi-words")
    clone_repo(
        "https://github.com/kodchi/uzbek-words.git",
        kodchi_dir,
        "kodchi uzbek-words repo"
    )

    print("\n=== 7. SMenigat common words ===")
    download_file(
        "https://raw.githubusercontent.com/SMenigat/thousand-most-common-words/master/words/uz.json",
        os.path.join(RAW_DIR, "common-words-uz.json"),
        "1000 common Uzbek words"
    )

    print("\n=== 8. nurullon/Dictionary ===")
    nurullon_dir = os.path.join(RAW_DIR, "nurullon-dict")
    clone_repo(
        "https://github.com/nurullon/Dictionary.git",
        nurullon_dir,
        "nurullon Dictionary repo"
    )

    print("\n=== 9. Tatoeba Uzbek sentences ===")
    # Tatoeba sentence pairs
    download_file(
        "https://downloads.tatoeba.org/exports/per_language/uzb/uzb_sentences_detailed.tsv.bz2",
        os.path.join(RAW_DIR, "tatoeba-uzb.tsv.bz2"),
        "Tatoeba Uzbek sentences"
    )
    download_file(
        "https://downloads.tatoeba.org/exports/links.tar.bz2",
        os.path.join(RAW_DIR, "tatoeba-links.tar.bz2"),
        "Tatoeba sentence links"
    )

    print("\n=== 10. knightss27/uzbek-english-dictionary ===")
    knight_dir = os.path.join(RAW_DIR, "knightss27-dict")
    clone_repo(
        "https://github.com/knightss27/uzbek-english-dictionary.git",
        knight_dir,
        "knightss27 uzbek-english-dictionary"
    )

    # ─── Qo'shimcha manbalar (enrichment uchun) ───

    print("\n=== 11. Tatoeba Ingliz gaplar ===")
    download_file(
        "https://downloads.tatoeba.org/exports/per_language/eng/eng_sentences_detailed.tsv.bz2",
        os.path.join(RAW_DIR, "tatoeba-eng.tsv.bz2"),
        "Tatoeba English sentences"
    )

    print("\n=== 12. Tatoeba Rus gaplar ===")
    download_file(
        "https://downloads.tatoeba.org/exports/per_language/rus/rus_sentences_detailed.tsv.bz2",
        os.path.join(RAW_DIR, "tatoeba-rus.tsv.bz2"),
        "Tatoeba Russian sentences"
    )

    print("\n=== 13. OpenRussian lug'at ===")
    openrussian_dir = os.path.join(RAW_DIR, "openrussian")
    ensure_dir(openrussian_dir)
    for csv_name in ["nouns.csv", "verbs.csv", "adjectives.csv", "others.csv"]:
        download_file(
            f"https://raw.githubusercontent.com/Badestrand/russian-dictionary/master/{csv_name}",
            os.path.join(openrussian_dir, csv_name),
            f"OpenRussian {csv_name}"
        )

    print("\n=== 14. NLTK WordNet (inglizcha synset ta'riflari) ===")
    wn_zip = os.path.join(RAW_DIR, "wordnet.zip")
    download_file(
        "https://raw.githubusercontent.com/nltk/nltk_data/gh-pages/packages/corpora/wordnet.zip",
        wn_zip,
        "NLTK WordNet data"
    )
    # Avtomatik arxivdan chiqarish
    wn_dir = os.path.join(RAW_DIR, "wordnet")
    if not os.path.exists(wn_dir) and os.path.exists(wn_zip):
        print("  [OCHILMOQDA] WordNet arxivi...")
        try:
            with zipfile.ZipFile(wn_zip, "r") as z:
                z.extractall(RAW_DIR)
            print("  [OK] WordNet ochildi")
        except Exception as e:
            print(f"  [XATO] {e}")

    print("\n=== Yuklab olish tugadi ===")


if __name__ == "__main__":
    download_all()
