"""Okulun menüyü yalnızca resim/PDF-resim olarak yayınladığı aylar için elle girilmiş menüler.
`elle_veri/<üniversite>.json` dosyası, `data/<id>/menu.json` ile aynı biçimdedir: {"days": {"2026-10-01": {"lunch": {...}}}}.
Her ay okul yeni resmi yayınlayınca ilgili dosyaya o ayın günleri eklenir (eski günler build sırasında zaten ayıklanır)."""
import json
import os

KLASOR = os.path.join(os.path.dirname(__file__), "elle_veri")


def yukle(kimlik: str) -> dict:
    """{'2026-10-01': {'lunch': {...}, ...}, ...}; dosya yoksa boş sözlük."""
    yol = os.path.join(KLASOR, kimlik + ".json")
    if not os.path.exists(yol):
        return {}
    with open(yol, encoding="utf-8") as f:
        return json.load(f).get("days", {})
