"""Bağımlılıksız (yalnızca standart kütüphane) minik XLSX okuyucu: ilk sayfayı satır satır döndürür."""
import html
import re
import zipfile
from io import BytesIO


def satirlar(veri: bytes):
    """İlk çalışma sayfasının satırlarını {sütun_harfi: değer} sözlükleri olarak döndürür."""
    z = zipfile.ZipFile(BytesIO(veri))
    ss = []
    if "xl/sharedStrings.xml" in z.namelist():
        ham = z.read("xl/sharedStrings.xml").decode("utf-8")
        ss = [html.unescape(re.sub(r"<[^>]+>", "", x)) for x in re.findall(r"<si>(.*?)</si>", ham, flags=re.S)]
    sayfa = z.read("xl/worksheets/sheet1.xml").decode("utf-8")
    sonuc = []
    for satir in re.findall(r"<row [^>]*>(.*?)</row>", sayfa, flags=re.S):
        hucreler = {}
        for ref, attr, ic in re.findall(r'<c r="([A-Z]+)\d+"([^>]*?)(?:/>|>(.*?)</c>)', satir, flags=re.S):
            v = re.search(r"<v>(.*?)</v>", ic or "")
            if not v:
                continue
            deger = v.group(1)
            if 't="s"' in attr:
                deger = ss[int(deger)]
            hucreler[ref] = deger.strip()
        sonuc.append(hucreler)
    return sonuc
