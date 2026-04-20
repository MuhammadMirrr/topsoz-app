"""
Vuizur/Wiktionary-Dictionaries TSV parse qilish.
Format: so'z\tta'rif (tab bilan ajratilgan)
"""
import os

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "raw_data")


def parse_vuizur():
    filepath = os.path.join(RAW_DIR, "vuizur-uz-en.tsv")
    if not os.path.exists(filepath):
        print("[VUIZUR] Fayl topilmadi:", filepath)
        return []

    entries = []
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split("\t")
            if len(parts) < 2:
                continue
            raw_word = parts[0].strip()
            definition = parts[1].strip()
            if not raw_word or not definition:
                continue
            # Pipe bilan ajratilgan conjugation formalar: faqat asosiy shaklni olish
            word = raw_word.split("|")[0].strip() if "|" in raw_word else raw_word
            if not word:
                continue

            entries.append({
                "word": word,
                "language": "uz",
                "pos": "",
                "definitions": [definition],
                "target_language": "en",
                "pronunciation": "",
                "etymology": "",
                "examples": [],
                "source": "vuizur",
            })

    print(f"[VUIZUR] {len(entries)} ta yozuv parse qilindi")
    return entries


if __name__ == "__main__":
    results = parse_vuizur()
    for r in results[:5]:
        print(f"  {r['word']}: {r['definitions'][:2]}")
