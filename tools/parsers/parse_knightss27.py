"""
knightss27/uzbek-english-dictionary parse qilish.
Indiana University CTILD va Herve-Guerin lug'atlaridan ma'lumot.
Svelte web ilova — ma'lumot JS/JSON formatda saqlangan.
"""
import json
import os
import re

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "raw_data")


def parse_knightss27():
    base_dir = os.path.join(RAW_DIR, "knightss27-dict")
    if not os.path.isdir(base_dir):
        print("[KNIGHTSS27] Papka topilmadi:", base_dir)
        return []

    entries = []

    # JSON ma'lumot fayllarini qidirish
    for root, dirs, files in os.walk(base_dir):
        for fname in files:
            fpath = os.path.join(root, fname)

            if fname.endswith(".json"):
                entries.extend(_parse_json(fpath))
            elif fname.endswith(".js") and "data" in fname.lower():
                entries.extend(_parse_js_data(fpath))
            elif fname.endswith(".js") and "dict" in fname.lower():
                entries.extend(_parse_js_data(fpath))

    # Agar JSON/JS topilmasa, src papkadagi barcha JS fayllarni tekshirish
    if not entries:
        src_dir = os.path.join(base_dir, "src")
        if os.path.isdir(src_dir):
            for root, dirs, files in os.walk(src_dir):
                for fname in files:
                    if fname.endswith((".js", ".ts", ".svelte")):
                        fpath = os.path.join(root, fname)
                        entries.extend(_parse_js_data(fpath))

    # Static/public papkadagi JSON fayllar
    if not entries:
        for subdir in ["static", "public", "data", "assets"]:
            d = os.path.join(base_dir, subdir)
            if os.path.isdir(d):
                for root, dirs, files in os.walk(d):
                    for fname in files:
                        if fname.endswith(".json"):
                            entries.extend(_parse_json(os.path.join(root, fname)))

    print(f"[KNIGHTSS27] {len(entries)} ta yozuv parse qilindi")
    return entries


def _parse_json(filepath):
    entries = []
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        return entries

    if isinstance(data, list):
        for item in data:
            if isinstance(item, dict):
                word = (item.get("word", "") or item.get("uz", "")
                        or item.get("headword", "") or item.get("entry", "")).strip()
                defs = []
                for key in ["definition", "en", "english", "meaning", "translation", "gloss"]:
                    val = item.get(key, "")
                    if val:
                        if isinstance(val, list):
                            defs.extend([str(v).strip() for v in val if v])
                        else:
                            defs.append(str(val).strip())

                pos = item.get("pos", item.get("part_of_speech", item.get("category", "")))

                if word:
                    entries.append({
                        "word": word,
                        "language": "uz",
                        "pos": pos.lower() if pos else "",
                        "definitions": defs,
                        "target_language": "en" if defs else "",
                        "pronunciation": "",
                        "etymology": "",
                        "examples": [],
                        "source": "knightss27",
                    })
    elif isinstance(data, dict):
        for word, val in data.items():
            if isinstance(val, str):
                defs = [val.strip()]
            elif isinstance(val, dict):
                defs = []
                for key in ["definition", "en", "meaning"]:
                    if key in val:
                        d = val[key]
                        defs.append(str(d).strip() if not isinstance(d, list) else ", ".join(d))
            elif isinstance(val, list):
                defs = [str(v).strip() for v in val if v]
            else:
                continue

            if word.strip():
                entries.append({
                    "word": word.strip(),
                    "language": "uz",
                    "pos": "",
                    "definitions": defs,
                    "target_language": "en" if defs else "",
                    "pronunciation": "",
                    "etymology": "",
                    "examples": [],
                    "source": "knightss27",
                })
    return entries


def _parse_js_data(filepath):
    """JS fayllardan JSON massiv yoki obyektni ajratib olish."""
    entries = []
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception:
        return entries

    # export default [...] yoki const data = [...] pattern
    patterns = [
        r'export\s+default\s+(\[.*?\])\s*;?\s*$',
        r'(?:const|let|var)\s+\w+\s*=\s*(\[.*?\])\s*;?\s*$',
        r'(?:const|let|var)\s+\w+\s*=\s*(\{.*?\})\s*;?\s*$',
    ]

    for pattern in patterns:
        match = re.search(pattern, content, re.DOTALL)
        if match:
            try:
                data = json.loads(match.group(1))
                if isinstance(data, list):
                    for item in data:
                        if isinstance(item, dict):
                            word = (item.get("word", "") or item.get("uz", "")).strip()
                            defs = []
                            for key in ["definition", "en", "meaning"]:
                                if key in item:
                                    val = item[key]
                                    if isinstance(val, list):
                                        defs.extend([str(v) for v in val])
                                    else:
                                        defs.append(str(val))
                            if word:
                                entries.append({
                                    "word": word,
                                    "language": "uz",
                                    "pos": item.get("pos", ""),
                                    "definitions": defs,
                                    "target_language": "en",
                                    "pronunciation": "",
                                    "etymology": "",
                                    "examples": [],
                                    "source": "knightss27",
                                })
            except (json.JSONDecodeError, Exception):
                continue
    return entries


if __name__ == "__main__":
    results = parse_knightss27()
    for r in results[:5]:
        print(f"  {r['word']}: {r['definitions'][:2]}")
