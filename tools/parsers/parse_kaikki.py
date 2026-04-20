"""
Kaikki.org Wiktionary Uzbek JSONL parse qilish.
Eng boy manba: so'z, POS, ta'riflar, IPA, etimologiya.
"""
import json
import os

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "raw_data")

POS_MAP = {
    "noun": "noun", "verb": "verb", "adj": "adj", "adv": "adv",
    "pron": "pron", "prep": "prep", "conj": "conj", "intj": "intj",
    "det": "det", "num": "num", "particle": "particle",
    "prefix": "prefix", "suffix": "suffix", "phrase": "phrase",
    "name": "noun",  # proper nouns
}


def normalize_pos(pos: str) -> str:
    if not pos:
        return ""
    return POS_MAP.get(pos.lower(), pos.lower())


def parse_kaikki():
    """Kaikki JSONL faylini parse qiladi. Umumiy format qaytaradi."""
    filepath = os.path.join(RAW_DIR, "kaikki-uzbek.jsonl")
    if not os.path.exists(filepath):
        print("[KAIKKI] Fayl topilmadi:", filepath)
        return []

    entries = []
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
            if not word:
                continue

            pos = normalize_pos(obj.get("pos", ""))
            lang_code = obj.get("lang_code", "")
            if lang_code != "uz":
                continue

            # IPA
            pronunciation = ""
            sounds = obj.get("sounds", [])
            for s in sounds:
                if "ipa" in s:
                    pronunciation = s["ipa"]
                    break

            # Etimologiya
            etymology = obj.get("etymology_text", "")

            # Ta'riflar (inglizcha glossalar)
            definitions = []
            examples = []
            for sense in obj.get("senses", []):
                glosses = sense.get("glosses", [])
                for gloss in glosses:
                    if gloss and gloss not in definitions:
                        definitions.append(gloss)

                # Misollar
                for ex in sense.get("examples", []):
                    ex_text = ex.get("text", "")
                    ex_translation = ex.get("english", "") or ex.get("translation", "")
                    if ex_text:
                        examples.append((ex_text, ex_translation))

            if not definitions:
                continue

            entries.append({
                "word": word,
                "language": "uz",
                "pos": pos,
                "definitions": definitions,
                "target_language": "en",
                "pronunciation": pronunciation,
                "etymology": etymology,
                "examples": examples,
                "source": "kaikki",
            })

    print(f"[KAIKKI] {len(entries)} ta yozuv parse qilindi")
    return entries


if __name__ == "__main__":
    results = parse_kaikki()
    for r in results[:5]:
        print(f"  {r['word']} ({r['pos']}): {r['definitions'][:2]}")
