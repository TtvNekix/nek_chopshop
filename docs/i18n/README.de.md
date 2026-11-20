# Nekix ChopShop

Schrottplatz-Job für FiveM: ein Fahrzeug stehlen, zum Schrottplatz fahren, ausschlachten und die Teile verkaufen. Läuft auf ESX, QBCore und Qbox. Jede Entscheidung (Job, Fahrzeug, Teile, Beute, Bezahlung, XP) trifft der Server.

**Dokumentation in anderen Sprachen:** [English](../../README.md) | [Español](README.es.md) | [Português (Brasil)](README.pt-br.md) | [Français](README.fr.md) | Deutsch

## Funktionen

- **Frameworks:** ESX, QBCore und Qbox, automatisch erkannt (`Config.Framework = 'auto'`).
- **Inventare:** ox_inventory, qs-inventory, core_inventory, ps-inventory und qb-inventory, automatisch erkannt, dazu ein `custom`-Adapter für jedes andere Inventar.
- **Server-autoritative Jobs:** Der Server wählt das Fahrzeug, spawnt es, prüft Entfernungen, Zeiten und Lockpick und entscheidet über jede Belohnung. Ein manipulierter Client kann sich keine Items, kein Geld und keine XP geben.
- **Fahrzeugklassen und Beute:** Fahrzeuge der niedrigen, mittleren und hohen Klasse mit eigener Auszahlung, Item-Qualität und Beutetabelle.
- **Ruf:** XP und Level pro Charakter (oxmysql), die Fahrzeugklassen und Boni freischalten.
- **Mehr Teile:** Türen, Motorhaube, Kofferraum, Motor, Vordersitze und Räder, mit einer vom Server erzwungenen Reihenfolge "dies zuerst entfernen".
- **Polizei:** Mindestanzahl Beamter im Dienst und Dispatch-Meldung mit 9 unterstützten Skripten plus `custom`.
- **Fahrzeugschlüssel:** Der Job-Besitzer erhält nach dem Lockpick die Schlüssel des Job-Fahrzeugs, mit 7 unterstützten Skripten plus `custom`.
- **Partnersystem:** Der Besitzer kann vor dem Ausschlachten einen Partner einladen; der Partner teilt sich die Arbeit und einen Anteil der XP.
- **Zeitlimits:** Timer für Abholung und Ausschlachten; ein abgelaufener Job wird abgebrochen und sein Stellplatz freigegeben.
- **Dauerhafter Cooldown:** im KVP der Ressource gespeichert (ohne SQL), pro Charakter und pro Lizenz, mit einem Reset-Befehl für Admins.
- **Arbeitsauftrag-NUI:** Jobtafel, Jobzettel mit Notizen, lose Notizen, Partner-Einladung und Teile-Ankäufer. Kann abgeschaltet werden.
- **10 Sprachen** über die Locales von ox_lib: en, es, fr, de, it, pt-br, pl, nl, tr, cs.
- **Discord-Logs** und Versionsprüfung.

## Voraussetzungen

