"""Üniversite eklentileri. Yeni üniversite: bu klasöre bir modül ekle, `Universite` alt sınıfı yaz, aşağıdaki listeye kaydet."""
from .alku import AlanyaAlaaddinKeykubat
from .ankara import AnkaraUniversitesi
from .asbu import AnkaraSosyalBilimler
from .atauni import AtaturkUniversitesi
from .aybu import AnkaraYildirimBeyazit
from .boun import BogaziciUniversitesi
from .cukurova import CukurovaUniversitesi
from .comu import CanakkaleOnsekizMart
from .cumhuriyet import SivasCumhuriyet
from .deu import DokuzEylul
from .ege import EgeUniversitesi
from .esogu import EskisehirOsmangazi
from .estu import EskisehirTeknik
from .gaziantep import GaziantepUniversitesi
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
from .pamukkale import PamukkaleUniversitesi
from .omu import OndokuzMayis
from .sakarya import SakaryaUniversitesi
from .samsun import SamsunUniversitesi
from .sbtu import SivasBilimTeknoloji
from .trabzon import TrabzonUniversitesi
from .uludag import BursaUludag

KAYITLI = [AnkaraUniversitesi(), GaziUniversitesi(), HacettepeUniversitesi(), AnkaraYildirimBeyazit(),
           OrtaDoguTeknik(), HaciBayramVeli(), AnkaraSosyalBilimler(), AnkaraMuzikGuzelSanatlar(),
           EskisehirOsmangazi(), EskisehirTeknik(),
           IstanbulUniversitesi(), IstanbulTeknik(), BogaziciUniversitesi(), MarmaraUniversitesi(), GalatasarayUniversitesi(),
           MimarSinanGuzelSanatlar(),
           EgeUniversitesi(), DokuzEylul(), IzmirKatipCelebi(),
           AlanyaAlaaddinKeykubat(), CanakkaleOnsekizMart(), SivasBilimTeknoloji(), SivasCumhuriyet(), AtaturkUniversitesi(),
           KaradenizTeknik(), TrabzonUniversitesi(), OndokuzMayis(), SamsunUniversitesi(), GebzeTeknik(),
           SakaryaUniversitesi(), CukurovaUniversitesi(), BursaUludag(), PamukkaleUniversitesi(), GaziantepUniversitesi()]
