"""
UzWordnet JSON/XML parse qilish.
20,683 so'z, 28,149 synset.
Global WordNet Association formatida.
"""
import json
import os
import xml.etree.ElementTree as ET

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "raw_data")

POS_MAP = {"n": "noun", "v": "verb", "a": "adj", "r": "adv", "s": "adj"}


def parse_uzwordnet():
    base_dir = os.path.join(RAW_DIR, "uzwordnet")

    # JSON faylni qidirish
    json_candidates = [
        os.path.join(base_dir, "files", "uzwordnet.json"),
        os.path.join(base_dir, "uzwordnet.json"),
        os.path.join(base_dir, "data", "uzwordnet.json"),
    ]

    json_path = None
    for p in json_candidates:
        if os.path.exists(p):
            json_path = p
            break

    # XML faylni qidirish
    xml_candidates = [
        os.path.join(base_dir, "files", "uzwordnet.xml"),
        os.path.join(base_dir, "uzwordnet.xml"),
    ]
    xml_path = None
    for p in xml_candidates:
        if os.path.exists(p):
            xml_path = p
            break

    if json_path:
        return _parse_json(json_path)
    elif xml_path:
        return _parse_xml(xml_path)
    else:
        # Papka ichidagi barcha JSON fayllarni tekshirish
        print(f"[UZWORDNET] Asosiy fayllar topilmadi, papkani tekshirish...")
        for root, dirs, files in os.walk(base_dir):
            for f in files:
                if f.endswith(".json") and "wordnet" in f.lower():
                    return _parse_json(os.path.join(root, f))
                elif f.endswith(".xml") and "wordnet" in f.lower():
                    return _parse_xml(os.path.join(root, f))
        print("[UZWORDNET] Hech qanday fayl topilmadi")
        return []


