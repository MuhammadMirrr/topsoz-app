"""
Asosiy o'zbek so'zlar — boshqa manbalarda yo'q bo'lgan muhim so'zlar.
"""
import json
import os

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "raw_data")


def parse_essential():
    filepath = os.path.join(RAW_DIR, "essential-words.json")
    if not os.path.exists(filepath):
        print("[ESSENTIAL] Fayl topilmadi:", filepath)
        return []

    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)

    entries = []
    for item in data:
        word = item.get("word", "").strip()
        if not word:
            continue

        examples = []
        for ex in item.get("examples", []):
            if isinstance(ex, (list, tuple)) and len(ex) >= 1:
                examples.append((ex[0], ex[1] if len(ex) > 1 else ""))

        entries.append({
            "word": word,
            "language": "uz",
            "pos": item.get("pos", ""),
            "definitions": item.get("definitions", []),
            "target_language": "en",
            "pronunciation": "",
            "etymology": "",
            "examples": examples,
            "source": "essential",
        })

    print(f"[ESSENTIAL] {len(entries)} ta yozuv parse qilindi")
    return entries


if __name__ == "__main__":
    results = parse_essential()
    for r in results[:5]:
        print(f"  {r['word']} ({r['pos']}): {r['definitions'][:2]}")
