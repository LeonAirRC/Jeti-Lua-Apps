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

#### Suchmodus umschalten
Dieser Schalter schaltet den Suchmodus ein. In diesem Modus wird der Flugweg nicht mehr auf einen Kreis begrenzt und die Sprachansage nutzt anstelle des Mittelpunkts nun die aktuelle Position als Bezugspunkt.
Standardmäßig wird Algorithmus 1 genutzt.

### Sensoren
#### Messintervall
Der zeitliche Abstand zwischen zwei Messungen [ms].

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
<img src="https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist6.png" width=320/>
<img src="https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist7.png" width=320/>\
Beispiel: 'Gewichtete Vektoren' vs 'Beste Teilsequenz'

#### Switch
Mit diesem Schalter kann der Auswertungsalgorithmus geändert werden. Wenn kein Schalter zugewiesen ist, ist Algorithmus 2 standardmäßig aktiviert.

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

### Sprachausgabe
#### Ansageintervall
Der zeitliche Abstand zwischen zwei Sprachansagen [s].

#### Höhe ausgeben
Wenn dies ausgewählt ist und eine Höhensensor ausgewählt ist, wird am Ende jeder Sprachausgabe die aktuelle Höhe mit angesagt. 

### Telemetriefenster
#### Kreisradius
Radius der Kreise im Telemetriefenster in Pixel je m/s Steigen.

## Screenshots
<p>
<img src="https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist1.png" />
<img src="https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist2.png" />
<img src="https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist3.png" />
<img src="https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist4.png" />
<img src="https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist5.png" />
</p>
