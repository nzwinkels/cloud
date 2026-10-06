# Snowboard Lab

Eerste 3D-prototype voor oefenen met snowboardbochten op harde sneeuw.
Godot **4.6.x**, standaardversie met GDScript; getest met **4.6.3**.
Geen plugins, assetdownloads, accounts of andere dependencies nodig.

## Spelen

Open `project.godot` in Godot en druk op **F6** vanuit `scenes/piste.tscn`,
of **F5** om het project te starten. Vanuit een terminal met grafisch scherm:

```bash
./tools/godot.sh --editor
./tools/godot.sh
```

Op Windows/macOS kun je gewoon de Godot-editor gebruiken; het shellscript
is alleen een Linux/cloud-helper voor schrijfbare caches en logbestanden.
Een cloudtest zonder grafisch scherm geeft geen speelbaar venster.

## Besturing

| Beweging | Controller (Xbox-benamingen) | Toetsenbord |
| --- | --- | --- |
| Op je hielen hangen | LB | Q |
| Op je tenen hangen | RB | E |
| Bovenlichaam links/rechts draaien | Linker stick links/rechts | A / D |
| Gewicht naar voren/achteren | Rechter stick omhoog/omlaag | W / S |
| Terug naar start | A, onderste actieknop | R |
| Regular ↔ goofy | Y, bovenste actieknop | G |
| Pauze | Start | Esc |

Regular (linkervoet voor) is de standaard. In goofy liggen hiel- en teenkant
aan de andere zijde van het board; LB blijft altijd hielkant. De sticks
hebben een deadzone van 15%. Beide schouderknoppen tegelijk centreren het board.
Controllers die Godot als gamepad herkent gebruiken dezelfde semantische
knoppen; op PlayStation zijn de schouderknoppen L1/R1.

Begin zonder input en voel de versnelling. Houd een schouderknop vast en
geef rustig lichaamsrotatie met de linker stick. Laat de stick terugkomen
zodra je de gewenste boardrichting hebt. Voor remmen draai je het board
dwars op de helling en houd je een kant vast. Laat je de kant los, dan
slip je weer naar beneden. Een smal spoor en weinig zijwaartse slip wijzen
op grip; een breed spoor en oplopende slip wijzen op schuiven.

De piste is 84 meter breed en 360 meter lang, met een standaardhelling van
12°. Bij de rand of het einde keer je automatisch terug naar de start.
De camera volgt vanuit een vast perspectief achter de afdaling.

## Wat de fysica nu doet

`scripts/snow_model.gd` berekent beweging in meters en seconden op een vlakke
helling. Zwaartekracht versnelt langs de helling. Basiswrijving en
kwadratische luchtweerstand vertragen het board. Snelheid heeft geen harde
arcadelimiet. Kantengrip remt zijwaartse beweging, met een begrensd
wrijvingsbudget: vraagt een bocht te veel grip, dan blijft er slip over.
Dezelfde wrijving kan het dwarsgezette board op de helling stilhouden.

Een vereenvoudigde sidecut-respons laat een gekant board een bocht inzetten.
Lichaamsrotatie stuurt een gedempte draairespons in plaats van onmiddellijk
de rijrichting te veranderen. Voorwaarts gewicht verhoogt de stuurrespons;
achterwaarts gewicht vermindert die. Input wordt geleidelijk verwerkt en
de simulatie draait op 120 Hz, onafhankelijk van de renderfrequentie.

**Dit is een afstelbaar eerste model, geen gevalideerde snowboardsimulator.**
De snowboarder is een puntmassa die op het pistevlak blijft. De sidecut,
lichaamsrotatie en drukverdeling zijn benaderingen; boardflex, echte
contactkrachten per voet, kanten happen, botsingen, vallen, sprongen,
oneffen terrein en poedersneeuw zijn nog niet gesimuleerd. De sneeuwsporen
zijn visueel; sneeuwspray is nog niet toegevoegd. Er is nog geen aparte
modellus voor switch rijden.

Selecteer `SnowboardLab` in `scenes/piste.tscn` om helling, sidecutradius,
kantengrip, vlakke wrijving en lichaamsrespons in de Inspector af te stellen.
De overige parameters staan bovenaan `snow_model.gd`. De eigenlijke
beweging staat los van de voorstelling en HUD in `scripts/piste.gd`.

De logische volgende stap is controller-playtesting: klopt het gevoel bij
een ervaren snowboarder? Daarna de drukverdeling en kantengrip verfijnen,
vervolgens contact met variabel terrein en een afzonderlijk sneeuwmodel
voor poeder en spray toevoegen.

## Controles

```bash
./tools/godot.sh --headless --editor --import
./tools/godot.sh --headless --script res://tests/physics_test.gd
./tools/godot.sh --headless --script res://tests/scene_test.gd
./tools/godot.sh --headless --quit-after 240
```

De fysicatests controleren versnelling, wrijving, bochten, stoppen,
stilstaan, gewicht, goofy, tijdstapgevoeligheid en numerieke stabiliteit.
De scenetest start de echte piste en controleert invoeracties, HUD,
sneeuwsporen, pauze, opnieuw beginnen en pistegrenzen.
Dat bewijst technische werking; het bewijst niet dat het rijgevoel
overeenkomt met echte sneeuw. Een fysieke controller is in de cloud
nog niet door een speler getest.

Gebruik de bestaande checkout; elke cloudtaak is al geïsoleerd en vereist
geen extra Git-worktree. De map `.godot/` is gegenereerd en genegeerd.
