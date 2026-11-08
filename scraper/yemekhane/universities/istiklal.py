"""İBTÜ: Angular CMS'nin girişsiz sayfa/yazı JSON'u; en güncel dolu ay."""
import json
from datetime import date
from urllib.request import Request
from ..model import bugun_tr
from ._son_ortak import oge
from .base import Universite,UA,indir

SAYFA_URL='https://www.istiklal.edu.tr/sksdb/beslenme-ve-kafeterya'
SAYFA_API='https://istiklal.edu.tr/api/pages/get'
MENU_API='https://istiklal.edu.tr/api/posts/get'
AYLAR=('January','February','March','April','May','June','July','August','September','October','November','December')


def json_indir(url,veri):
    istek=Request(url,data=json.dumps(veri).encode('utf-8'),headers={'User-Agent':UA,'Content-Type':'application/json'})
    return indir(istek)


def json_menu(yazi,bugun=None):
    bugun=bugun or bugun_tr()
    if not isinstance(yazi,dict) or not isinstance(yazi.get('content'),str):
        return {}
    agac,_=json.JSONDecoder().raw_decode(yazi['content'].lstrip())
    if not isinstance(agac,dict):
        return {}
    sonuc={}
    for node in agac.get('componentTree',[]):
        if node.get('selector')!='args-ahbv-food-list':
            continue
        for ay in node.get('arguments',{}).get('foodLists',[]):
            ayadi=str(ay.get('monthName','')).replace('GENERAL.','')
            if ayadi not in AYLAR:
                continue
            for g in ay.get('dailyFoodLists',[]):
                try:
                    t=date.fromisoformat(str(g.get('date',''))[:10])
                except ValueError:
                    continue
                if t.year!=ay.get('year') or t.month!=AYLAR.index(ayadi)+1:
                    continue
                items=[o for o in (oge(str(f.get('foodName','')).replace('S. Mercimek','Süzme Mercimek')) for f in g.get('foods',[]) if isinstance(f,dict)) if o]
                if items:
                    menu={'items':items}
                    k=g.get('calorie')
                    if isinstance(k,(int,float)) and k>0:
                        menu['kcal']=int(k)
                    sonuc[t.isoformat()]={'lunch':menu}
    aylar={t[:7] for t in sonuc if t[:7]<=bugun.isoformat()[:7]}
    son=max(aylar) if aylar else ''
    return {t:g for t,g in sonuc.items() if son and t.startswith(son)}


class IstiklalBilimTeknoloji(Universite):
    id,ad,kisa,sehir='istiklal','İstiklal Bilim ve Teknoloji Üniversitesi','İBTÜ','Kahramanmaraş'
    kaynak=SAYFA_URL

    def __init__(self,indirici=json_indir):
        self.indir=indirici

    def menuler(self):
        try:
            sayfa=json.loads(self.indir(SAYFA_API,{'originId':'1','language':'tr-TR','slug':'sksdb'}).decode('utf-8-sig'))
            if not isinstance(sayfa,dict) or not sayfa.get('id'):
                raise ValueError('SKS sayfa kimliği bulunamadı')
            veri=self.indir(MENU_API,{'pageId':sayfa['id'],'language':'tr-TR','slug':'beslenme-ve-kafeterya'})
        except (OSError,TimeoutError) as e:
            raise RuntimeError('İstiklal: yemek JSON indirilemedi: %s'%e) from e
        except (ValueError,TypeError) as e:
            raise RuntimeError("İstiklal: SKS sayfa JSON'u okunamadı: %s"%e) from e
        try:
            sonuc=json_menu(json.loads(veri.decode('utf-8-sig')))
        except (ValueError,TypeError) as e:
            raise RuntimeError("İstiklal: yemek JSON'u okunamadı: %s"%e) from e
        if not sonuc:
            raise RuntimeError('İstiklal: tarihli yemek menüsü bulunamadı')
        return sonuc
