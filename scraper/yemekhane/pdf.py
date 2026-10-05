"""Metin tabanlı (Word vb. çıkışlı) PDF'lerden konumlu metin çıkarır; yalnızca standart kütüphane kullanır.
Taranmış (resim) PDF'lerde metin yoktur, onlar için ocr.py kullanılır.

Kapsam: FlateDecode akışlar, nesne akışları (ObjStm), Type0/Identity-H yazı tiplerinin ToUnicode tabloları (bfchar, bfrange ve dizi biçimli bfrange; kodlar
hem <hex> hem de (literal) dizgi olarak yazılmış olabilir), dolaylı (`/Font 21 0 R`) yazı tipi sözlükleri ve basit yazı tiplerinin düz metin dizgileri. Şifreli PDF'ler ve gömülü olmayan özel kodlamalar desteklenmez."""
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


def cmap_genislik(akis: bytes) -> int:
    """ToUnicode CMap'in kod uzayından kodun bayt sayısı: <0000> <FFFF> -> 2, <00> <FF> -> 1 (belirtilmemişse 2: Identity-H)."""
    m = re.search(rb"begincodespacerange\s*<([0-9A-Fa-f]+)>", akis)
    return max(1, len(m.group(1)) // 2) if m else 2


def _dizgi_baytlari(ham: bytes) -> bytes:
    ic = ham[1:-1]
    ic = re.sub(rb"\\([0-7]{1,3})", lambda m: bytes([int(m.group(1), 8) & 255]), ic)
    return re.sub(rb"\\(.)", lambda m: {b"n": b"\n", b"r": b"\r", b"t": b"\t"}.get(m.group(1), m.group(1)), ic, flags=re.S)


def _dizgi(ham: bytes) -> str:
    return _dizgi_baytlari(ham).decode("cp1254", "ignore")


def sayfa_metinleri(pdf: bytes, ctm: bool = False) -> list:
    """Her içerik akışı için [(x, y, yazı_boyu, metin)] listesi (PDF koordinatları: y yukarı doğru artar).
    ctm=True: q/Q/cm dönüşümleri ve metin matrisleri uygulanır, konumlar sayfa koordinatlarında verilir (her metin bloğu kendi `cm` matrisiyle yazılmışsa,
    örn. Canva çıkışlı PDF'ler); varsayılan (False) konumlar içerik akışındaki ham değerlerdir."""
    nes = nesneler(pdf)
    yazitipi = {}          # nesne_no -> (cmap, kod_baytı)
    for no, (sozluk, _) in nes.items():
        m = re.search(rb"/ToUnicode\s+(\d+) 0 R", sozluk)
        if m and re.search(rb"/Type\s*/Font\b", sozluk) and nes.get(int(m.group(1)), (b"", None))[1]:
            akis = nes[int(m.group(1))][1]
            yazitipi[no] = (cmap_oku(akis), cmap_genislik(akis))
    adlar = {}             # kaynak adı (F1) -> yazı tipi nesnesi
    for sozluk, _ in nes.values():
        for m in re.finditer(rb"/Font\s*(?:<<(.*?)>>|(\d+) 0 R)", sozluk, re.S):
            govde = m.group(1) if m.group(1) is not None else nes.get(int(m.group(2)), (b"", None))[0]
            for ad, ref in re.findall(rb"/([\w+-]+)\s+(\d+) 0 R", govde):
                adlar[ad.decode()] = int(ref)
    sayfalar = []
    for no in sorted(nes):
        sozluk, akis = nes[no]
        if not akis or not _icerik_akisi_mi(sozluk, akis):
            continue
        sayfalar.append(_icerik(akis, adlar, yazitipi, ctm))
    return sayfalar


def _icerik_akisi_mi(sozluk: bytes, akis: bytes) -> bool:
    """Sayfa içerik akışı: metin işleçleri (BT..Tf) var ve içerik düz metin; gömülü yazı tipi/görsel/ObjStm akışları değil."""
    if re.search(rb"/Length1|/Subtype\s*/(Image|Type1C|CIDFontType0C|OpenType)|/ObjStm|/XRef|/Metadata", sozluk):
        return False
    if not re.search(rb"\bBT\b", akis) or not re.search(rb"\bTf\b", akis):
        return False
    ornek = akis[:4000]
    yazdirilabilir = sum(1 for b in ornek if 32 <= b < 127 or b in (9, 10, 13))
    return yazdirilabilir >= 0.85 * len(ornek)           # ikili veri (yazı tipi dosyası vb.) metin işleci içerse bile içerik akışı değildir; 2 baytlı (\x00D) dizgiler %5-10 ikili bayt taşır


def satirlari_birlestir(parcalar: list, bosluk: float = 2.0) -> list:
    """Karakter karakter (ya da sözcük sözcük) konumlanmış metin parçalarını satırlara toplar: art arda gelen, aynı y'deki ve soldan sağa giden
    parçalar birleşir. [(x, y, boyut, metin)] -> [(metin, x_baş, x_son, y, boyut)]; x_son son parçanın başlangıcıdır."""
    sonuc, cur = [], None
    for x, y, boyut, metin in parcalar:
        if cur and abs(cur[3] - y) < 0.5 and x >= cur[2] - 0.01 and x - cur[2] <= boyut * bosluk:
            cur[0] += metin
            cur[2] = x
        else:
            if cur:
                sonuc.append(tuple(cur))
            cur = [metin, x, x, y, boyut]
    if cur:
        sonuc.append(tuple(cur))
    return sonuc


def _carp(m, n):
    """İki 2B dönüşüm matrisi [a b c d e f]: önce m, sonra n uygulanır."""
    return (m[0] * n[0] + m[1] * n[2], m[0] * n[1] + m[1] * n[3], m[2] * n[0] + m[3] * n[2], m[2] * n[1] + m[3] * n[3],
            m[4] * n[0] + m[5] * n[2] + n[4], m[4] * n[1] + m[5] * n[3] + n[5])


_BIRIM = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)


