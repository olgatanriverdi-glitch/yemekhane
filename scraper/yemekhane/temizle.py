"""Bütün eklentilerin ve birikimli kayıtların yayın öncesi yemek adı temizliği."""
import re

_TARIH = re.compile(r'(?<!\d)(?:\d{1,2}[./]\d{1,2}[./]\d{4}|\d{4}-\d{2}-\d{2})(?!\d)')
_BIRIM = r'(?:k\s*cal|k\s*kal|kalori|kal|cal)'
_KALORI = re.compile(r'(\d+(?:[.,]\d+)?(?:\s*[/–-]\s*\d+(?:[.,]\d+)?)*)\s*(?:' + _BIRIM + r'|\.k)\b', re.I)   # '180 Cal', '180.K'
_BOS_BIRIM = re.compile(r'\b' + _BIRIM + r'\b', re.I)
_GRAMAJ = re.compile(r'\b\d+(?:[.,]\d+)?\s*(?:gr(?:am)?|g|ml)\b', re.I)
_TATIL = re.compile(r'\b(?:tatil(?:dir)?|bayram(?:[ıi](?:m[ıi]z)?)?)\b|^\s*29\s+ekim\s*$', re.I)


def oge_temizle(oge):
    yeni = dict(oge)
    ad = str(yeni.get('name', ''))
    if _TATIL.search(ad):
        return None, '29 Ekim Cumhuriyet Bayramı' if re.fullmatch(r'\s*29\s+ekim\s*', ad, re.I) else ad.strip()
    ad = _TARIH.sub(' ', ad)
    sayilar = [float(n.replace(',', '.')) for m in _KALORI.finditer(ad)
               for n in re.findall(r'\d+(?:[.,]\d+)?', m.group(1))]
    ad = _KALORI.sub(' ', ad)
    ad = _BOS_BIRIM.sub(' ', ad)
    ad = _GRAMAJ.sub(' ', ad)
    ad = re.sub(r'\(\s*\)|\[\s*\]', ' ', ad)
    ad = re.sub(r'([\(\[])\s+', r'\1', ad)
    ad = re.sub(r'\s+([\)\]])', r'\1', ad)
    ad = re.sub(r'\s+', ' ', ad).strip(' /-–;:,.')
    yeni['name'] = ad
    if len(sayilar) > 1 or (sayilar and re.search(r'/|\bveya\b', ad, re.I)):
        yeni.pop('kcal', None)   # iki seçenek/aralık tek kalori veya toplam değildir
    elif len(sayilar) == 1 and not re.search(r'/|\bveya\b', ad, re.I) and sayilar[0] > 0:
        yeni['kcal'] = int(sayilar[0]) if sayilar[0].is_integer() else sayilar[0]
    return (yeni if ad else None), None


def menuleri_temizle(menuler):
    sonuc = {}
    for tarih, gun in menuler.items():
        sonuc[tarih] = {}
        for tur, ogun in gun.items():
            yeni, ogeler, notlar = dict(ogun), [], []
            for oge in ogun.get('items', []):
                temiz, not_ = oge_temizle(oge)
                if temiz:
                    ogeler.append(temiz)
                if not_ and not_ not in notlar:
                    notlar.append(not_)
            if notlar and ogeler and all(re.fullmatch(r'(?:Kutlu|Olsun|Kutlu Olsun)[!.]*', o['name'], re.I) for o in ogeler):
                # KTÜ bayram kutlamasını dört yemek sütununa bölüyor:
                # '29 Ekim' | 'Cumhuriyet Bayramımız' | 'Kutlu' | 'Olsun'.
                notlar = [' '.join(str(o.get('name', '')).strip() for o in ogun.get('items', []))]
                ogeler = []
            yeni['items'] = ogeler
            if notlar:
                notlar = list(dict.fromkeys(([yeni['note']] if yeni.get('note') else []) + notlar))
                yeni['note'] = '; '.join(notlar)
            kaloriler_degisti = [o.get('kcal') for o in ogeler] != [o.get('kcal') for o in ogun.get('items', [])]
            if not ogeler:
                yeni.pop('kcal', None)
                yeni.pop('photo', None)
                yeni.pop('photoApprox', None)
            elif kaloriler_degisti and 'kcal' in yeni:
                if all('kcal' in o for o in ogeler):
                    yeni['kcal'] = sum(o['kcal'] for o in ogeler)
                else:
                    yeni.pop('kcal', None)
            sonuc[tarih][tur] = yeni
    return sonuc
