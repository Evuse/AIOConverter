# AIO Converter · iPhone

App nativa **SwiftUI per iOS 16 e successivi**. Tre conversioni indipendenti nella stessa schermata, ispirate alla versione Mac, con schede adattate a iPhone e icona originale blu/ciano.

## Aprire ed eseguire

1. Su un Mac con **Xcode 15 o successivo**, apri `AIOConverter.xcodeproj`.
2. Seleziona lo schema **AIOConverter** e un simulatore iPhone, poi premi **Run**.
3. Per un iPhone reale, seleziona il tuo Team in **Signing & Capabilities**. Se necessario, sostituisci `com.evuse.AIOConverter` con un bundle identifier disponibile. Non sono incluse credenziali o certificati di firma.

Il progetto non richiede CocoaPods, pacchetti esterni, backend, account o chiavi API. Il deployment target è iOS 16.0. Su schermi piccoli, con tastiera aperta o testo ingrandito, la schermata scorre per mantenere accessibili tutte le schede.

## Funzioni

- Tre importi e coppie indipendenti, calcolati localmente a ogni modifica.
- Scambio della coppia mantenendo l’importo digitato.
- Ricerca per codice e nome, filtri FIAT/Crypto e valute comuni in cima.
- Input con virgola o punto decimale, senza separatori delle migliaia.
- Calcolo con `Decimal`; risultati con 2, 4, 6 o 8 decimali. Le quantità piccolissime usano la notazione scientifica.
- Tema di sistema, chiaro o scuro; compatibilità con Dynamic Type e controlli VoiceOver.
- Preferenze, tre conversioni e ultimo elenco dei tassi salvati sul dispositivo.
- Cache offline identificata come tale, con data del download e, dove disponibile, data dei tassi.

## Fonti e frequenza

**Primaria: Coinbase**, endpoint pubblico senza autenticazione:

```
https://api.coinbase.com/v2/exchange-rates?currency=USD
```

**Fallback: Currency API di Fawaz Ahmed via jsDelivr**, aggiornamento giornaliero:

```
https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json
```

L’app tenta Coinbase e passa al fallback in caso di errore HTTP, timeout o risposta non valida. La schermata indica la fonte effettiva e distingue l’ora di ricezione Coinbase dalla data dei tassi giornalieri. I tassi di ogni risposta sono applicati insieme: non si mescolano basi o fonti diverse.

Le conversioni non fanno chiamate di rete. Il download avviene all’apertura, al ritorno in primo piano, ogni minuto mentre l’app è attiva e tramite il pulsante di aggiornamento, con un intervallo minimo condiviso di 60 secondi. Dopo un errore si conserva la cache senza inventare quotazioni. Il fallback può restituire lo stesso dato per tutta la giornata.

Nessun servizio pubblico può garantire richieste illimitate o quotazioni per **ogni** valuta o token esistente. Il catalogo riflette le valute della fonte corrente; se una coppia salvata non è più disponibile, l’app lo segnala e permette di sceglierne un’altra. I tassi sono indicativi e non comprendono spread, commissioni o prezzi di esecuzione.

Riferimenti: [Coinbase](https://docs.cdp.coinbase.com/coinbase-app/track-apis/exchange-rates), [Currency API e licenza](https://github.com/fawazahmed0/exchange-api).

## Verifica

Su macOS, dalla radice del repository:

```sh
swift test
xcodebuild -project AIOConverter.xcodeproj -scheme AIOConverter \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

La GitHub Action `.github/workflows/ios.yml` esegue questi comandi a ogni push/PR. I sette test XCTest del package coprono conversioni FIAT/crypto, input locali e invalidi, risultati piccoli, risposte delle due API, dati incompleti e serializzazione della cache. Il package serve a testare il motore; il progetto Xcode include lo stesso sorgente nell’app.

In questo ambiente Linux sono stati verificati la sintassi Swift tramite parser, la struttura del progetto Xcode, schema, manifest privacy e icona. L’endpoint fallback ha restituito oltre 330 valute, con cataloghi e date variabili tra le risposte CDN; Coinbase è bloccato dal proxy dell’ambiente con HTTP 403. **Build iOS, esecuzione degli XCTest e prove su simulatore non sono state eseguite**, perché qui non sono installati Swift/Xcode. Una validazione sintattica non sostituisce la compilazione.

Prima di distribuire, eseguire anche la checklist in `TESTING.md`. Il progetto non è firmato né pubblicato su TestFlight/App Store.

## Struttura

| File | Responsabilità |
| --- | --- |
| `AIOConverter/ContentView.swift` | Schermata, schede, ricerca, impostazioni |
| `AIOConverter/ConverterModel.swift` | Stato, persistenza, aggiornamento e cooldown |
| `AIOConverter/RateService.swift` | Richieste HTTPS e fallback |
| `AIOConverter/Core/Conversion.swift` | Calcolo, formattazione e validazione delle risposte |
| `AIOConverter/Assets.xcassets` | Icona iOS, 1024 × 1024 senza trasparenza |
| `AIOConverter/PrivacyInfo.xcprivacy` | Uso di UserDefaults limitato all’app |

Gli importi digitati non sono inviati ai provider. Le richieste ai provider espongono normalmente indirizzo IP e metadati HTTP ai rispettivi servizi; non sono inclusi SDK di analytics. Prima della pubblicazione, verificare le condizioni aggiornate dei provider e compilare le dichiarazioni privacy richieste da Apple.
