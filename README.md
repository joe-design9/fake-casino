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
