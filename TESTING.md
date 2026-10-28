# Verifica su Mac / iPhone

Queste prove richiedono Xcode e non risultano ancora eseguite nell’ambiente Linux.

1. Eseguire `swift test`: devono passare tutti i sette metodi XCTest, senza test saltati.
2. Eseguire la build per simulatore indicata nel README, quindi avviare l’app su iPhone con iOS 16 o successivo.
3. Con rete attiva, controllare caricamento, fonte e data. Verificare EUR → USD, USD → SOL e BTC → EUR; digitare `12,50` e `12.50`. Modificare ogni riga e verificare che le altre non cambino.
4. Provare zero, campo vuoto, testo incollato non numerico, separatori multipli e un importo molto piccolo. Il campo vuoto/non valido deve mostrare `—`; una quantità piccola valida non deve essere arrotondata a zero.
5. Cercare Bitcoin ed EUR, cambiare entrambi i lati e scambiarli. L’importo digitato deve restare invariato durante lo scambio.
6. Provare tema sistema/chiaro/scuro e precisione 2/4/6/8; riavviare l’app e verificare il ripristino di preferenze e tre righe.
7. Dopo un download riuscito, togliere la rete e attendere almeno 60 secondi prima di aggiornare. Verificare che restino disponibili i calcoli con cache e che siano visibili avviso e date. Ripetere senza cache su una nuova installazione: nessun valore fittizio, errore leggibile, possibilità di riprovare.
8. Con uno strumento di rete di sviluppo, simulare errore/429 Coinbase: deve essere usato il fallback e comparire la sua data giornaliera. Simulare fallimento di entrambe le fonti e controllare che non vengano cancellati i tassi precedenti.
9. Verificare con un monitor di rete che digitare/scambiare valute non faccia richieste e che aggiornamenti ripetuti rispettino il cooldown. Gli importi digitati non devono apparire nelle richieste.
10. Provare iPhone SE e un iPhone grande, tastiera, testo accessibilità e VoiceOver. Le tre schede devono restare nella stessa schermata, scorribile quando necessario, con selettori e pulsante Fine accessibili.
11. Configurare firma, bundle identifier e icona su dispositivo reale prima di Archive/TestFlight. Controllare condizioni dei provider e dichiarazioni privacy App Store.
