"""
nurullon/Dictionary repo parse qilish.
Formatini repo yuklanganida aniqlaymiz.
"""
import json
import os
import csv

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "raw_data")


def parse_nurullon():
    base_dir = os.path.join(RAW_DIR, "nurullon-dict")
    if not os.path.isdir(base_dir):
        print("[NURULLON] Papka topilmadi:", base_dir)
        return []

    entries = []

    # uzb_ang.json — asosiy fayl
    json_path = os.path.join(base_dir, "uzb_ang.json")
    if os.path.exists(json_path):
        entries.extend(_parse_uzb_ang_json(json_path))

    # Qolgan fayllarni tekshirish
    for root, dirs, files in os.walk(base_dir):
        for fname in files:
            fpath = os.path.join(root, fname)
            if fname == "uzb_ang.json":
                continue  # Allaqachon parse qildik
            if fname.endswith(".json"):
                entries.extend(_parse_json_file(fpath))
            elif fname.endswith(".csv"):
                entries.extend(_parse_csv_file(fpath))
            elif fname.endswith(".txt") and "dict" in fname.lower():
                entries.extend(_parse_txt_file(fpath))
            elif fname.endswith(".tsv"):
                entries.extend(_parse_tsv_file(fpath))

    print(f"[NURULLON] {len(entries)} ta yozuv parse qilindi")
    return entries


def _parse_uzb_ang_json(filepath):
    """nurullon/Dictionary uzb_ang.json — [{uz_word: en_word}, ...] formatda."""
    entries = []
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        return entries

    if isinstance(data, list):
        for item in data:
            if isinstance(item, dict):
                for uz_word, en_word in item.items():
                    uz_word = uz_word.strip()
                    en_word = str(en_word).strip() if en_word else ""
                    if uz_word and en_word:
                        entries.append({
                            "word": uz_word,
                            "language": "uz",
                            "pos": "",
                            "definitions": [en_word],
                            "target_language": "en",
                            "pronunciation": "",
                            "etymology": "",
                            "examples": [],
                            "source": "nurullon",
                        })
    return entries


def _parse_json_file(filepath):
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
                        or item.get("term", "")).strip()
                definition = (item.get("definition", "") or item.get("en", "")
                              or item.get("translation", "") or item.get("meaning", "")).strip()
                pos = item.get("pos", item.get("part_of_speech", ""))
                if word:
                    entries.append({
                        "word": word,
                        "language": "uz",
                        "pos": pos,
                        "definitions": [definition] if definition else [],
                        "target_language": "en" if definition else "",
                        "pronunciation": "",
                        "etymology": "",
                        "examples": [],
                        "source": "nurullon",
                    })
    elif isinstance(data, dict):
        for word, val in data.items():
            definition = val if isinstance(val, str) else str(val)
            if word:
                entries.append({
                    "word": word.strip(),
                    "language": "uz",
                    "pos": "",
                    "definitions": [definition.strip()] if definition.strip() else [],
                    "target_language": "en",
                    "pronunciation": "",
                    "etymology": "",
                    "examples": [],
                    "source": "nurullon",
                })
    return entries


def _parse_csv_file(filepath):
    entries = []
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            reader = csv.reader(f)
            for row in reader:
                if len(row) >= 2:
                    word = row[0].strip()
                    definition = row[1].strip()
                    if word and definition:
                        entries.append({
                            "word": word,
                            "language": "uz",
                            "pos": "",
                            "definitions": [definition],
                            "target_language": "en",
                            "pronunciation": "",
                            "etymology": "",
                            "examples": [],
                            "source": "nurullon",
                        })
    except Exception:
        pass
    return entries


def _parse_tsv_file(filepath):
    entries = []
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split("\t")
                if len(parts) >= 2:
                    word = parts[0].strip()
                    definition = parts[1].strip()
                    if word and definition:
                        entries.append({
                            "word": word,
                            "language": "uz",
                            "pos": "",
                            "definitions": [definition],
                            "target_language": "en",
                            "pronunciation": "",
                            "etymology": "",
                            "examples": [],
                            "source": "nurullon",
                        })
    except Exception:
        pass
    return entries


def _parse_txt_file(filepath):
    entries = []
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                # "so'z - ta'rif" yoki "so'z\tta'rif" formatda
                for sep in [" - ", "\t", " = ", ": "]:
                    if sep in line:
                        parts = line.split(sep, 1)
                        word = parts[0].strip()
                        definition = parts[1].strip()
                        if word and definition:
                            entries.append({
                                "word": word,
                                "language": "uz",
                                "pos": "",
                                "definitions": [definition],
                                "target_language": "en",
                                "pronunciation": "",
                                "etymology": "",
                                "examples": [],
                                "source": "nurullon",
                            })
                        break
    except Exception:
        pass
    return entries


if __name__ == "__main__":
    results = parse_nurullon()
    for r in results[:5]:
        print(f"  {r['word']}: {r['definitions'][:2]}")
