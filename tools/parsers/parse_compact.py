"""
Compact Dictionaries (Wiktionary extract) JSON parse qilish.
3,801 ta o'zbek so'z.
"""
import json
import os

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "raw_data")


def parse_compact():
    filepath = os.path.join(RAW_DIR, "compact-uz.json")
    if not os.path.exists(filepath):
        print("[COMPACT] Fayl topilmadi:", filepath)
        return []

    entries = []

    # JSONL format — har qator alohida JSON obyekt
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                item = json.loads(line)
            except json.JSONDecodeError:
                continue

            if not isinstance(item, dict):
                continue

            # So'z "" (bo'sh kalit) da saqlangan
            word = item.get("", "") or item.get("word", "")
            if not word:
                continue

            pos_list = item.get("p", [])
            pos = pos_list[0] if isinstance(pos_list, list) and pos_list else ""
            defs = item.get("d", [])
            if not defs:
                continue
            if isinstance(defs, str):
                defs = [defs]

            entries.append({
                "word": word,
                "language": "uz",
                "pos": pos.lower() if pos else "",
                "definitions": defs,
                "target_language": "en",
                "pronunciation": item.get("i", ""),
                "etymology": "",
                "examples": [],
                "source": "compact",
            })

    print(f"[COMPACT] {len(entries)} ta yozuv parse qilindi")
    return entries


if __name__ == "__main__":
    results = parse_compact()
    for r in results[:5]:
        print(f"  {r['word']} ({r['pos']}): {r['definitions'][:2]}")
