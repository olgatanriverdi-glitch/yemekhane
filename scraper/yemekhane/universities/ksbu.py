"""KSBÜ: çizim dönüşümlü, harf harf metin PDF; günlük enerji tek toplamdır."""
import re
from .. import pdf
from ._son_ortak import oge,tarih
from ._son_pdf import BaglantiliPdfUniversitesi

SAYFA_URL='https://sks.ksbu.edu.tr/defaultx/slide/5613/ksbu-yemek-listesi'
SAYI=rb'[-+]?\d+(?:\.\d+)?'
# PDF'in .05 ölçekli Calibri tablosunun ad/enerji sütunları.
SUTUNLAR=((65,180,216),(216,314,350),(350,458,505),(505,613,642),(642,738,790))


def harf_genislikleri(veri):
    nes=pdf.nesneler(veri)
    sonuc={}
    for d,_ in nes.values():
        cm=re.search(rb'/ToUnicode\s+(\d+) 0 R',d)
        desc=re.search(rb'/DescendantFonts\s*\[\s*(\d+) 0 R',d)
        if not cm or not desc:
            continue
        font=nes[int(desc[1])][0]
        w=re.search(rb'/W\s*\[(.*)\]',font,re.S)
        if not w:
            continue
        ws={}
        for bas,son,v,seq in re.findall(rb'(\d+)\s*(?:(\d+)\s+('+SAYI+rb')|\[([^]]+)\])',w[1]):
            if seq:
                ws.update((int(bas)+i,float(v)) for i,v in enumerate(re.findall(SAYI,seq)))
            else:
                ws.update((i,float(v)) for i in range(int(bas),int(son)+1))
        for kod,harf in pdf.cmap_oku(nes[int(cm[1])][1]).items():
            sonuc.setdefault(harf,ws.get(kod,506))
    return sonuc


def harfleri_birlestir(parcalar,genislikler):
    sonuc=''
    onceki=None
    for x,b,t in sorted(parcalar):
        if onceki:
            px,pb,pc=onceki
            aralik=x-px-genislikler.get(pc,506)*pb*.05/1000
            if aralik>1.1:
                sonuc+=' '
        sonuc+=t
        onceki=(x,b,t)
    return sonuc.strip()


def yemek_adi(ad):
    for kalip,yeni in ((r'\bKIY\.LI\s*','Kıymalı '),(r'\bPEY\.Lİ\s*','Peynirli '),
                        (r'\bŞEH\.Lİ\s*','Şehriyeli '),(r'\bKAŞ\.LI\s*','Kaşarlı '),
                        (r'\bZYT\.LI\s*','Zeytinyağlı '),(r'\bYOĞ\.(?=\s|$)','Yoğurt'),
                        (r'KURUFASÜLYE','Kuru Fasulye')):
        ad=re.sub(kalip,yeni,ad,flags=re.I)
    return oge(ad)


def pdf_menu(veri):
    widths=harf_genislikleri(veri)
    sonuc={}
    for sayfa in pdf.sayfa_metinleri(veri,ctm=True):
        for sol,kal,sag in SUTUNLAR:
            parcalar=[(x,y,b,c) for x,y,b,c in sayfa if sol<=x<sag and y>95]
            gruplar={}
            for x,y,b,c in parcalar:
                yy=next((yy for yy in gruplar if abs(yy-y)<.2),y)
                gruplar.setdefault(yy,[]).append((x,b,c))
            rows=[(y,harfleri_birlestir([p for p in gruplar[y] if p[0]<kal],widths),
                     harfleri_birlestir([p for p in gruplar[y] if p[0]>=kal],widths)) for y in sorted(gruplar,reverse=True)]
            basliklar=[(y,tarih(ad)) for y,ad,k in rows if tarih(ad)]
            for n,(ust,t) in enumerate(basliklar):
                alt=basliklar[n+1][0] if n+1<len(basliklar) else 95
                adlar,kaloriler=[],[]
                for y,ad,k in rows:
                    if not alt<y<ust-18:
                        continue
                    if k.isdigit():
                        kaloriler.append(int(k))
                    if ad:
                        if adlar and adlar[-1].endswith(('/',' SOSLU')):
                            adlar[-1]+=('' if adlar[-1].endswith('/') else ' ')+ad
                        else:
                            adlar.append(ad)
                items=[o for o in (yemek_adi(ad) for ad in adlar) if o]
                if items:
                    if len(items)!=4 or len(kaloriler)!=1:
                        raise ValueError('KSBÜ: PDF gününde dört yemek ve tek enerji toplamı eşleşmedi (%s)'%t)
                    sonuc[t.isoformat()]={'lunch':{'items':items,'kcal':kaloriler[0]}}
    return sonuc


class KutahyaSaglikBilimleri(BaglantiliPdfUniversitesi):
    id,ad,kisa,sehir='ksbu','Kütahya Sağlık Bilimleri Üniversitesi','KSBÜ','Kütahya'
    kaynak=SAYFA_URL
    ayristir=staticmethod(pdf_menu)
    baglanti_uygun=staticmethod(lambda ad:'aylık yemek' in ad and 'çölyak' not in ad)
