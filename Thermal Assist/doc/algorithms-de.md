# Algorithmen
## Beste Teilsequenz
Dieser Algorithmus sucht nach der Teilsequenz mit der Länge 'Länge optimale Teilsequenz' und der höchsten Summe über die enthaltenen Steigwerte.\
In folgendem Szenario, wobei die Zahlen das Steigen an den jeweiligen Stellen angeben,\
\
<img src="https://user-images.githubusercontent.com/57962936/115403853-14031700-a1ed-11eb-989a-be5743f78519.png" width=300>\
\
wird die folgende Teilsequenz gewählt:\
\
<img src="https://user-images.githubusercontent.com/57962936/115404091-490f6980-a1ed-11eb-8517-bec7fd6b43a1.png" width=400>\
\
Die Ansage ist in diesem Fall "56 Grad, 21 Meter, 2 Meter pro Sekunde".

## Gewichtete Vektoren
Berechnet den gewichteten Durchschnitt über alle Vektoren, die vom Kreismittelpunkt zu den GPS-Punkten zeigen:\
\
<img src="https://user-images.githubusercontent.com/57962936/115405333-71e42e80-a1ee-11eb-8937-439e753f6a5b.png" width=300>\
\
Dann wird jeder Vektor mit seinem Gewicht (Steigrate / absolute Summe über alle Steigraten). Daraus resultiert dieser optimale Punkt:\
\
<img src="https://user-images.githubusercontent.com/57962936/115410878-4d3e8580-a1f3-11eb-812f-87bdbb663b0b.png" width=400>

## Bias
Dieser Algorithmus addiert lediglich einen Wert auf alle Steigwerte. Dieser Wert ist die geringste Steigrate, aber niemals größer als null:\
\
<img src="https://user-images.githubusercontent.com/57962936/115411702-fdac8980-a1f3-11eb-8d7d-fe058b2f7a55.png" width=400>\
\
Daraus resultiert dieser optimale Punkt:\
\
<img src="https://user-images.githubusercontent.com/57962936/115411827-1c128500-a1f4-11eb-818d-bd7b54fc2b09.png" width=400>\
\
In diesem einfachen Szenario ist der Vektor zum optimalen Punkt etwas kürzer, aber kaum verschieden zu dem Punkt ohne Bias. Trotzdem macht das Bias den Punkt hier offensichtlich schlechter.\
Umstände, unter denen dieser Algorithmus trotzdem geeignet ist, sind weiter unten aufgelistet.\
Als ein Seiteneffekt dieser Berechnungsmethode sind die empfohlenen Verlagerungen häufig weniger aggressiv.

# Anwendungsfälle
<p>
  <img src="https://user-images.githubusercontent.com/57962936/115416629-39e1e900-a1f8-11eb-9630-140859666782.png" width=300>
  <img src="https://user-images.githubusercontent.com/57962936/115416998-8a594680-a1f8-11eb-851a-9b29b73c071a.png" width=300>
</p>
&#8195;Abb. 1&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;Abb. 2

### Beste Teilsequenz
Dieser Algorithmus ist ideal für frühe Flüge mit punktueller und unkonstanter Thermik (Abb. 1), da er den Piloten immer an den Rand des geflogenen Kreises lenkt.\
Sobald jedoch die Thermik großflächiger wird, wird die App immer noch empfehlen, den Kreis zu verlagern.\
In Abb. 1 z.B. wäre der beste Punkt die "2", was offensichtlich die beste Option ist. In Abb. 2 würde jedoch der Punkt "3" gewählt werden, was deutlich näher an sinkender Luft ist als z.B. die Mitte der rechten Kreishälfte.

### Gewichtete Vektoren
Größflächigere Thermik ist die Stärke dieses Algorithmus. Da der berechnete Punkt ein Durchschnitt ist, ist es vorteilhaft, wenn es klar getrennte Bereiche mit besserem und schlechterem Steigen gibt.
Außerdem wird die App - wenn überhaupt - nur noch sehr geringe Verlagerungen ausgeben, wenn ein guter Kreispunkt gefunden wurde.\
In Abb. 1 wäre der berechnete Punt sehr nah am Mittelpunkt. Dafür würde in Abb. 2 eine Verlagerung nach Osten empfohlen, was offensichtlich die richtie Option ist.

### Bias
Mit Bias wird selbst Sinken als "positiv" interpretiert, sofern es weniger als am schlechtesten Punkt ist.
Daher ist diese Methode sinnvoll, wenn keine Thermik mehr auffindbar ist und man trotzdem versucht so lange wie möglich in der Luft zu bleiben.


# Mathematik
![Screenshot_2021-04-20 StackEdit(2)](https://user-images.githubusercontent.com/57962936/115458458-061db800-a226-11eb-9292-44ab3dee70d3.png)
