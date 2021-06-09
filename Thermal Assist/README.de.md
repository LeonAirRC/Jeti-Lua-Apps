# Thermikassistent
Diese App basiert auf einem System, das in bemannten Segelflugzeugen eingesetzt wird, und hilft dabei den optimalen Kreispunkt in der Thermik zu finden.
Eine regelmäßige Sprachansage nennt dem Piloten die Richtung und die Strecke, um welche der Kreis verlagert werden sollte.\
Dafür werden ein GPS und ein Vario oder ein Höhenmesser benötigt.

### [Installation](https://github.com/LeonAirRC/Jeti-Lua-Apps#installation)

## So funktionierts
Die GPS-Position und die Steigraten werden in regelmäßigen Intervallen abgefragt.\
Jeder Messpunkt wird in einem Telemetriefenster als ein Kreis angezeigt, wobei der Radius proportional vom dortigen Steigen abhängt.
Stellen, an denen es nicht steigt, werden nur als Punkt dargestellt.\
Der Flugweg wird immer so gekürzt, dass er eine Drehung von maximal 360° enthält, also immer nur den letzen Kreis repräsentiert.\
Basierend auf den Steigwerten entlang des Weges und dem ausgewählten Algorithmus wird dann der optimale Punkt berechnet.\
Die Sprachansage enthält daraufhin die Richtung (°) und die Entfernung dieses Punktes relativ zum Mittelpunkt des letzen Kreises.
Außerdem wird die Steigrate ausgegeben, die dort zu erwarten ist, falls diese bekannt ist.

#### Switch
Die App ist genau dann nicht aktiv, wenn hier ein Schalter ausgewählt ist und er sich in der Aus-Position befindet.
Dann werden keine neuen Messpunkte hinzugefügt und die Sprachausgabe ist deaktiviert.

#### Messintervall
Der zeitliche Abstand zwischen zwei Messungen [ms].

#### Ansageintervall
Der zeitliche Abstand zwischen zwei Sprachansagen [s].

#### Suchmodus umschalten
Dieser Schalter schaltet den Suchmodus ein. In diesem Modus wird der Flugweg nicht mehr auf einen Kreis begrenzt und die Sprachansage nutzt anstelle des Mittelpunkts nun die aktuelle Position als Bezugspunkt.

#### Im Suchmodus immer Algorithmus 1 nutzen
Wenn dies ausgewählt ist, wird im Suchmodus immer der Beste-Teilsequenz Algorithmus genutzt, da dieser zum suchen am besten geeignet ist.

#### Verzögerung
Fügt eine künstliche Verzögerung hinzu, um das häufig stark verzögerte Verhalten von Varios zu kompensieren.
Dieser Parameter beschreibt die Anzahl an Messpunkten, um die die Steigraten zeitlich nach hinten geschoben werden.
Wenn z.B. das Messintervall auf 0,8s eingestellt ist und das Vario eine Ansprechverzögerung von etwa 1,5s hat, ist es sinnvoll diesen Wert auf 2 zu stellen.

### Algorithmus
Aktuell gibt es drei verschiedene Algorithmen, die den besten Punkt berechnen:
- Beste Teilsequenz
- Gewichtete Vektoren
- Gewichtete Vektoren mit Bias

Details zu deren Funktionsweisen und Anwendungsfällen sind [hier](doc/algorithms-de.md) aufgeführt.\
\
<img src="https://user-images.githubusercontent.com/57962936/115938774-0a530b00-a49c-11eb-8f15-e7ce81d31ad9.png" width=320/>
<img src="https://user-images.githubusercontent.com/57962936/115938776-0aeba180-a49c-11eb-8280-065e14868b05.png" width=320/>\
Beispiel: 'Gewichtete Vektoren' vs 'Beste Teilsequenz'

#### Switch
Mit diesem Schalter kann der Auswertungsalgorithmus geändert werden. Wenn kein Schalter zugewiesen ist, kann die Auswahl manuell getroffen werden.

#### Minimale Sequenzlänge
Der optimale Punkt wird nicht berechnet, sofern die Anzahl an Messpunkten geringer als dieser Parameter ist.

#### Maximale Sequenzlänge
Dieser Wert wird genutzt, um einen übermäßig langen Flugweg zu vermeiden, falls der Weg keinen ganzen Kreis beinhaltet.

#### Länge optimale Teilsequenz
Um den besten Punkt auf dem Flugweg zu finden, berechnet der Beste-Teilsequenz-Algorithmus die Summe über alle Teilsequenzen dieser Länge.\
Der optimale Punkt entspricht dann dem mittleren Punkt dieser optimalen Teilsequenz.

#### Erwartetes Steigen
Wenn dies ausgewählt ist, versucht die App das erwartete Steigen am optimalen Punkt zu bestimmen. Dieser Wert wird dann mit der Sprachausgabe angesagt und beeinflusst zudem die Größe des optimalen Punktes in der Darstellung.\
Das erwartete Steigen wird als ein gewichteter Durchschnitt berechnet, wobei das Gewicht eines Punktes das inverse Quadrat der Entfernung zum optimalen Punkt ist.

### Telemetriefenster
#### Zoom
Mit dem Zoom-Geber kann der Zoom auf der "Karte" von Punkten kontrolliert werden.\
Wenn kein Geber ausgewählt ist oder sich der Geber in (-1)-Position befindet, wird der automatische Zoom aktiviert.\
Dieser entspricht immer der höchsten Zoomstufe, bei der alle Punkte auf dem Bildschirm sind.


#### Kreisradius
Radius der Kreise im Telemetriefenster in Pixel je m/s Steigen.

#### Zoombereich
Bereich der Zoomstufen, die mit dem Zoom-Geber erreichbar sind.

## Screenshots
![thlassist1](https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist1.png)
![thlassist1.1](https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist1-1.png)
![thlassist2](https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist2.png)
![thlassist3](https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist3.png)
![thlassist4](https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist4.png)