| Ressource | Hinweise |
| :--- | :--- |
| [ox_lib](https://github.com/overextended/ox_lib) | erforderlich |
| [ox_target](https://github.com/overextended/ox_target) | erforderlich |
| [oxmysql](https://github.com/overextended/oxmysql) | erforderlich (Manifest-Abhängigkeit). Mit `Config.Reputation.Enabled = false` wird kein SQL ausgeführt |
| OneSync | erforderlich (der Server spawnt die Fahrzeuge) |
| `qbx_core`, `es_extended` oder `qb-core` | eines davon |
| Ein Inventar | `ox_inventory`, `qs-inventory`, `core_inventory`, `ps-inventory`, `qb-inventory` oder ein Custom-Adapter |

Optional: ein Fahrzeugschlüssel-Skript und ein Polizei-Dispatch-Skript (siehe "Fahrzeugschlüssel" und "Polizei & Dispatch").

## Installation

1. **Lade** die Ressource herunter und lege den Ordner in dein Ressourcenverzeichnis. Behalte den Ordnernamen `nek_chopshop`: Die Exports verwenden ihn (`exports.nek_chopshop`).
2. **Füge die Items** zu deinem Inventar hinzu. Öffne die Anleitung für dein Inventar, kopiere den Block und starte das Inventar neu:

   | Inventar | Anleitung |
   | :--- | :--- |
   | ox_inventory | [docs/items/ox_inventory.md](../items/ox_inventory.md) |
   | qb-inventory | [docs/items/qb-inventory.md](../items/qb-inventory.md) |
   | ps-inventory | [docs/items/ps-inventory.md](../items/ps-inventory.md) |
   | qs-inventory | [docs/items/qs-inventory.md](../items/qs-inventory.md) |
   | core_inventory | [docs/items/core_inventory.md](../items/core_inventory.md) |
   | jedes andere | [docs/items/custom.md](../items/custom.md) |

3. **Kopiere die Item-Bilder** aus dem Ordner `[assets]` in das Bilderverzeichnis deines Inventars (`ox_inventory/web/images/`, `qb-inventory/html/images/`, ...; jede Anleitung nennt den Ordner). Jedes Bild ist nach seinem Item benannt.
4. **Trage die Ressource in `server.cfg` ein**, nach ihren Abhängigkeiten:

   ```cfg
   ensure ox_lib
   ensure ox_target
   ensure oxmysql
   ensure qbx_core            # oder es_extended / qb-core
   ensure ox_inventory        # oder dein Inventar
   ensure qbx_vehiclekeys     # optional: dein Schlüssel-Skript
   ensure ps-dispatch         # optional: dein Dispatch-Skript
   ensure nek_chopshop
   ```

5. **Datenbank:** Es muss nichts importiert werden. Die Tabelle `nek_chopshop_reputation` wird beim ersten Start angelegt.
6. **Konfiguration:** Lass `Config.Framework = 'auto'` und `Config.Inventory = 'auto'`, sofern du nicht eines erzwingen musst. Sieh dir [`shared/config.lua`](../../shared/config.lua) an.
7. **Sprache (optional):** Füge `setr ox:locale "de"` zu `server.cfg` hinzu (siehe "Sprachen").
8. **Starte den Server** und prüfe die Konsole: Sie gibt das gefundene Framework und Inventar aus und warnt vor jedem nicht registrierten Item.

## Ablauf eines Jobs

1. Der Spieler fragt beim Ped nach einem Job (Target-Option oder Jobtafel). Der Server prüft Cooldown, Polizisten im Dienst, Fahrzeugklasse laut Ruf und einen freien Stellplatz auf dem Schrottplatz, spawnt dann das Fahrzeug und markiert es auf der Karte.
2. Der Spieler knackt das Fahrzeug per Lockpick (benötigt eines der `Config.LockpickItems` und das bestandene Minispiel). Der Server gibt die Schlüssel und sendet die Polizeimeldung.
3. Der Spieler fährt es zum Schrottplatz.
4. Auf dem Schrottplatz kann der Spieler einen Partner einladen und beginnt dann mit dem Ausschlachten.
5. Jedes entfernte Teil landet im Inventar. Sind alle Teile entfernt, erhält der Besitzer `Config.FinishReward` und, falls aktiviert, Geld. Das Fahrzeug wird zerstört.
6. Der Spieler verkauft die Teile beim Verkaufs-Ped.

## Konfigurationsübersicht

Alle Optionen stehen in [`shared/config.lua`](../../shared/config.lua), jede mit einem Kommentar. Nach Bereichen gruppiert:

### Allgemein

| Option | Beschreibung |
| :--- | :--- |
| `Config.Framework` | `'auto'` (Standard), `'esx'`, `'qbcore'` oder `'qbox'`. Reihenfolge bei auto: `qbx_core` > `es_extended` > `qb-core`. Ein erzwungenes Framework, das nicht gestartet ist, fällt auf die automatische Erkennung zurück. |
| `Config.Inventory` | `'auto'` (Standard), `'ox_inventory'`, `'qs-inventory'`, `'core_inventory'`, `'ps-inventory'`, `'qb-inventory'` oder `'custom'`. Siehe "Inventar". |
| `Config.LockpickItems` | Items, mit denen das Job-Fahrzeug geknackt werden kann (eines genügt). Standard `lockpick`, `advancedlockpick`, `advanced_lockpick`. |
| `Config.UseNUI` | `true` nutzt die NUI; `false` fällt auf die Menüs und Benachrichtigungen von ox_lib zurück. |
| `Config.Debug` | Debug-Ausgaben. |
| `Config.AdminAce` | ACE, der den Admin-Befehl benutzen darf. Siehe "Administration". |

### Jobs, Belohnungen und Zeit

| Option | Beschreibung |
| :--- | :--- |
| `Config.Cooldown` | Sekunden zwischen Jobs (Standard 3600). Ruf-Boni können ihn verkürzen. |
| `Config.TimeLimit` | `Pickup` und `Scrap`, in Minuten (Standard 20 und 10). Pickup läuft von der Jobannahme bis zum Beginn des Ausschlachtens; Scrap vom Beginn bis alle Teile entfernt sind. Ein Job, der eines davon überschreitet, wird abgebrochen. |
| `Config.Payment` | `Enable`, `Min`, `Max`: optionales Geld pro Job (standardmäßig deaktiviert). Wird mit dem `payout` der Klasse multipliziert. |
| `Config.FinishReward` | Item, das der Besitzer erhält, wenn alle Teile entfernt sind (Standard `veh_suspension`), oder `false`. |
| `Config.ChopParts` | Teile, die entfernt werden können. Das ist die Belohnungs-Whitelist: Der Server belohnt nur hier aufgeführte Teile. Siehe "Teile". |
| `Config.Coords` | `Spawns` (Fahrzeug-Spawnpunkte) und `Scrap` (Stellplätze auf dem Schrottplatz). |
| `Config.Tiers` | Fahrzeugklassen. Siehe "Fahrzeugklassen & Beute". |
| `Config.Reputation` | XP, Level, Boni, Verfall. Siehe "Ruf". |

### Peds und Verkauf

| Option | Beschreibung |
| :--- | :--- |
| `Config.Ped` | Job-Ped: `Model`, `Coords`, `Scenario`, `Target` (ox_target-Optionen), `Blip`. |
| `Config.SellPed` | Verkaufs-Ped: `Enable`, `Model`, `Coords`, `Scenario`, `Items` (Item, Grundpreis, Bezeichnung), `QualityMultiplier`, `Blip`. |

Bezeichnungen (`label`, `Label` des Blips, `label` des Targets) akzeptieren einen Locale-Schlüssel; ein Klartext funktioniert ebenfalls.

### Polizei und Fahrzeugschlüssel

| Option | Beschreibung |
| :--- | :--- |
| `Config.Police` | `MinOnDuty`, `JobType`, `Jobs`, `Dispatch`. Siehe "Polizei & Dispatch". |
| `Config.VehicleKeys` | `System`, `RemoveOnEnd`. Siehe "Fahrzeugschlüssel". |

### Sicherheit (Anti-Exploit)

`Config.Security` enthält die serverseitigen Schwellenwerte (Entfernungen in Metern, Zeiten in Millisekunden):

| Option | Standard | Beschreibung |
| :--- | :--- | :--- |
| `PedDistance` | 10.0 | Maximale Entfernung zum Job-Ped, um einen Job anzufragen. |
| `SellDistance` | 10.0 | Maximale Entfernung zum Verkaufs-Ped zum Verkaufen. |
| `ScrapDistance` | 15.0 | Maximale Entfernung des Fahrzeugs zum Schrottpunkt, um mit dem Ausschlachten zu beginnen. |
| `PartDistance` | 6.0 | Maximale Entfernung des Spielers zum Fahrzeug, um ein Teil zu entfernen. |
| `PartnerDistance` | 20.0 | Maximale Entfernung zwischen Besitzer und Partner bei der Zuweisung. |
| `PartInterval` | 2000 | Mindestzeit zwischen zwei Teileentfernungen desselben Spielers. |
| `SpawnClearRadius` | 3.0 | Ein Spawnpunkt wird übersprungen, wenn sich ein Fahrzeug in diesem Radius befindet. |
| `MaxAverageSpeed` | 60.0 | m/s. Eine Lieferung vom Spawn zum Schrottplatz, die schneller ist, gilt als Teleport und wird abgelehnt. |
| `WarnThrottle` | 30 | Sekunden zwischen Logs verdächtiger Anfragen desselben Spielers. |
| `DispatchDistance` | 10.0 | Maximale Entfernung zum Job-Fahrzeug, wenn die Lockpick-Meldung eintrifft. |

### Logs

| Option | Beschreibung |
| :--- | :--- |
| `Config.Discord` | `Username`, `AvatarUrl`, `Color` der Embeds. Die Webhook-URL steht **nicht** hier: Setze `Editable.Webhook` in `editable/server.lua`. |
| `Config.Logs` | `EnableItem`, `EnablePay`, `EnableFinish`, `EnableWarn`, `EnableReputation`, `Compact`. |

Discord-Logs verwenden die Sprache des Servers.

## Inventar

`Config.Inventory = 'auto'` verwendet das erste gestartete Inventar dieser Liste:

| # | Ressource | Frameworks | Hinweise |
| :--- | :--- | :--- | :--- |
| 1 | `ox_inventory` | ESX, QBCore, Qbox | Volle Unterstützung. |
| 2 | `qs-inventory` | ESX, QBCore, Qbox | Nach der Herstellerdokumentation geschrieben. |
| 3 | `core_inventory` | ESX, QBCore, Qbox | Nach der Herstellerdokumentation geschrieben; Verkauf nach Qualität ist eingeschränkt. |
| 4 | `ps-inventory` | QBCore | Die Platzprüfung ist eine Schätzung; Verkauf nach Qualität ist eingeschränkt. |
| 5 | `qb-inventory` | QBCore | Verkauf nach Qualität ist eingeschränkt. |

- **Später Start:** Läuft beim Start der Ressource kein Inventar, wartet sie und wählt eines, sobald eine Ressource der Liste startet. Starte dein Inventar trotzdem vor nek_chopshop.
- **Eines erzwingen:** Gib den Ressourcennamen an. Ist es nicht gestartet, wird eine Warnung in der Konsole ausgegeben und die automatische Erkennung verwendet.
- **Jedes andere Inventar:** `Config.Inventory = 'custom'` und `Editable.Inventory` in `editable/server.lua` ausfüllen. Siehe [docs/items/custom.md](../items/custom.md).
- **Qualitäts-Metadaten:** ox_inventory speichert die Klassenqualität in `metadata.quality`; die anderen Inventare verwenden `chopQuality`.
- Bekannte Einschränkungen jedes Inventars stehen am Ende seiner Item-Anleitung.

## Polizei & Dispatch

### Mindestanzahl Polizisten im Dienst

`Config.Police.MinOnDuty` ist die Anzahl Beamter, die im Dienst sein müssen, um einen Job zu vergeben (`0` deaktiviert es). Die Anfrage wird serverseitig abgelehnt und die Tafel zeigt "Not enough police on duty" (Text je nach Sprache).

- **Qbox / QBCore:** zählt Spieler im Dienst, deren Jobtyp `Config.Police.JobType` ist (Standard `'leo'`). Mit `JobType = false` werden stattdessen die Jobnamen in `Config.Police.Jobs` gezählt.
- **ESX:** zählt Spieler mit einem Job aus `Config.Police.Jobs`, deren `job.onDuty` nicht `false` ist (ein älteres ESX ohne Dienststatus zählt alle im Job).
- Eine Klasse kann `minPolice` hinzufügen; die tatsächliche Anforderung ist der höhere der beiden Werte.

### Meldung

Eine Meldung pro Job, vom Server gesendet (aus seinem Job-Durchlauf oder bei der Lieferung des Fahrzeugs), damit ein manipulierter Client sie nicht überspringen kann. Der Client des Diebs kann sie früher auslösen, direkt nach dem Lockpick; der Server prüft, ob der Aufrufer der Job-Besitzer ist, sich in der Abholphase befindet, neben dem Fahrzeug steht (`Config.Security.DispatchDistance`) und noch keine Meldung abgesetzt hat. Position, Kennzeichen und Modell kommen immer vom Server.

`Config.Police.Dispatch.System`:

| Wert | Verhalten |
| :--- | :--- |
| `'auto'` | Erstes gestartetes Skript der folgenden Liste. |
| ein Skriptname | Erzwingt dieses Skript. |
| `'custom'` | Ruft deinen eigenen Code auf (siehe unten). |
| `false` | Keine Meldung. |

Unterstützte Skripte, in der Reihenfolge der automatischen Erkennung:

| # | Ressource | Läuft auf |
| :--- | :--- | :--- |
| 1 | `ps-dispatch` | Client |
| 2 | `cd_dispatch` | Client |
| 3 | `qs-dispatch` | Client |
| 4 | `rcore_dispatch` | Client |
| 5 | `core_dispatch` | Server |
| 6 | `tk_dispatch` | Client |
| 7 | `origen_police` | Client |
| 8 | `lb-tablet` | Server |
| 9 | `linden_outlawalert` | Client |

Weitere Optionen von `Config.Police.Dispatch`: `Code` (Funkcode, Standard `10-35`), `CodeName` (nur ps-dispatch), `Title` und `Message` (Locale-Schlüssel `dispatch_title` / `dispatch_message`; die Nachricht erhält Modell und Kennzeichen) und `Blip` (`Sprite`, `Color`, `Scale`, `Time` in Sekunden).

**Custom:** Setze `System = 'custom'` und fülle `Editable.Client.DispatchAlert(data)` (`editable/client.lua`) und/oder `Editable.Server.DispatchAlert(data, source)` (`editable/server.lua`) aus. `data` ist `{ coords, plate, model, code, title, message, jobs, jobType }`; die Client-Version erhält zusätzlich `modelLabel` und `vehicle` (Entity).

## Fahrzeugschlüssel

Schlüssel-Skripte (zum Beispiel `qbx_vehiclekeys`) lassen einen Spieler kein Fahrzeug starten, für das er keine Schlüssel hat. Nach einem erfolgreichen Lockpick gibt der Server dem Besitzer die Schlüssel des Job-Fahrzeugs, einmal pro Job und nur, wenn er ein Lockpick-Item bei sich hat. Partner erhalten nie Schlüssel.

`Config.VehicleKeys`:

| Option | Verhalten |
| :--- | :--- |
| `System = 'auto'` | Erstes gestartetes Skript der folgenden Liste. |
| `System = '<resource>'` | Erzwingt dieses Skript (keine Schlüssel, wenn es nicht gestartet ist). |
| `System = 'custom'` | Ruft `Editable.Server.GiveVehicleKeys(src, vehicle, plate, model)` und `Editable.Server.RemoveVehicleKeys(...)` in `editable/server.lua` auf. |
| `System = false` | Es werden keine Schlüssel vergeben (zum Beispiel ESX ohne Schlüssel-Skript). |
| `RemoveOnEnd = true` | Nimmt die Schlüssel zurück, wenn der Job endet, bevor das Fahrzeug gelöscht wird. |

Unterstützte Skripte, in der Reihenfolge der automatischen Erkennung: `qbx_vehiclekeys`, `qs-vehiclekeys`, `wasabi_carlock`, `MrNewbVehicleKeys`, `ak47_vehiclekeys`, `vehicles_keys`, `qb-vehiclekeys`.

Nicht eingebaut (nutze `'custom'`): Renewed-Vehiclekeys, cd_garage-Schlüssel, t1ger_keys, okokGarage / okokVehicleKeys.

## Fahrzeugklassen & Beute

Der Server wählt das Fahrzeug. `Config.Tiers` gruppiert die Modelle in Klassen (standardmäßig `low`, `mid`, `high`):

| Feld | Beschreibung |
| :--- | :--- |
| `label` | Locale-Schlüssel (oder Text), der beim Jobstart angezeigt wird. |
| `weight` | Relative Wahrscheinlichkeit der Klasse unter den Klassen, für die der Spieler qualifiziert ist. |
| `minLevel` | Benötigtes Ruf-Level. Wird ignoriert, wenn der Ruf deaktiviert ist. |
| `minPolice` | Optional. Für diese Klasse benötigte Beamte im Dienst. |
| `payout` | Multiplikator für die Endauszahlung (`Config.Payment`). |
| `quality` | Qualität, die die Teile-Items dieser Klasse erhalten: `standard`, `premium` oder `exotic`. Items unterschiedlicher Qualität lassen sich nicht stapeln. |
| `models` | Fahrzeugmodellnamen; eines wird zufällig gewählt. |
| `loot` | Zusätzliche Würfe für jedes entfernte Teil: `{ item, chance (0-100), min, max, parts = { bones }, quality = true }`. |

- Klasse, Modell und Beute werden auf dem Server ausgewürfelt.
- Bevor ein Teil entfernt wird, prüft der Server, ob das Teil, seine Bonus-Items und die gesamte Beute gleichzeitig ins Inventar passen. Wenn nicht, wird nichts vergeben und das Teil bleibt am Auto.
- **Verkauf:** Das Verkaufs-Ped zahlt `price x QualityMultiplier[quality] x sellMultiplier des Rufs` pro Stapel. Standardwerte von `Config.SellPed.QualityMultiplier`: standard 1.0, premium 1.5, exotic 2.5.
- Nur als Beute erhältliche Items (`scrap_metal`, `sport_wheel`, `turbo_kit`) müssen in deinem Inventar registriert und in `Config.SellPed.Items` aufgeführt sein, damit sie verkauft werden können.
- Eine Konfiguration, die noch die alte flache Liste `Config.Vehicles` und kein `Config.Tiers` enthält, funktioniert weiter als einzelne Klasse `low`.

## Ruf

Pro Charakter in der oxmysql-Tabelle `nek_chopshop_reputation` gespeichert (`identifier`, `xp`, `jobs`, `last_job`), automatisch angelegt. `identifier` ist die Charakter-ID des Frameworks (`identifier` bei ESX, `citizenid` bei QBCore/Qbox).

- **XP verdienen (nur Server):** Ein abgeschlossener Job gibt dem Besitzer `Base + PerPart x entfernte Teile + TimeBonusMax x (verbleibender Anteil der Ausschlachtzeit)`. Der Partner erhält davon `PartnerShare` (0-1). Ein Job, der die Zeit überschreitet oder dessen Fahrzeug verloren geht, kostet den Besitzer `PenaltyExpired`; den Server mit aktivem Job zu verlassen kostet `PenaltyAbandoned`. XP fallen nie unter 0.
- **Level** (`Config.Reputation.Levels`): Der erste Eintrag ist Level 0 (`xp = 0`). Jedes Level führt seine eigenen Boni auf:

| Bonus | Wirkung |
| :--- | :--- |
| `sellMultiplier` | Multipliziert den Preis des Verkaufs-Peds (zusätzlich zum Qualitätsmultiplikator). |
| `cooldownMultiplier` | Multipliziert `Config.Cooldown`, wenn ein Job angenommen wird (0-1). |
| `extraPartChance` | Wahrscheinlichkeit (0-100) auf eine zusätzliche Kopie jedes entfernten Teils. |
| Fahrzeugklassen | Freigeschaltet über `Config.Tiers[].minLevel` (Standard: mittlere ab Level 2, hohe ab Level 4). |

- **Verfall** (`Config.Reputation.Decay`, standardmäßig aus): Jede volle Woche ohne abgeschlossenen Job entfernt `PerWeek` XP. Wird beim Lesen des Rufs berechnet; es gibt keinen Timer.
- **Deaktiviert** (`Enabled = false`): keine XP, keine Boni, alle Klassen verfügbar, kein SQL.
- Die Tafel zeigt Level und Fortschritt; ein Level-Aufstieg sendet eine Benachrichtigung und, mit `Config.Logs.EnableReputation`, ein Discord-Log.

## Teile

Einträge von `Config.ChopParts`: `bone`, `part` (Tür- oder Radindex), `item`, `label` (Locale-Schlüssel), `isDoor` / `isWheel`, `bonus` (zusätzliche Items), `anim` (`'repair'` für die Animation unter der Haube), `optional` und `requires`.

- Standardteile: 4 Türen, Motorhaube (gibt `car-battery`), Kofferraum, Motor (erfordert entfernte Haube), 2 Vordersitze (erfordern ihre entfernte Tür) und 4 Räder.
- Nur die 4 Räder sind Pflicht. Alle anderen Teile sind optional: Sie gehören nur dann zum Job, wenn das Fahrzeugmodell diesen Bone hat, sodass ein Modell ohne einen Bone den Job nie unabschließbar macht.
- `requires` wird auf dem Server erzwungen. Gehört das geforderte Teil nicht zum Job, gilt die Anforderung als erfüllt.

## Sprachen

Alle für Spieler sichtbaren Texte stehen in `locales/<lang>.json` und werden mit dem Locale-Modul von ox_lib geladen.

Enthalten: Englisch (`en`), Spanisch (`es`), Französisch (`fr`), Deutsch (`de`), Italienisch (`it`), brasilianisches Portugiesisch (`pt-br`), Polnisch (`pl`), Niederländisch (`nl`), Türkisch (`tr`) und Tschechisch (`cs`).

- **Sprache wechseln:** Füge `setr ox:locale "de"` zu `server.cfg` hinzu (Standard `en`). Spieler können die Sprache auch im Einstellungsmenü von ox_lib wählen; die NUI aktualisiert sich dabei.
- **Rückfall:** Ein fehlender Schlüssel fällt auf Englisch zurück; eine fehlende Datei fällt auf Englisch zurück.
- **Sprache hinzufügen:** Kopiere `locales/en.json` nach `locales/<code>.json` (derselbe Code wie in `ox_lib/locales`, z. B. `ru`, `zh-cn`), übersetze die Werte und behalte die Schlüssel bei. Behalte `%s` / `%d` in derselben Reihenfolge und die `{placeholders}` im Abschnitt `nui` unverändert. Verwende kein `${...}` in Texten.
- Bearbeite `ChopLocale` / `LoadChopLocale` in der Konfiguration nicht.

## Administration

| Befehl | Beschreibung |
| :--- | :--- |
| `chopshop_resetcd all` | Löscht den Job-Cooldown aller Charaktere und Lizenzen. |
| `chopshop_resetcd <player id>` | Löscht den Cooldown eines verbundenen Spielers (aktueller Charakter und Lizenz). |
| `chopshopui` | Spielerbefehl: schließt alle NUI-Ansichten und gibt den Maus-Fokus frei, falls ein Seitenfehler ihn blockiert. |

Cooldowns liegen im KVP-Speicher dieser Ressource (der Ordner `db/` des Servers), nicht in MySQL.

`Config.AdminAce` (Standard `'admin'`):

- Spieler mit diesem ACE können `chopshop_resetcd` im Spiel ausführen (der ACE `command.chopshop_resetcd` funktioniert ebenfalls). Die Serverkonsole kann ihn immer ausführen.
- Spieler mit diesem ACE überspringen die Anti-Teleport-Prüfung bei der Lieferung, sodass das Team mit Teleports testen kann.

```cfg
add_ace group.admin admin allow
```

## Exports

Verwende den Ordnernamen der Ressource in `exports[...]`.

### Client

```lua
-- Gibt { active = boolean, pedCoords = vector4 } zurück
-- active: Der lokale Spieler hat einen aktiven Chop-Job. pedCoords: Config.Ped.Coords.
local status = exports.nek_chopshop:GetJobStatus()
if status.active then
    print('Working on a chop job')
end
```

### Server

```lua
-- GetReputation(identifier: string) -> { xp = number, level = number, jobs = number } | nil
-- nil, wenn der Ruf deaktiviert ist, der Identifier ungültig ist oder die Datenbank nicht gelesen werden konnte.
-- Kann beim ersten Lesen eines Identifiers auf die Datenbank warten: aus einem Thread aufrufen.
CreateThread(function()
    local rep = exports.nek_chopshop:GetReputation(citizenid)
    if rep then print(rep.xp, rep.level, rep.jobs) end
end)

-- AddReputation(identifier: string, amount: number, reason?: string) -> boolean
-- amount: ungleich null; positiv addiert, negativ entfernt (Bruchteile werden abgeschnitten, maximal 1000000).
-- reason: Text für das Log (auf 100 Zeichen gekürzt, Standard 'export').
-- Asynchron gespeichert, in der Konsole ausgegeben und auf Discord protokolliert (Config.Logs.EnableReputation).
-- Gibt false zurück bei ungültigem Identifier oder Betrag, bei deaktiviertem Ruf oder wenn die
-- Zeile nicht gelesen werden konnte (die Änderung wird dann eingereiht und beim nächsten erfolgreichen Lesen einmal angewendet).
-- Kann beim ersten Verwenden eines Identifiers auf die Datenbank warten: aus einem Thread aufrufen.
CreateThread(function()
    exports.nek_chopshop:AddReputation(citizenid, 50, 'event reward')
    exports.nek_chopshop:AddReputation(citizenid, -25, 'admin correction')
end)
```

## Editierbare Hooks

Diese Dateien sind zum Bearbeiten gedacht:

| Datei | Funktion | Zweck |
| :--- | :--- | :--- |
| `editable/server.lua` | `Editable.Webhook` | Discord-Webhook-URL. |
| `editable/server.lua` | `Editable.Server.SendDiscordLog(title, description, color)` | Eigener Log-Versand. |
| `editable/server.lua` | `Editable.Server.CustomReward(source)` | Zusätzliche Belohnung bei Jobabschluss (Krypto, XP, Items...). |
| `editable/server.lua` | `Editable.Server.DispatchAlert(data, source)` | Eigener Dispatch (`System = 'custom'`). |
| `editable/server.lua` | `Editable.Server.GiveVehicleKeys` / `RemoveVehicleKeys` | Eigene Schlüssel (`System = 'custom'`). |
| `editable/server.lua` | `Editable.Inventory` | Eigener Inventar-Adapter (`Config.Inventory = 'custom'`). |
| `editable/client.lua` | `Editable.Client.MiniGame()` | Lockpick-Minispiel; gib bei Erfolg `true` zurück. Standard `lib.skillCheck`. |
| `editable/client.lua` | `Editable.Client.DispatchAlert(data)` | Eigener Dispatch auf dem Client des Diebs. |
| `editable/client.lua` | `Editable.Client.Notify(data)` | Benachrichtigungsstil (verwendet, wenn die NUI aus oder nicht bereit ist). |

Jede Funktion enthält kommentierte Beispiele und die genaue Form ihrer Argumente.

## NUI anpassen

Die NUI liegt in `web/` (einfache Web Components, kein Build-Schritt). Die Lua-Seite und die Seite teilen sich einen einzigen Vertrag: [web/CONTRACT.md](../../web/CONTRACT.md) (Nachrichten, Callbacks, View-Payloads, Locale-Schlüssel).

- **Farben, Schriften, Abstände und Platzierung** sind CSS-Variablen in `web/styles/tokens.css`: Papier- und Tintenfarben (`--paper-original`, `--ink`, `--stamp`...), Schriften (`--font-print`, `--font-hand`, `--font-num`) und die Position des Jobzettels (`--tracker-top`, `--tracker-right`).
- **Texte** stammen aus dem Abschnitt `nui` von `locales/<lang>.json`.
- `Config.UseNUI = false` entfernt die NUI und nutzt Menüs und Benachrichtigungen von ox_lib.

## Items und Icons

Jedes Teil, Bonus-Item, Abschlussbelohnung und Klassen-Beute-Item wird beim Start und bei jedem Neustart des Inventars gegen die Item-Liste des Inventars geprüft (übersprungen, wenn das Inventar keinen Export für die Item-Liste hat). Unbekannte Beute-Einträge werden mit einer Konsolenwarnung verworfen; unbekannte Teile, Bonus-Items und Belohnungen werden nur gemeldet.

| Item | Herkunft |
| :--- | :--- |
| `vehicle_door`, `vehicle_hood`, `vehicle_trunk`, `vehicle_engine`, `vehicle_seat`, `veh_wheels` | Teile |
| `car-battery` | Bonus der Motorhaube |
| `veh_suspension` | Standard-`Config.FinishReward` |
| `scrap_metal`, `sport_wheel`, `turbo_kit` | Klassen-Beute |

Die Icons liegen in `[assets]`, nach ihrem Item benannt. Sie stammen aus der RAINMAD-Bildergalerie (https://items.rainmad.com/).

## Fehlerbehebung

| Problem | Ursache und Lösung |
| :--- | :--- |
| `No such export getSharedObject in resource es_extended` (oder ähnlich) | `Config.Framework` ist auf ein Framework erzwungen, das nicht gestartet ist. Setze `'auto'`. Seit 2.0.0 fällt ein erzwungenes, nicht gestartetes Framework auf die automatische Erkennung zurück und gibt eine Warnung aus. |
| `... item "x" is not registered in <inventory>` in der Konsole | Das Item fehlt in deinem Inventar. Füge es aus [docs/items](../items/) hinzu. |
| `No supported inventory detected` | Kein Inventar der Liste ist gestartet. Starte es vor nek_chopshop oder nutze `'custom'`. |
| Der Spieler hat nach dem Lockpick keine Schlüssel | Prüfe `Config.VehicleKeys.System`: Dein Schlüssel-Skript wird eventuell nicht unterstützt (nutze `'custom'`) oder ist nicht gestartet. |
| Keine Polizeimeldung | Prüfe `Config.Police.Dispatch.System`: Das Skript ist eventuell nicht gestartet oder wird nicht unterstützt (nutze `'custom'`). |
| "Not enough police on duty" | `Config.Police.MinOnDuty` (oder das `minPolice` der Klasse) ist höher als die Zahl der Beamten im Dienst. Setze es auf `0`, um es zu deaktivieren. |
| "You have to wait N minutes before working again." | Job-Cooldown. Das Team kann `chopshop_resetcd <id>` oder `chopshop_resetcd all` ausführen. |
| "Nobody drives here that fast. Wait N s and try again." | Die Anti-Teleport-Prüfung hat eine Lieferung abgelehnt, die schneller war als `Config.Security.MaxAverageSpeed`. Warte die angezeigten Sekunden. Teammitglieder mit `Config.AdminAce` überspringen die Prüfung. |
| Die Maus bleibt auf dem Bildschirm | Führe `/chopshopui` aus. |
| `Could not check for updates.` | Der Server erreicht GitHub nicht. Harmlos. |
| Fehler bei der Ruf-Tabelle | oxmysql funktioniert nicht. Prüfe seinen Connection-String. |

Setze `Config.Debug = true` für zusätzliche Konsolenausgaben.

Hinweis: Die zitierten Meldungen sind die englischen Texte; im Spiel erscheinen sie in der konfigurierten Sprache.

## Update von v1

Inkompatible Änderungen:

- **Items:** 6 neue Items (`vehicle_trunk`, `vehicle_engine`, `vehicle_seat`, `scrap_metal`, `sport_wheel`, `turbo_kit`). Registriere sie und kopiere ihre Bilder (siehe "Installation").
- **Bild umbenannt:** `[assets]/vehicle_wheel.png` heißt jetzt `[assets]/veh_wheels.png` (der Item-Name `veh_wheels` hat sich nicht geändert). Benenne es in den Bildern deines Inventars um, falls du das alte kopiert hast.
- **Locales:** `Config.Locales` ist entfallen. Die Texte liegen jetzt in `locales/*.json` (ox_lib). Falls du Texte bearbeitet hast, übernimm sie in deine Sprachdatei.
- **Fahrzeuge:** Die flache Liste `Config.Vehicles` wurde zu `Config.Tiers` (die alte Liste funktioniert weiter als eine `low`-Klasse).
- **Neue Konfigurationsabschnitte:** `Config.Inventory`, `Config.Police`, `Config.VehicleKeys`, `Config.TimeLimit`, `Config.Reputation`, `Config.Tiers`, `Config.AdminAce`, `Config.UseNUI`, `Config.SellPed.QualityMultiplier`. `Config.Framework` ist jetzt standardmäßig `'auto'`. Übernimm sie aus der neuen `shared/config.lua`.
- **Editierbare Hooks:** `Editable.Client.DispatchAlert` erhält jetzt eine `data`-Tabelle statt des Fahrzeugs (`data.vehicle` ist die Entity). Neue Hooks: `Editable.Server.DispatchAlert`, `Editable.Server.GiveVehicleKeys`, `Editable.Server.RemoveVehicleKeys`, `Editable.Inventory`.
- **Abhängigkeiten:** `oxmysql` ist jetzt erforderlich. `ox_inventory` ist nicht mehr erforderlich.
- **Exports:** Der Client-Export ist `exports.nek_chopshop:GetJobStatus()` (verwende den echten Ordnernamen der Ressource); neue Server-Exports `GetReputation` und `AddReputation`.

Sichere deine `shared/config.lua` und die Dateien in `editable/`, bevor du die Ressource ersetzt, und wende deine Änderungen danach auf den neuen Dateien erneut an. Vollständige Liste der Änderungen: [CHANGELOG.md](../../CHANGELOG.md).

## Dokumentation in anderen Sprachen

- [English](../../README.md)
- [Español](README.es.md)
- [Português (Brasil)](README.pt-br.md)
- [Français](README.fr.md)

## Lizenz

Proprietär, Quellcode einsehbar. Du darfst es auf deinen Servern nutzen, ändern und das Repository forken; Verkauf, erneutes Hochladen oder Weitergabe außerhalb eines Forks sind nicht erlaubt. Vollständige Bedingungen (auf Englisch) in [LICENSE](../../LICENSE).
