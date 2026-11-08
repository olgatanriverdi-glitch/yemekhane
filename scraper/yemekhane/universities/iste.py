"""İSTE SKS'nin en yeni duyurusu ve gramaj/kalorili aylık metin PDF'i."""
import re
from urllib.parse import urljoin
from .. import pdf
from ..model import etiket_temizle,gun_icerigi
from ._son_ortak import oge,tarih
from ._son_pdf import satirlar,birlestir,BaglantiliPdfUniversitesi

SAYFA_URL='https://iste.edu.tr/sksdb'
SINIRLAR=(0,177,348,505,668,843)
GRAM_KALORI=((125,154),(295,324),(451,480),(616,643),(791,820))


def pdf_menu(veri):
    sonuc={}
    for sayfa in pdf.sayfa_metinleri(veri):
        for (sol,sag),(gram_x,kal_x) in zip(zip(SINIRLAR,SINIRLAR[1:]),GRAM_KALORI):
            rows=satirlar([(x,y,b,t) for x,y,b,t in sayfa if sol<=x<sag and y>100],tolerans=1.2)
            basliklar=[(y,tarih(''.join(t for _,t in p))) for y,p in rows]
            basliklar=[(y,t) for y,t in basliklar if t]
            for n,(ust,t) in enumerate(basliklar):
                alt=basliklar[n+1][0] if n+1<len(basliklar) else 100
                items=[]
                for y,parcalar in rows:
                    if not alt<y<ust:
                        continue
                    gram=''.join(v.strip() for x,v in parcalar if x<kal_x-3 and v.strip().isdigit())
                    kalori=''.join(v.strip() for x,v in parcalar if x>=kal_x-3 and v.strip().isdigit())
                    if not gram or not kalori:
                        continue
                    ad=birlestir([(x,v) for x,v in parcalar if not v.strip().isdigit()]).replace('*','')
                    ad=re.sub(r'(?<=[a-zçğıöşü])(?=[A-ZÇĞİÖŞÜ])',' ',ad)
                    o=oge(ad)
                    if o:
                        o['kcal']=int(kalori)  # Ayrı sütundaki ilk sayı gramajdır.
                        items.append(o)
                if items:
                    if len(items)!=4:
                        raise ValueError('İSTE: PDF gününde dört yemek/gramaj/kalori eşleşmedi (%s, %d kalem)'%(t,len(items)))
                    sonuc[t.isoformat()]={'lunch':gun_icerigi(items)}
    return sonuc


class IskenderunTeknik(BaglantiliPdfUniversitesi):
    id,ad,kisa,sehir='iste','İskenderun Teknik Üniversitesi','İSTE','Hatay'
    kaynak=SAYFA_URL
    ayristir=staticmethod(pdf_menu)

    def pdf_baglantisi(self,sayfa):
        duyurular=[]
        for u,b in re.findall(r'<a[^>]*href=[\'\"]([^\'\"]+)[\'\"][^>]*>(.*?)</a>',sayfa,re.S):
            if 'YEMEK MENÜSÜ' in etiket_temizle(b):
                duyurular.append(urljoin(SAYFA_URL,u))
        if not duyurular:
            return None
        url=max(duyurular)
        try:
            icerik=self.indir(url).decode('utf-8-sig')
        except Exception as e:
            raise RuntimeError('İSTE: yemek duyurusu indirilemedi: %s'%e) from e
        for u,b in re.findall(r'<a[^>]*href=[\'\"]([^\'\"]+)[\'\"][^>]*>(.*?)</a>',icerik,re.S):
            if 'YEMEK MENÜSÜ' in etiket_temizle(b) and u.endswith('.pdf'):
                return urljoin(url,u)
        return None
