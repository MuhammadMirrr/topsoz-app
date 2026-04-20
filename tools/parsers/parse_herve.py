"""
Herve-Guerin Uzbek Glossary HTML fayllarini parse qilish.
17 ta HTML fayl, semantik guruhlarga bo'lingan.
"""
import os
import re
from bs4 import BeautifulSoup

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "raw_data")

POS_MAP = {
    "n": "noun", "v": "verb", "v.int": "verb", "v.tr": "verb",
    "adj": "adj", "adv": "adv", "pron": "pron", "conj": "conj",
    "prep": "prep", "interj": "intj", "num": "num",
    "n.pl": "noun", "n.abstr": "noun", "part": "particle",
}


def parse_herve():
    glossary_dir = os.path.join(RAW_DIR, "herve-glossary")
    # HTML fayllar turli joylarda bo'lishi mumkin
    html_dirs = [
        os.path.join(glossary_dir, "glossary", "html"),
        os.path.join(glossary_dir, "html"),
        glossary_dir,
    ]

    html_files = []
    for d in html_dirs:
        if os.path.isdir(d):
            for f in os.listdir(d):
                if f.endswith((".htm", ".html")):
                    html_files.append(os.path.join(d, f))
            if html_files:
                break

    if not html_files:
        print("[HERVE] HTML fayllar topilmadi")
        return []

    entries = []
    for filepath in html_files:
        try:
            with open(filepath, "r", encoding="utf-8", errors="replace") as f:
                soup = BeautifulSoup(f.read(), "lxml")
        except Exception as e:
            print(f"[HERVE] Xato {filepath}: {e}")
            continue

        # Jadval qatorlarini qayta ishlash
        for tr in soup.find_all("tr"):
            tds = tr.find_all("td")
            if len(tds) < 3:
                continue

            # Birinchi ustun — so'z (ko'pincha bold/anchor)
            word_td = tds[0]
            anchor = word_td.find("a", attrs={"name": True})
            word_text = ""
            if anchor:
                word_text = anchor.get_text(strip=True)
            if not word_text:
                bold = word_td.find("b")
                if bold:
                    word_text = bold.get_text(strip=True)
            if not word_text:
                word_text = word_td.get_text(strip=True)

            if not word_text:
                continue

            # Normalizatsiya: KATTA HARFDAN kichikga, oxiridagi "-" olib tashlash
            word = word_text.strip().rstrip("-").strip()
            # Newline va ortiqcha probel tozalash
            word = re.sub(r'[\r\n]+', ' ', word)
            word = re.sub(r'\s+', ' ', word).strip()
            if word.isupper():
                word = word.lower()
            # Juda uzun so'zlarni o'tkazib yuborish (iboralar, gaplar)
            if len(word) > 80:
                continue

            # Ikkinchi ustun — POS
            pos_text = tds[1].get_text(strip=True).lower().strip(".")
            pos = POS_MAP.get(pos_text, pos_text)

            # Uchinchi ustun — inglizcha ta'rif
            definition = tds[2].get_text(strip=True)
            if not definition:
                continue

            # Ta'rifni tozalash
            definition = re.sub(r'\s+', ' ', definition).strip()

            entries.append({
                "word": word,
                "language": "uz",
                "pos": pos,
                "definitions": [definition],
                "target_language": "en",
                "pronunciation": "",
                "etymology": "",
                "examples": [],
                "source": "herve",
            })

    print(f"[HERVE] {len(entries)} ta yozuv parse qilindi")
    return entries


if __name__ == "__main__":
    results = parse_herve()
    for r in results[:5]:
        print(f"  {r['word']} ({r['pos']}): {r['definitions'][:1]}")
