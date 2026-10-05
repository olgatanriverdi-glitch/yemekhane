"""Trabzon Üniversitesi: aylık menü sks.trabzon.edu.tr/S/8978 ('Aylık Yemek Listesi') sayfasında yalnızca bir Excel ekran görüntüsü (PNG) olarak yayınlanıyor; her günde 4 kalem,
kalem kalorisi ve günlük toplam var. Menü `elle_veri/trabzon.json` dosyasına resimden elle girilir (her günün toplamı kalem toplamıyla doğrulandı). Her ay okul yeni
resmi koyunca dosyaya o ayın günleri eklenmelidir.
"""
from .base import ElleUniversite


class TrabzonUniversitesi(ElleUniversite):
    id = "trabzon"
    ad = "Trabzon Üniversitesi"
    kisa = "TÜ"
    sehir = "Trabzon"
    kaynak = "https://sks.trabzon.edu.tr/S/8978"
