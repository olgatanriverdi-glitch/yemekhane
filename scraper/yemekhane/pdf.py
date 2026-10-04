"""Metin tabanlı (Word vb. çıkışlı) PDF'lerden konumlu metin çıkarır; yalnızca standart kütüphane kullanır.
Taranmış (resim) PDF'lerde metin yoktur, onlar için ocr.py kullanılır.

Kapsam: FlateDecode akışlar, nesne akışları (ObjStm), Type0/Identity-H yazı tiplerinin ToUnicode tabloları (bfchar, bfrange ve dizi biçimli bfrange)
ve basit yazı tiplerinin düz metin dizgileri. Şifreli PDF'ler ve gömülü olmayan özel kodlamalar desteklenmez."""
import re
import zlib

_TOKEN = re.compile(rb"<<|>>|<[0-9A-Fa-f\s]*>|\((?:\\.|[^\\)])*\)|\[|\]|/[^\s/\[\]<>()]+|[-+]?\d*\.\d+|[-+]?\d+|[A-Za-z'\"*]+")
_OPERATOR = re.compile(rb"[A-Za-z'\"*]+")


def _coz(sozluk: bytes, ham: bytes) -> bytes:
    if b"/FlateDecode" not in sozluk:
        return ham
    try:
        return zlib.decompress(ham)
    except zlib.error:
        try:
            return zlib.decompressobj().decompress(ham)         # sonu bozuk akışlardan elde edilebildiği kadarı
        except zlib.error:
            return b""


