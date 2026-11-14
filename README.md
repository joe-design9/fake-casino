# Muse Casino — Fake Casino (nur Spielgeld)

**Muse Casino** ist eine native iOS-App (SwiftUI, iOS 26, Liquid-Glass-Design) mit drei
Spielautomaten. Es ist ein **reines Fake-Casino**: 100 % Spielgeld, **kein Echtgeld**,
keine In-App-Käufe, keine Werbung, keine Auszahlungen und keine Links zu echten Casinos.
In der App steht das auch überall ausdrücklich dabei („Nur Spielgeld – kein Echtgeld").

## Die Automaten

| Automat | Mechanik |
|---|---|
| **Book of Muse** | 5 Walzen × 3 Reihen, 10 Linien. Das Buch ist Wild + Scatter: 3+ Bücher zahlen 5×/25×/100× des Gesamteinsatzes und starten **10 Freispiele** mit einem zufälligen Expandier-Symbol (klassische Book-of-Mechanik, inkl. Retrigger). |
| **Vice Fruits** | 5 Walzen × 3 Reihen, 10 Linien. Frucht-Klassiker (Kirsche, Zitrone, Traube, Pflaume, Glocke, Diamant, Sieben). Kirschen zahlen schon ab 2 Treffern. |
| **Mochi Millions** | 3 Walzen, 5 Linien. Plüsch-Teddy, Diamant, Stern, Herz, Münze, Glocke – plus Juwelen-Mix-Gewinn. |

Gemeinsam: Guthaben wird lokal gespeichert (Start: 10.000 Coins), Tagesbonus +1.000 Coins,
Gratis-Refill, wenn das Guthaben fast leer ist, Statistiken (Drehungen & größter Gewinn),
gestaffelte Walzen-Stopps, Gewinnlinien-Highlights und Gewinnzähler-Animation.

## IPA installieren (Sideloadly / AltStore)

Die GitHub-Actions-Builds erzeugen eine **unsignierte** `MuseCasino.ipa`
(als Workflow-Artefakt und – bei einem Release – als Release-Datei).

1. `MuseCasino.ipa` herunterladen (Actions-Artefakt oder Release).
2. iPhone per Kabel mit dem PC verbinden.
3. **Sideloadly** öffnen, die IPA hineinziehen, deine (kostenlose) Apple-ID eintragen
   und „Start" klicken. Sideloadly signiert die App mit deinem kostenlosen
   Entwickler-Zertifikat.
4. Auf dem iPhone: *Einstellungen → Allgemein → VPN & Geräteverwaltung* → dein
   Entwickler-Zertifikat vertrauen.
5. Fertig – Muse Casino erscheint auf dem Homescreen.

Hinweise zum kostenlosen Signieren:

- Die Signatur läuft nach **7 Tagen** ab. Dann einfach erneut mit Sideloadly/AltStore
  installieren bzw. in AltStore „Refresh" ausführen – Spielstände (Guthaben) bleiben
  bei gleicher Bundle-ID erhalten.
- Bundle-ID der App: `dev.joe.fakecasino`.

## Selbst bauen (Xcode)

Voraussetzung: macOS mit aktuellem Xcode (iOS-26-SDK).

```bash
git clone https://github.com/joe-design9/fake-casino.git
cd fake-casino
open FakeCasino.xcodeproj
```

- Scheme **FakeCasino** wählen, iPhone als Ziel auswählen, ▶ Run.
- Für die eigene Signierung im Target unter *Signing & Capabilities* das eigene
  Team (kostenlose Apple-ID reicht) auswählen.
- Unsigned-Build wie die CI:

```bash
xcodebuild -project FakeCasino.xcodeproj -scheme FakeCasino \
  -configuration Release -sdk iphoneos \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

## Projektstruktur

```
FakeCasino/
  FakeCasinoApp.swift        App-Einstieg
  LobbyView.swift            Root-TabView + Lobby (Guthaben, Bonus, Statistiken)
  WalletStore.swift          Spielgeld-Guthaben & Statistiken (UserDefaults)
  SlotMath.swift             Gewinnlinien & gemeinsame Typen
  Components.swift           Liquid-Glass-Bausteine, Balance-Anzeige, Buttons
  BookOfMuseEngine.swift     Mathematik: Book of Muse
  BookOfMuseView.swift       UI + ViewModel: Book of Muse
  ViceFruitsEngine.swift     Mathematik: Vice Fruits
  ViceFruitsView.swift       UI + ViewModel: Vice Fruits
  MochiMillionsEngine.swift  Mathematik: Mochi Millions
  MochiMillionsView.swift    UI + ViewModel: Mochi Millions
.github/workflows/build-ipa.yml   CI: baut & verpackt die IPA
```

**Disclaimer:** Ein Unterhaltungsspiel ohne Echtgeld. Gewinne sind Spielgeld-Coins
ohne jeden realen Wert.

## GOLDKRONE Spielhalle

**GOLDKRONE Spielhalle** ist eine eigene native iOS-App (SwiftUI) im Look einer
deutschen Spielhalle: dunkles Navy, goldene Rahmen, LED-Anzeigen und ein roter
RISIKO-Knopf. Sie liegt im Ordner `spielhalle/` und hat nichts mit Muse Casino
zu tun. Bundle-ID: `dev.joe.goldkrone`. Anzeigename: **Goldkrone**.

Es ist **ausschließlich Spielgeld**. Keine Käufe, keine Werbung, keine
Auszahlungen, keine Links nach draußen. In der App steht dauerhaft
„Nur Spielgeld – keine echten Gewinne“. Die Währung heißt **Kronentaler (KT)**
und hat keinen realen Wert. Das Maskottchen ist eine goldene Krone.

### Automaten

| Automat | Mechanik |
|---|---|
| **Fruchtfeuer** | 5×3, 10 Linien. Kirsche, Zitrone, Pflaume, Traube, Melone, Glocke, BAR und Sieben. Kirschen zahlen ab 2. |
| **Buch der Sphinx** | 5×3, 10 Linien. Das Buch ist Wild und Scatter. 3+ Bücher starten **10 Freispiele** mit einem zufälligen Expandier-Symbol, inklusive Retrigger. |
| **Joker Sterne** | 5×3, 5 Linien. Joker ist Wild, Sterne zahlen irgendwo auf den Walzen. |

Dazu: Einsatzstufen von 10 bis 1.000 KT, Turbo, Autoplay (10/25/50/100, Stopp bei
Freispielen, großem Gewinn ab 15× oder leerem Guthaben), **Risikoleiter** und
**Kartenrisiko** (Rot/Schwarz, die letzten 6 Karten). Ab 15× Einsatz gibt es
„GROSSER GEWINN“, ab 50× „MEGA GEWINN“.

Startguthaben: **5.000 KT**. Täglicher Bonus 1.000 KT, mit Serie bis 2.200 KT.
Liegt das Guthaben unter dem Mindesteinsatz, gibt es eine gratis Auffüllung.
Statistik: Drehungen, Einsatz, Gewinn, größter Gewinn, Quote je Automat.
Ton und Haptik lassen sich in der Halle abschalten. Klänge werden im Gerät
erzeugt, es gibt keine fremden Audiodateien.

Die Auszahlungsquote jedes Automaten liegt bei etwa **95 %** (Zielband 93–97 %,
Trefferquote etwa 25–35 %). Das prüft ein fest gesäter Simulationstest im
Target `GoldkroneTests`.

### IPA installieren (Sideloadly / AltStore)

Die Workflow-Datei `.github/workflows/build-goldkrone.yml` baut bei Änderungen
unter `spielhalle/` eine **unsignierte** `Goldkrone.ipa` und hängt sie zusammen
mit `Goldkrone-screenshots.zip` an ein GitHub-Prerelease.

1. `Goldkrone.ipa` aus dem Prerelease oder dem Actions-Artefakt laden.
2. iPhone per Kabel verbinden.
3. **Sideloadly** (oder AltStore) öffnen, die IPA hineinziehen, eine kostenlose
   Apple-ID eintragen und starten. Das Tool signiert die App mit deinem Zertifikat.
4. Auf dem iPhone: *Einstellungen → Allgemein → VPN & Geräteverwaltung* → das
   Entwicklerzertifikat **vertrauen**.
5. Goldkrone liegt auf dem Home-Bildschirm.

Hinweise zum kostenlosen Signieren:

- Die Signatur läuft nach **7 Tagen** ab. Danach erneut mit Sideloadly installieren
  oder in AltStore „Refresh“ tippen. Das Guthaben bleibt bei gleicher Bundle-ID
  erhalten.
- Es ist ein Unterhaltungsspiel. Kronentaler kann man nicht kaufen und nicht
  auszahlen.

### Selbst bauen

```bash
open spielhalle/Goldkrone.xcodeproj
```

Scheme **Goldkrone**, iPhone wählen, ausführen. Für einen Unsigned-Build wie in
der CI:

```bash
xcodebuild -project spielhalle/Goldkrone.xcodeproj -scheme Goldkrone \
  -configuration Release -sdk iphoneos \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```