def _icerik(akis: bytes, adlar: dict, yazitipi: dict, ctm: bool = False) -> list:
    yigin, sonuc = [], []
    font, boyut, tx, ty, lx, ly, tl = None, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
    cm, cm_yigin, tlm = _BIRIM, [], _BIRIM          # yalnızca ctm=True: geçerli dönüşüm matrisi, q/Q yığını, metin satır matrisi
    for m in _TOKEN.finditer(akis):
        t = m.group(0)
        if not _OPERATOR.fullmatch(t) or t in (b"true", b"false", b"null"):
            yigin.append(float(t) if t[:1] in b"-+0123456789." else t)
            continue
        try:
            if ctm and t == b"q":
                cm_yigin.append(cm)
            elif ctm and t == b"Q":
                cm = cm_yigin.pop() if cm_yigin else _BIRIM
            elif ctm and t == b"cm":
                cm = _carp(tuple(float(v) for v in yigin[-6:]), cm)
            elif ctm and t == b"Tm":
                tlm = tuple(float(v) for v in yigin[-6:])
                tx, ty = tlm[4] * cm[0] + tlm[5] * cm[2] + cm[4], tlm[4] * cm[1] + tlm[5] * cm[3] + cm[5]
            elif ctm and t in (b"Td", b"TD"):
                tlm = _carp((1.0, 0.0, 0.0, 1.0, float(yigin[-2]), float(yigin[-1])), tlm)
                tx, ty = tlm[4] * cm[0] + tlm[5] * cm[2] + cm[4], tlm[4] * cm[1] + tlm[5] * cm[3] + cm[5]
            elif t == b"Tf":
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
                cmap, genislik = yazitipi.get(adlar.get(font, -1), (None, 2))
                parca = []
                for o in yigin:
                    if isinstance(o, bytes) and o[:1] == b"<" and o[:2] != b"<<":
                        ham = bytes.fromhex(re.sub(rb"\s", b"", o[1:-1]).decode() or "")
                    elif isinstance(o, bytes) and o[:1] == b"(":
                        ham = _dizgi_baytlari(o)
                    elif isinstance(o, float) and o < -200:           # TJ içindeki büyük boşluk ayarı: sözcük aralığı
                        parca.append(" ")
                        continue
                    else:
                        continue
                    if cmap:
                        parca += [cmap.get(int.from_bytes(ham[i:i + genislik], "big"), "") for i in range(0, len(ham) - genislik + 1, genislik)]
                    elif o[:1] == b"<":
                        parca += [bytes([b]).decode("cp1254", "ignore") for b in ham]
                    else:
                        parca.append(ham.decode("cp1254", "ignore"))
                metin = "".join(parca)
                if metin:
                    sonuc.append((round(tx, 1), round(ty, 1), boyut, metin))
        except (IndexError, ValueError):
            pass
        yigin = []
    return sonuc
