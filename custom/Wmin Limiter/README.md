<h1>Wmin Limiter</h1>

### [Installation](https://github.com/LeonAirRC/Jeti-Lua-Apps/tree/main/custom#installation)
<p>
Diese App begrenzt das Gas, wenn der Antrieb eine bestimmte Energie verbraucht hat oder eine bestimmte Motorlaufzeit erreicht wurde.<br/>
Die Energie in Wmin wird mit der Telemetrie eines Spannungs- und eines Stromsensors berechnet.
<ul>
<li><b>Switch:</b> Beim Bewegen in die Ein-Position werden die Werte zurückgesetzt und die App erhält die Kontrolle über den Gaskanal. In der Aus-Position wird die App gestoppt und der Pilot hat uneingeschränkte Kontrolle über den Gaskanal.</li>
<li><b>Limit/Energie:</b> Die maximal nutzbare Energie, bevor das Gas abgeschaltet wird</li>
<li><b>Limit/Zeit:</b> Die maximale Motorlaufzeit</li>
<li><b>Alarmsound:</b> Sound, der bei Erreichen des Limits und dem damit einhergehenden Drosseln des Gaskanals abgespielt wird</li>
<li><b>Motorlaufzeit Trigger:</b> Geber, welcher im Normalbetrieb das Gas steuert. Der Motor wird dann als <i>an</i> interpretiert, wenn dieser Wert >-100% ist.</li>
<li><b>Gas-Output:</b> Auswahl des Lua-Gebers, auf welchem das Gassignal ausgegeben wird</li>
</ul>
<p>
Für die sichere Nutzung ist ein Setup mit Logischen Schaltern notwendig, um der App in Notsituationen die Kontrolle über den Gaskanal entziehen zu können. Seien <b>C1</b> der gewählte Gas-Output und <b>P4</b> der eigentliche Gas-Geber:</p>

    L1 = <b>App-Switch</b> AND <b>C1</b><br>
    L2 = <b>P4 linear</b> AND <b>L1 reverse</b>

<p>
<b>L2</b> sollte dann als Geber des Gaskanals zugewiesen werden. Somit hat die Ausgabe der App auf <b>C1</b> keinen Effekt, solange der Schalter in Aus-Position ist.
</p>
