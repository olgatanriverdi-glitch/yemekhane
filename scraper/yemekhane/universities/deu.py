"""Dokuz Eylül Üniversitesi (İzmir): aylık menü sks.deu.edu.tr/yemek-menusu/ sayfasında yalnızca resim olarak yayınlanıyor (normal liste ve ayrı bir vegan liste;
resimlerde kalem kalorisi yok, günün toplam kalorisi var ve 50 gr ekmek dahil). Menü `elle_veri/deu.json` dosyasına resimden elle girilir: normal liste -> öğle (lunch),
vegan liste -> vejetaryen (vegetarian). Her ay okul yeni resmi koyunca dosyaya o ayın günleri eklenmelidir.
"""
from .base import ElleUniversite


class DokuzEylul(ElleUniversite):
    id = "deu"
    ad = "Dokuz Eylül Üniversitesi"
    kisa = "DEÜ"
    sehir = "İzmir"
    kaynak = "https://sks.deu.edu.tr/yemek-menusu/"
