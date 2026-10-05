"""Gebze Teknik Üniversitesi: aylık menü gtu.edu.tr 'Yemek Listesi ve Mobil Uygulama' sayfasında yalnızca resim olarak ('EKİM 2026 MENÜ.jpg') yayınlanıyor; her günde 7-8 kalem
(çorba, ana yemek, pilav/makarna, tatlı, salata, turşu...) ve kalem kalorisi var. Menü `elle_veri/gtu.json` dosyasına resimden elle girilir. Her ay okul yeni resmi
koyunca dosyaya o ayın günleri eklenmelidir.
"""
from .base import ElleUniversite


class GebzeTeknik(ElleUniversite):
    id = "gtu"
    ad = "Gebze Teknik Üniversitesi"
    kisa = "GTÜ"
    sehir = "Kocaeli"
    kaynak = "https://www.gtu.edu.tr/kategori/1296/0/display.aspx"