def _parse_json(filepath):
    print(f"[UZWORDNET] JSON parse: {filepath}")
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"[UZWORDNET] JSON xato: {e}")
        return []

    entries = []

    # JSON-LD @graph formatda
    if isinstance(data, dict) and "@graph" in data:
        graph = data["@graph"]

        # Avval synset ta'riflarini yig'ish (synset ID → ta'rif matni)
        synset_defs = {}
        for item in graph:
            if not isinstance(item, dict):
                continue
            # Synset elementlarini aniqlash
            synset_entries = item.get("synset", [])
            if not isinstance(synset_entries, list):
                synset_entries = [synset_entries]
            for ss in synset_entries:
                if not isinstance(ss, dict):
                    continue
                ss_id = ss.get("@id", ss.get("id", ""))
                # Ta'rifni "definition" yoki "gloss" maydonidan olish
                defn_obj = ss.get("definition", ss.get("gloss", ""))
                if isinstance(defn_obj, list):
                    for d in defn_obj:
                        if isinstance(d, dict):
                            text = d.get("gloss", d.get("value", d.get("writtenForm", "")))
                        else:
                            text = str(d)
                        if text and ss_id:
                            synset_defs[ss_id] = text.strip()
                            break
                elif isinstance(defn_obj, dict):
                    text = defn_obj.get("gloss", defn_obj.get("value", defn_obj.get("writtenForm", "")))
                    if text and ss_id:
                        synset_defs[ss_id] = text.strip()
                elif isinstance(defn_obj, str) and defn_obj.strip():
                    if ss_id:
                        synset_defs[ss_id] = defn_obj.strip()

        for lexicon in graph:
            if not isinstance(lexicon, dict):
                continue

            lexicon_entries = lexicon.get("entry", [])
            if not isinstance(lexicon_entries, list):
                continue

            for entry in lexicon_entries:
                if not isinstance(entry, dict):
                    continue

                # Lemma olish
                lemma_obj = entry.get("lemma", {})
                if isinstance(lemma_obj, dict):
                    lemma = lemma_obj.get("writtenForm", "")
                elif isinstance(lemma_obj, str):
                    lemma = lemma_obj
                else:
                    continue

                if not lemma:
                    continue

                pos = entry.get("partOfSpeech", "")
                pos = POS_MAP.get(pos.lower() if pos else "", pos.lower() if pos else "")

                # Sense orqali synset ta'riflarini olish
                senses = entry.get("sense", [])
                if isinstance(senses, dict):
                    senses = [senses]

                definitions = []
                for sense in senses:
                    if not isinstance(sense, dict):
                        continue
                    synset_ref = sense.get("synset", sense.get("@id", ""))
                    if synset_ref and synset_ref in synset_defs:
                        defn_text = synset_defs[synset_ref]
                        if defn_text not in definitions:
                            definitions.append(defn_text)

                entries.append({
                    "word": lemma,
                    "language": "uz",
                    "pos": pos,
                    "definitions": definitions,
                    "target_language": "uz" if definitions else "",
                    "pronunciation": "",
                    "etymology": "",
                    "examples": [],
                    "source": "uzwordnet",
                })

        print(f"[UZWORDNET] {len(entries)} ta yozuv parse qilindi "
              f"({len(synset_defs)} synset ta'rifi topildi)")
        return entries

    # Oddiy GWA JSON formatda
    if isinstance(data, dict):
        synsets = {}
        for ss in data.get("synsets", []):
            ss_id = ss.get("id", "")
            definitions = []
            for d in ss.get("definitions", []):
                if isinstance(d, str):
                    definitions.append(d)
                elif isinstance(d, dict):
                    definitions.append(d.get("gloss", d.get("definition", "")))
            synsets[ss_id] = {"definitions": definitions}

        for entry in data.get("entries", data.get("lexicalEntries", [])):
            lemma_obj = entry.get("lemma", {})
            lemma = lemma_obj.get("writtenForm", "") if isinstance(lemma_obj, dict) else str(lemma_obj)
            pos = entry.get("partOfSpeech", "")
            pos = POS_MAP.get(pos.lower() if pos else "", pos.lower() if pos else "")

            if not lemma:
                continue

            definitions = []
            for sense in entry.get("senses", []):
                ss_ref = sense.get("synset", "")
                if ss_ref in synsets:
                    definitions.extend(synsets[ss_ref]["definitions"])

            entries.append({
                "word": lemma,
                "language": "uz",
                "pos": pos,
                "definitions": definitions,
                "target_language": "uz",
                "pronunciation": "",
                "etymology": "",
                "examples": [],
                "source": "uzwordnet",
            })

    print(f"[UZWORDNET] {len(entries)} ta yozuv parse qilindi")
    return entries


def _parse_xml(filepath):
    print(f"[UZWORDNET] XML parse: {filepath}")
    try:
        tree = ET.parse(filepath)
        root = tree.getroot()
    except Exception as e:
        print(f"[UZWORDNET] XML xato: {e}")
        return []

    # Namespace aniqlash
    ns = ""
    if root.tag.startswith("{"):
        ns = root.tag.split("}")[0] + "}"

    entries = []
    for lexicon in root.iter(f"{ns}Lexicon"):
        for entry in lexicon.iter(f"{ns}LexicalEntry"):
            lemma_el = entry.find(f"{ns}Lemma")
            if lemma_el is None:
                continue
            word = lemma_el.get("writtenForm", "")
            pos = lemma_el.get("partOfSpeech", "")
            pos = POS_MAP.get(pos.lower() if pos else "", pos.lower() if pos else "")

            if not word:
                continue

            definitions = []
            for sense in entry.iter(f"{ns}Sense"):
                synset_id = sense.get("synset", "")
                # Ta'rif qidirish
                for defn in sense.iter(f"{ns}Definition"):
                    text = defn.text or defn.get("gloss", "")
                    if text:
                        definitions.append(text.strip())

            entries.append({
                "word": word,
                "language": "uz",
                "pos": pos,
                "definitions": definitions if definitions else [word],
                "target_language": "uz",
                "pronunciation": "",
                "etymology": "",
                "examples": [],
                "source": "uzwordnet",
            })

    print(f"[UZWORDNET] {len(entries)} ta yozuv parse qilindi")
    return entries


if __name__ == "__main__":
    results = parse_uzwordnet()
    for r in results[:5]:
        print(f"  {r['word']} ({r['pos']}): {r['definitions'][:2]}")
