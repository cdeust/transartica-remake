# SPDX-License-Identifier: MIT
"""Build metadata and an offline gallery from delivered artwork; never edits PNGs."""
from pathlib import Path
from PIL import Image
import json, hashlib, html
D=Path(__file__).resolve().parent
labels={
'captain-boudoir':'Boudoir du capitaine','command-room-background':'Salle de commandement — décor seul',
'city-trading-station':'Ville marchande','city-industrial-workshop':'Atelier ferroviaire','city-mammoth-fair':'Marché aux mammouths','city-information':'Ville de renseignements','city-slave-market':'Marché aux esclaves','city-garrison':'Garnison','coal-mine':'Mine de charbon',
'rail-track-kit':'Rails et aiguillages','world-landmarks-kit':'Lieux de la carte','world-chart-frame':'Cadre de la carte — centre transparent','bridge-works-alpha':'Obstacles et travaux — trois états',
'combat-background':'Combat — décor sans trains','combat-train-kit':'Combat — six véhicules principaux','combat-scene-reference':'Combat — composition de référence','combat-actors-kit':'Soldats, mammouths et acteurs','combat-equipment-kit':'Armement et équipements séparés','combat-wagons-04-10':'Combat — types 4 à 9','combat-wagons-10-17':'Combat — types 10, 12 à 16','combat-wagons-17-25':'Combat — sept autres types','combat-effects-kit':'Effets et dégâts — poses clés','enemy-train-kit':'Trains adverses — propositions graphiques','crew-and-city-characters':'Équipage et personnages — portraits et découpes',
'event-railway-works':'Rencontre — travaux ferroviaires','event-nomad-camp':'Rencontre — camp nomade','event-tunnel-ambush':'Rencontre — embuscade dans le tunnel','final-project-sun-overcast':'Projet Soleil — ciel couvert','final-project-sun-restored':'Projet Soleil — retour du soleil','story-urga-refuge':'Urga — refuge et clé','story-mammoth-mausoleum':'Mausolée du mammouth','story-oslo-vault':'Oslo — coffre et appareil Geiger'}
mapping={'combat-train-kit':([1,21,2,3,23,11],3,2),'combat-wagons-04-10':([4,5,6,7,8,9],2,3),'combat-wagons-10-17':([10,12,13,14,15,16],2,3),'combat-wagons-17-25':([17,18,19,20,22,24,25],2,4)}
observed={'captain-boudoir','command-room-background','city-trading-station','city-information','city-slave-market','city-garrison','coal-mine','event-railway-works','event-nomad-camp','event-tunnel-ambush','final-project-sun-overcast','final-project-sun-restored','combat-background','combat-scene-reference'}
rows=[]
for j in json.loads((D/'generation-record.json').read_text()):
 p=D/(j['id']+'.png')
 with Image.open(p) as im:
  im.load(); a=im.convert('RGBA').getchannel('A'); hist=a.histogram(); dims=list(im.size)
 r={'id':j['id'],'title':labels[j['id']],'file':p.name,'prompt':'prompts/'+j['id']+'.txt','width':dims[0],'height':dims[1],'alpha_min':a.getextrema()[0],'alpha_max':a.getextrema()[1],'fully_transparent_percent':round(100*hist[0]/(dims[0]*dims[1]),2),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'source_images':j.get('refs',[]),'provenance':'composition observée, dessin réinterprété' if j['id'] in observed else 'adaptation / extrapolation artistique','integration_status':'design livré ; intégration non effectuée par Codex'}
 if j['id'] in mapping:
  ids,c,l=mapping[j['id']];r['wagon_sheet']={'type_ids_reading_order':ids,'columns':c,'rows':l,'order':'gauche à droite, haut en bas','note':'cellules de rangement seulement ; découpe et ancrages à relever sur le dessin'}
 rows.append(r)
assert sorted(x for ids,_,_ in mapping.values() for x in ids)==list(range(1,26))
assert len(rows)==32 and len(list(D.glob('*.png')))==32
(D/'manifest.json').write_text(json.dumps({'date':'2026-09-27','count':len(rows),'assets':rows},ensure_ascii=False,indent=2)+'\n')
cards=[]
for r in rows:
 esc=html.escape
 cards.append(f'<article><a href="{r["file"]}"><img loading="lazy" src="{r["file"]}" alt="{esc(r["title"])}"></a><h2>{esc(r["title"])}</h2><p>{r["width"]} × {r["height"]} · {esc(r["provenance"])}</p><a href="{r["file"]}">PNG original</a> · <a href="{r["prompt"]}">Prompt</a></article>')
(D/'index.html').write_text('''<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Transartica — 32 visuels</title><style>body{margin:0;background:#111b24;color:#e9e3d5;font:16px system-ui}header,main{max-width:1500px;margin:auto;padding:28px}h1{font-size:32px}p{line-height:1.5;color:#bfcbd2}a{color:#e7bc73}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(360px,1fr));gap:24px}article{background:#1a2833;padding:14px;border:1px solid #334652;border-radius:8px}img{width:100%;height:270px;object-fit:contain;background:repeating-conic-gradient(#263745 0% 25%,#304351 0% 50%) 0/20px 20px;image-rendering:pixelated}h2{font-size:19px}article p{font-size:14px}@media(max-width:450px){main{display:block}article{margin-bottom:20px}header,main{padding:16px}}</style><header><h1>Transartica · Visuels du 27 septembre</h1><p>32 dessins et planches pour l’intégration par Opus. Villes, intérieurs, combat, carte, voies, travaux et récit. Cliquer une image pour sa pleine définition.</p><p>Les compositions observées sont réinterprétées ; les autres propositions sont signalées. Les planches demandent une découpe et une calibration en jeu. L’inventaire des variantes originales reste ouvert.</p><a href="../../../tasks/handoff-visuals-20260927.md">Remise à Opus</a> · <a href="manifest.json">Manifeste et empreintes</a></header><main>'''+''.join(cards)+'</main></html>\n')
print(json.dumps({'png':len(rows),'wagon_types':25,'with_transparency':sum(r['alpha_min']<255 for r in rows),'bytes':sum((D/r['file']).stat().st_size for r in rows)},indent=2))
