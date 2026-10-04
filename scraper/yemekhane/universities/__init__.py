"""Üniversite eklentileri. Yeni üniversite: bu klasöre bir modül ekle, `Universite` alt sınıfı yaz, aşağıdaki listeye kaydet."""
from .ankara import AnkaraUniversitesi
from .asbu import AnkaraSosyalBilimler
from .aybu import AnkaraYildirimBeyazit
from .boun import BogaziciUniversitesi
from .esogu import EskisehirOsmangazi
from .estu import EskisehirTeknik
from .gazi import GaziUniversitesi
from .gsu import GalatasarayUniversitesi
from .hacettepe import HacettepeUniversitesi
from .hbv import HaciBayramVeli
from .itu import IstanbulTeknik
from .iu import IstanbulUniversitesi
from .marmara import MarmaraUniversitesi
from .mgu import AnkaraMuzikGuzelSanatlar
from .msgsu import MimarSinanGuzelSanatlar
from .odtu import OrtaDoguTeknik

KAYITLI = [AnkaraUniversitesi(), GaziUniversitesi(), HacettepeUniversitesi(), AnkaraYildirimBeyazit(),
           OrtaDoguTeknik(), HaciBayramVeli(), AnkaraSosyalBilimler(), AnkaraMuzikGuzelSanatlar(),
           EskisehirOsmangazi(), EskisehirTeknik(),
           IstanbulUniversitesi(), IstanbulTeknik(), BogaziciUniversitesi(), MarmaraUniversitesi(), GalatasarayUniversitesi(),
           MimarSinanGuzelSanatlar()]
