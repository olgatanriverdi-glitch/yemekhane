"""BAÜN: yılsız haftalık HTML; yıl, hafta günüyle doğrulanır ve biriktirilir."""
import re
from datetime import date, timedelta
from ..model import ay_no, bugun_tr, etiket_temizle, gun_icerigi
from ._son_ortak import HtmlUniversitesi, oge

SAYFA_URL = "https://balikesir.edu.tr/yemek-listesi"
GUNLER = ("Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma")


def sayfa_menu(sayfa, bugun=None):
    bugun = bugun or bugun_tr()
    h = re.search(r'<h2\b[^>]*>(.*?)</h2>\s*(<table\b.*?</table>)',sayfa,re.S)
    aralik = re.search(r"(\d+)\s+(\S+)\s*-\s*(\d+)\s+(\S+)\s+Yemek Listesi",etiket_temizle(h[1])) if h else None
    if not aralik or not ay_no(aralik[2]) or not ay_no(aralik[4]):
        return {}
    adaylar = []
    for yil in range(bugun.year-1,bugun.year+2):
        try:
            ilk,son = date(yil,ay_no(aralik[2]),int(aralik[1])), date(yil,ay_no(aralik[4]),int(aralik[3]))
            if ilk.weekday()==0 and (son-ilk).days==4:
                adaylar.append(ilk)
        except ValueError:
            continue
    if not adaylar:
        return {}
    ilk = min(adaylar,key=lambda d:abs((d-bugun).days))
    sonuc = {}
    for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>',h[2],re.S):
        hs = re.findall(r'<td\b[^>]*>(.*?)</td>',row,re.S)
        ad = etiket_temizle(hs[0]) if hs else ""
        if len(hs)!=6 or ad not in GUNLER:
            continue
        items = [o for o in (oge(x) for x in hs[1:5]) if o]
        if items:
            menu=gun_icerigi(items)
            k=re.search(r"(\d+)\s*kcal",etiket_temizle(hs[5]),re.I)
            if k:
                menu['kcal']=int(k[1])
            sonuc[(ilk+timedelta(days=GUNLER.index(ad))).isoformat()]={'lunch':menu}
    return sonuc


class BalikesirUniversitesi(HtmlUniversitesi):
    id, ad, kisa, sehir = "balikesir", "Balıkesir Üniversitesi", "BAÜN", "Balıkesir"
    kaynak = SAYFA_URL
    birikimli = True
    ayristir = staticmethod(sayfa_menu)
