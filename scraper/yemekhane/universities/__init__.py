"""Üniversite eklentileri. Yeni üniversite: bu klasöre bir modül ekle, `Universite` alt sınıfı yaz, aşağıdaki listeye kaydet."""
from .ankara import AnkaraUniversitesi
from .asbu import AnkaraSosyalBilimler
from .aybu import AnkaraYildirimBeyazit
from .gazi import GaziUniversitesi
from .hacettepe import HacettepeUniversitesi
from .hbv import HaciBayramVeli
from .mgu import AnkaraMuzikGuzelSanatlar
from .odtu import OrtaDoguTeknik

KAYITLI = [AnkaraUniversitesi(), GaziUniversitesi(), HacettepeUniversitesi(), AnkaraYildirimBeyazit(),
           OrtaDoguTeknik(), HaciBayramVeli(), AnkaraSosyalBilimler(), AnkaraMuzikGuzelSanatlar()]
