"""Üniversite eklentileri. Yeni üniversite: bu klasöre bir modül ekle, `Universite` alt sınıfı yaz, aşağıdaki listeye kaydet."""
from .adu import AydinAdnanMenderes
from .aku import AfyonKocatepe
from .duzce import DuzceUniversitesi
from .harran import HarranUniversitesi
from .mugla import MuglaSitkiKocman
from .trakya import TrakyaUniversitesi
from .yyu import VanYuzuncuYil
from .subu import SakaryaUygulamaliBilimler
from .btu import BursaTeknik
from .neu import NecmettinErbakan
from .kayseri import KayseriUniversitesi
from .nevsehir import NevsehirHaciBektasVeli
from .ahievran import KirsehirAhiEvran
from .aksaray import AksarayUniversitesi
from .ohu import NigdeOmerHalisdemir
from .karatekin import CankiriKaratekin
from .kastamonu import KastamonuUniversitesi
from .sinop import SinopUniversitesi
from .amasya import AmasyaUniversitesi
from .gop import TokatGaziosmanpasa
from .odu import OrduUniversitesi
from .giresun import GiresunUniversitesi
from .bayburt import BayburtUniversitesi
from .kafkas import KafkasUniversitesi
from .ardahan import ArdahanUniversitesi
from .alparslan import MusAlparslan
from .bingol import BingolUniversitesi
from .munzur import MunzurUniversitesi
from .siirt import SiirtUniversitesi
from .sirnak import SirnakUniversitesi
from .adiyaman import AdiyamanUniversitesi
from .kilis import Kilis7Aralik
from .mku import HatayMustafaKemal
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
from .inonu import InonuUniversitesi
from .iu import IstanbulUniversitesi
from .karabuk import KarabukUniversitesi
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
from .sdu import SuleymanDemirel
from .trabzon import TrabzonUniversitesi
from .uludag import BursaUludag
from .osmaniye import OsmaniyeKorkutAta
from .ksu import KahramanmarasSutcuImam
from .tarsus import TarsusUniversitesi
from .atu import AdanaAlparslanTurkes
from .maku import BurdurMehmetAkifErsoy
from .isubu import IspartaUygulamaliBilimler
from .usak import UsakUniversitesi
from .balikesir import BalikesirUniversitesi
from .bandirma import BandirmaOnyediEylul
from .nku import TekirdagNamikKemal
from .klu import KirklareliUniversitesi
from .bilecik import BilecikSeyhEdebali
from .yalova import YalovaUniversitesi
from .hitit import HititUniversitesi
from .bozok import YozgatBozok
from .bartin import BartinUniversitesi
from .rte import RecepTayyipErdogan
from .gumushane import GumushaneUniversitesi
from .bitlis import BitlisEren
from .batman import BatmanUniversitesi
from .erciyes import ErciyesUniversitesi
from .etu import ErzurumTeknik
from .agri import AgriIbrahimCecen
from .hakkari import HakkariUniversitesi
from .gibtu import GaziantepIslamBilimTeknoloji
from .kmu import KaramanogluMehmetbey
from .mtu import MalatyaTurgutOzal
from .iste import IskenderunTeknik
from .ksbu import KutahyaSaglikBilimleri
from .istiklal import IstiklalBilimTeknoloji

KAYITLI = [AnkaraUniversitesi(), GaziUniversitesi(), HacettepeUniversitesi(), AnkaraYildirimBeyazit(),
           OrtaDoguTeknik(), HaciBayramVeli(), AnkaraSosyalBilimler(), AnkaraMuzikGuzelSanatlar(),
           EskisehirOsmangazi(), EskisehirTeknik(),
           IstanbulUniversitesi(), IstanbulTeknik(), BogaziciUniversitesi(), MarmaraUniversitesi(), GalatasarayUniversitesi(),
           MimarSinanGuzelSanatlar(),
           EgeUniversitesi(), DokuzEylul(), IzmirKatipCelebi(),
           AlanyaAlaaddinKeykubat(), CanakkaleOnsekizMart(), SivasBilimTeknoloji(), SivasCumhuriyet(), AtaturkUniversitesi(),
           KaradenizTeknik(), TrabzonUniversitesi(), OndokuzMayis(), SamsunUniversitesi(), GebzeTeknik(),
           SakaryaUniversitesi(), CukurovaUniversitesi(), BursaUludag(), PamukkaleUniversitesi(), GaziantepUniversitesi(),
           SuleymanDemirel(), AydinAdnanMenderes(), InonuUniversitesi(), KarabukUniversitesi(),
           MuglaSitkiKocman(), AfyonKocatepe(), TrakyaUniversitesi(), HarranUniversitesi(), VanYuzuncuYil(), DuzceUniversitesi(),
           SakaryaUygulamaliBilimler(), BursaTeknik(), NecmettinErbakan(), KayseriUniversitesi(),
           NevsehirHaciBektasVeli(), KirsehirAhiEvran(), AksarayUniversitesi(),
           NigdeOmerHalisdemir(), CankiriKaratekin(), KastamonuUniversitesi(), SinopUniversitesi(), AmasyaUniversitesi(),
           TokatGaziosmanpasa(), OrduUniversitesi(), GiresunUniversitesi(), BayburtUniversitesi(),
           KafkasUniversitesi(), ArdahanUniversitesi(), MusAlparslan(), BingolUniversitesi(), MunzurUniversitesi(),
           SiirtUniversitesi(), SirnakUniversitesi(), AdiyamanUniversitesi(), Kilis7Aralik(), HatayMustafaKemal(),
           OsmaniyeKorkutAta(), KahramanmarasSutcuImam(), TarsusUniversitesi(), AdanaAlparslanTurkes(),
           BurdurMehmetAkifErsoy(), IspartaUygulamaliBilimler(), UsakUniversitesi(),
           BalikesirUniversitesi(), BandirmaOnyediEylul(), TekirdagNamikKemal(), KirklareliUniversitesi(),
           BilecikSeyhEdebali(), YalovaUniversitesi(), HititUniversitesi(),
           YozgatBozok(), BartinUniversitesi(), RecepTayyipErdogan(), GumushaneUniversitesi(),
           BitlisEren(), BatmanUniversitesi(), ErciyesUniversitesi(), ErzurumTeknik(),
           AgriIbrahimCecen(), HakkariUniversitesi(),
           GaziantepIslamBilimTeknoloji(), KaramanogluMehmetbey(), MalatyaTurgutOzal(),
           IskenderunTeknik(), KutahyaSaglikBilimleri(), IstiklalBilimTeknoloji()]