def nesneler(pdf: bytes) -> dict:
    """{nesne_no: (sözlük_bayt, çözülmüş_akış|None)}; ObjStm içindeki nesneler de dahil."""
    sonuc = {}
    for m in re.finditer(rb"(\d+) (\d+) obj\b(.*?)endobj", pdf, re.S):
        govde = m.group(3)
        s = re.search(rb"stream\r?\n", govde)
        if s:
            sozluk = govde[:s.start()]
            sonuc[int(m.group(1))] = (sozluk, _coz(sozluk, govde[s.end():govde.rfind(b"endstream")]))
        else:
            sonuc[int(m.group(1))] = (govde, None)
    for sozluk, akis in [v for v in sonuc.values() if v[1] is not None and b"/ObjStm" in v[0]]:
        n = int(re.search(rb"/N (\d+)", sozluk).group(1))
        ilk = int(re.search(rb"/First (\d+)", sozluk).group(1))
        sayilar = list(map(int, re.findall(rb"\d+", akis[:ilk])))[:2 * n]
        for i in range(len(sayilar) // 2):
            sonraki = sayilar[2 * i + 3] if 2 * i + 3 < len(sayilar) else len(akis) - ilk
            sonuc[sayilar[2 * i]] = (akis[ilk + sayilar[2 * i + 1]: ilk + sonraki], None)
    return sonuc


def _utf16(hexmetin: bytes) -> str:
    return bytes.fromhex(hexmetin.decode()).decode("utf-16-be", "ignore")


def cmap_oku(akis: bytes) -> dict:
    """ToUnicode CMap -> {kod: metin}"""
    harita = {}
    for blok in re.findall(rb"beginbfchar(.*?)endbfchar", akis, re.S):
        for a, b in re.findall(rb"<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>", blok):
            harita[int(a, 16)] = _utf16(b)
    for blok in re.findall(rb"beginbfrange(.*?)endbfrange", akis, re.S):
        for a, b, kalan in re.findall(rb"<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(\[[^\]]*\]|<[0-9A-Fa-f]+>)", blok):
            if kalan.startswith(b"["):
                for k, hx in enumerate(re.findall(rb"<([0-9A-Fa-f]+)>", kalan)):
                    harita[int(a, 16) + k] = _utf16(hx)
            else:
                bas = int(kalan[1:-1], 16)
                for k in range(int(a, 16), int(b, 16) + 1):
                    harita[k] = chr(bas + k - int(a, 16))
    return harita


def _dizgi(ham: bytes) -> str:
    ic = ham[1:-1]
    ic = re.sub(rb"\\([0-7]{1,3})", lambda m: bytes([int(m.group(1), 8) & 255]), ic)
    ic = re.sub(rb"\\(.)", lambda m: m.group(1), ic, flags=re.S)
    return ic.decode("cp1254", "ignore")


def sayfa_metinleri(pdf: bytes) -> list:
    """Her içerik akışı için [(x, y, yazı_boyu, metin)] listesi (PDF koordinatları: y yukarı doğru artar)."""
    nes = nesneler(pdf)
    yazitipi = {}          # nesne_no -> cmap
    for no, (sozluk, _) in nes.items():
        m = re.search(rb"/ToUnicode (\d+) 0 R", sozluk)
        if m and re.search(rb"/Type\s*/Font\b", sozluk) and nes.get(int(m.group(1)), (b"", None))[1]:
            yazitipi[no] = cmap_oku(nes[int(m.group(1))][1])
    adlar = {}             # kaynak adı (F1) -> yazı tipi nesnesi
    for sozluk, _ in nes.values():
        for m in re.finditer(rb"/Font\s*<<(.*?)>>", sozluk, re.S):
            for ad, ref in re.findall(rb"/(\w+)\s+(\d+) 0 R", m.group(1)):
                adlar[ad.decode()] = int(ref)
    sayfalar = []
    for no in sorted(nes):
        sozluk, akis = nes[no]
        if not akis or not _icerik_akisi_mi(sozluk, akis):
            continue
        sayfalar.append(_icerik(akis, adlar, yazitipi))
    return sayfalar


def _icerik_akisi_mi(sozluk: bytes, akis: bytes) -> bool:
    """Sayfa içerik akışı: metin işleçleri (BT..Tf) var ve içerik düz metin; gömülü yazı tipi/görsel/ObjStm akışları değil."""
    if re.search(rb"/Length1|/Subtype\s*/(Image|Type1C|CIDFontType0C|OpenType)|/ObjStm|/XRef|/Metadata", sozluk):
        return False
    if not re.search(rb"\bBT\b", akis) or not re.search(rb"\bTf\b", akis):
        return False
    ornek = akis[:4000]
    yazdirilabilir = sum(1 for b in ornek if 32 <= b < 127 or b in (9, 10, 13))
    return yazdirilabilir >= 0.95 * len(ornek)           # ikili veri (yazı tipi dosyası vb.) metin işleci içerse bile içerik akışı değildir


def _icerik(akis: bytes, adlar: dict, yazitipi: dict) -> list:
    yigin, sonuc = [], []
    font, boyut, tx, ty, lx, ly, tl = None, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
    for m in _TOKEN.finditer(akis):
        t = m.group(0)
        if not _OPERATOR.fullmatch(t) or t in (b"true", b"false", b"null"):
            yigin.append(float(t) if t[:1] in b"-+0123456789." else t)
            continue
        try:
            if t == b"Tf":
                font, boyut = yigin[-2][1:].decode(), float(yigin[-1])
            elif t == b"Tm":
                lx, ly = float(yigin[-2]), float(yigin[-1])
                tx, ty = lx, ly
            elif t in (b"Td", b"TD"):
                lx, ly = lx + float(yigin[-2]), ly + float(yigin[-1])
                tx, ty = lx, ly
                if t == b"TD":
                    tl = -float(yigin[-1])
            elif t == b"T*":
                ly -= tl
                tx, ty = lx, ly
            elif t == b"TL":
                tl = float(yigin[-1])
            elif t in (b"Tj", b"TJ", b"'", b'"'):
                cmap = yazitipi.get(adlar.get(font, -1))
                parca = []
                for o in yigin:
                    if isinstance(o, bytes) and o[:1] == b"<" and o[:2] != b"<<":
                        hx = re.sub(rb"\s", b"", o[1:-1]).decode()
                        if cmap:
                            parca += [cmap.get(int(hx[i:i + 4], 16), "") for i in range(0, len(hx) - 3, 4)]
                        else:
                            parca += [bytes.fromhex(hx[i:i + 2]).decode("cp1254", "ignore") for i in range(0, len(hx) - 1, 2)]
                    elif isinstance(o, bytes) and o[:1] == b"(":
                        parca.append(_dizgi(o))
                    elif isinstance(o, float) and o < -200:           # TJ içindeki büyük boşluk ayarı: sözcük aralığı
                        parca.append(" ")
                metin = "".join(parca)
                if metin:
                    sonuc.append((round(tx, 1), round(ty, 1), boyut, metin))
        except (IndexError, ValueError):
            pass
        yigin = []
    return sonuc
