"""Üniversite eklentileri. Yeni üniversite: bu klasöre bir modül ekle, `Universite` alt sınıfı yaz, aşağıdaki listeye kaydet."""
from .ankara import AnkaraUniversitesi
from .aybu import AnkaraYildirimBeyazit
from .gazi import GaziUniversitesi
from .hacettepe import HacettepeUniversitesi

KAYITLI = [AnkaraUniversitesi(), GaziUniversitesi(), HacettepeUniversitesi(), AnkaraYildirimBeyazit()]
