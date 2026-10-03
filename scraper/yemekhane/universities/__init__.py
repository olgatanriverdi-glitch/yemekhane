"""Üniversite eklentileri. Yeni üniversite: bu klasöre bir modül ekle, `Universite` alt sınıfı yaz, aşağıdaki listeye kaydet."""
from .ankara import AnkaraUniversitesi
from .gazi import GaziUniversitesi

KAYITLI = [AnkaraUniversitesi(), GaziUniversitesi()]
