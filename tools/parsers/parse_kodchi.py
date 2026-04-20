"""
kodchi/uzbek-words parse qilish.
O'zbek so'zlar ro'yxati (faqat so'zlar, ta'rifsiz).
"""
import os

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "raw_data")


def parse_kodchi():
    base_dir = os.path.join(RAW_DIR, "kodchi-words")
    if not os.path.isdir(base_dir):
        print("[KODCHI] Papka topilmadi:", base_dir)
        return []

    # Fayllarni qidirish
    words = set()
    for root, dirs, files in os.walk(base_dir):
        for fname in files:
            if fname.endswith((".txt", ".json", ".csv", ".md")):
                fpath = os.path.join(root, fname)
                try:
                    with open(fpath, "r", encoding="utf-8") as f:
                        content = f.read()
                except Exception:
                    continue

                if fname.endswith(".json"):
                    import json
                    try:
                        data = json.loads(content)
                        if isinstance(data, list):
                            for item in data:
                                if isinstance(item, str):
                                    words.add(item.strip())
                                elif isinstance(item, dict):
                                    w = item.get("word", "") or item.get("name", "")
                                    if w:
                                        words.add(w.strip())
                    except json.JSONDecodeError:
                        pass
                else:
                    for line in content.splitlines():
                        line = line.strip()
                        if not line or line.startswith("#") or line.startswith("*"):
                            continue
                        # Tab bilan ajratilgan formatni aniqlash: "so'z\tPOS"
                        if "\t" in line:
                            word = line.split("\t")[0].strip()
                        else:
                            word = line
                        if word and len(word) < 50:
                            words.add(word)

    entries = []
    for word in sorted(words):
        if not word:
            continue
        entries.append({
            "word": word,
            "language": "uz",
            "pos": "",
            "definitions": [],  # Faqat so'zlar, ta'rifsiz
            "target_language": "",
            "pronunciation": "",
            "etymology": "",
            "examples": [],
            "source": "kodchi",
        })

    print(f"[KODCHI] {len(entries)} ta so'z parse qilindi")
    return entries


if __name__ == "__main__":
    results = parse_kodchi()
    print(f"  Jami: {len(results)} so'z")
    for r in results[:10]:
        print(f"  {r['word']}")
