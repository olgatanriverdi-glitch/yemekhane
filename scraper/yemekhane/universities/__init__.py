"""Üniversite eklentileri. Yeni üniversite: bu klasöre bir modül ekle, `Universite` alt sınıfı yaz, aşağıdaki listeye kaydet."""
from .alku import AlanyaAlaaddinKeykubat
from .ankara import AnkaraUniversitesi
from .asbu import AnkaraSosyalBilimler
from .atauni import AtaturkUniversitesi
from .aybu import AnkaraYildirimBeyazit
from .boun import BogaziciUniversitesi
from .comu import CanakkaleOnsekizMart
from .cumhuriyet import SivasCumhuriyet
from .deu import DokuzEylul
from .ege import EgeUniversitesi
from .esogu import EskisehirOsmangazi
from .estu import EskisehirTeknik
from .gazi import GaziUniversitesi
from .gsu import GalatasarayUniversitesi
from .gtu import GebzeTeknik
from .hacettepe import HacettepeUniversitesi
from .hbv import HaciBayramVeli
from .ikcu import IzmirKatipCelebi
from .itu import IstanbulTeknik
from .iu import IstanbulUniversitesi
from .ktu import KaradenizTeknik
from .marmara import MarmaraUniversitesi
from .mgu import AnkaraMuzikGuzelSanatlar
from .msgsu import MimarSinanGuzelSanatlar
from .odtu import OrtaDoguTeknik
from .omu import OndokuzMayis
from .samsun import SamsunUniversitesi
from .sbtu import SivasBilimTeknoloji
from .trabzon import TrabzonUniversitesi

KAYITLI = [AnkaraUniversitesi(), GaziUniversitesi(), HacettepeUniversitesi(), AnkaraYildirimBeyazit(),
           OrtaDoguTeknik(), HaciBayramVeli(), AnkaraSosyalBilimler(), AnkaraMuzikGuzelSanatlar(),
           EskisehirOsmangazi(), EskisehirTeknik(),
           IstanbulUniversitesi(), IstanbulTeknik(), BogaziciUniversitesi(), MarmaraUniversitesi(), GalatasarayUniversitesi(),
           MimarSinanGuzelSanatlar(),
           EgeUniversitesi(), DokuzEylul(), IzmirKatipCelebi(),
           AlanyaAlaaddinKeykubat(), CanakkaleOnsekizMart(), SivasBilimTeknoloji(), SivasCumhuriyet(), AtaturkUniversitesi(),
           KaradenizTeknik(), TrabzonUniversitesi(), OndokuzMayis(), SamsunUniversitesi(), GebzeTeknik()]
