"""
SMenigat/thousand-most-common-words — 1000 ta eng ko'p ishlatiladigan o'zbek so'zlar.
"""
import json
import os

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "raw_data")


def parse_common():
    filepath = os.path.join(RAW_DIR, "common-words-uz.json")
    if not os.path.exists(filepath):
        print("[COMMON] Fayl topilmadi:", filepath)
        return []

    with open(filepath, "r", encoding="utf-8") as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            print(f"[COMMON] JSON xato: {e}")
            return []

    entries = []

    # {"languageCode": "uz", "words": [...]} formatda
    if isinstance(data, dict) and "words" in data:
        data = data["words"]

    if isinstance(data, list):
        for item in data:
            word = ""
            definition = ""
            if isinstance(item, str):
                word = item.strip()
            elif isinstance(item, dict):
                word = (item.get("word", "") or item.get("name", "")
                        or item.get("uz", "") or item.get("targetWord", "")).strip()
                definition = (item.get("translation", "") or item.get("en", "")
                              or item.get("english", "") or item.get("englishWord", "")).strip()

            if not word:
                continue

            entries.append({
                "word": word,
                "language": "uz",
                "pos": "",
                "definitions": [definition] if definition else [],
                "target_language": "en" if definition else "",
                "pronunciation": "",
                "etymology": "",
                "examples": [],
                "source": "common",
            })

    print(f"[COMMON] {len(entries)} ta so'z parse qilindi")
    return entries


if __name__ == "__main__":
    results = parse_common()
    for r in results[:10]:
        print(f"  {r['word']}: {r['definitions']}")
