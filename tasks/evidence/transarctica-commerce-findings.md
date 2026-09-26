# FIC consumers — constats vérifiés

## VILLE.FIC

`main.alis` + trace: `cfreadb dest=MAIN+0x5fe4 len=0x008a`; `cdim` donne stride 3. VILLE.FIC = 138 octets = 46 triplets. Snapshot RAM confirme les 138 octets exacts au même offset.

Le consommateur est YODA: ses `omainc MAIN+0x5fe4` indexés via `tabchar` lisent le record `i` à `base + 3*i + champ` (indices `i` pris dans le mot local `0x30`, offsets de champ 0/1/2). TIME [0x2797..0x28d6] retrouve un record à partir des tuiles CARTE 71..76 et compare le champ 0 signé à `anchorX−40`, le champ 1 à `anchorY`. Décalages cellule→ancre dérivés de ses branches: 71:(+2,+1), 72:(+1,+1), 73:(0,+1), 74:(+2,0), 75:(+1,0), 76:(0,0). Donc `anchorX=signed(field0)+40`, `anchorY=field1`.

TEXTEK extrait par désassemblage donne 46 noms et six libellés selon `abs(field2)`: 1 TOWN, 2 COMMERCIAL CROSSROADS, 3 INDUSTRIAL TOWN, 4 GARRISON TOWN, 5 MAMMOTH FAIR, 6 SLAVE MARKET. Le signe brut reste conservé; TIME peut le modifier après visite. Avec les trois correspondances orthographiques explicites du CSV, les 43 guides dont la tuile est 71..76 concordent exactement avec l’ancre de leur record. Tibesti reste une observation distincte: guide (43,70), tuile 0; record nommé Tibesti `09 46 02`, ancre (49,70), tuile 76. Pas de correction supposée. Les 2 noms supplémentaires sans entrée CSV sont Alexandria (record 19) et Tribe of Nomads (record 45).

Le décodeur produit JSON/CSV privés: `reference-private/villes-decoded.{json,csv}`; code et tests: `tools/decode_cities.py`, `tests/test_decode_cities.py`.

## COMMERCE.FIC

Taille 1 472 = 46×32, facteurisation seulement. Aucun script `.CO` décompressé ne nomme ce FIC; la trace et le snapshot n’en montrent pas de lecture. Le consommateur et le schéma de COMMERCE restent inconnus.
