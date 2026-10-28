import SwiftUI

struct ConversionRow: Codable, Identifiable {
    var id = UUID()
    var amount: String
    var from: String
    var to: String

    static let defaults = [
        ConversionRow(amount: "100", from: "EUR", to: "USD"),
        ConversionRow(amount: "100", from: "USD", to: "SOL"),
        ConversionRow(amount: "1", from: "BTC", to: "EUR")
    ]
}

@MainActor
final class ConverterModel: ObservableObject {
    @Published var rows: [ConversionRow] { didSet { saveRows() } }
    @Published private(set) var snapshot: RateSnapshot?
    @Published private(set) var loading = false
    @Published private(set) var message: String?
    @Published private(set) var usingCache = false
    private var lastAttempt: Date?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "conversionRows"),
           let saved = try? JSONDecoder().decode([ConversionRow].self, from: data), saved.count == 3 {
            rows = saved
        } else { rows = ConversionRow.defaults }
        if let data = defaults.data(forKey: "rateSnapshot"),
           let cached = try? JSONDecoder().decode(RateSnapshot.self, from: data),
           cached.rates["USD"] == 1 {
            snapshot = cached
            usingCache = true
        }
    }

    var codes: [String] { (snapshot?.rates.keys.map { $0 } ?? []).sorted() }

    func refresh() async {
        guard !loading else { return }
        // A shared cooldown covers manual refresh, foregrounding and the periodic task.
        if let lastAttempt, Date().timeIntervalSince(lastAttempt) < 60 { return }
        lastAttempt = Date()
        loading = true
        defer { loading = false }
        do {
            let fresh = try await RateService().fetch()
            snapshot = fresh
            usingCache = false
            message = nil
            if let data = try? JSONEncoder().encode(fresh) { defaults.set(data, forKey: "rateSnapshot") }
        } catch {
            guard !Task.isCancelled else { return }
            usingCache = snapshot != nil
            message = snapshot == nil
                ? "Tassi non disponibili. Controlla la connessione e riprova tra un minuto."
                : "Aggiornamento non riuscito. Sono mostrati gli ultimi tassi salvati."
        }
    }

    private func saveRows() {
        if let data = try? JSONEncoder().encode(rows) { defaults.set(data, forKey: "conversionRows") }
    }
}

enum CurrencyInfo {
    static let fiat = Set(Locale.commonISOCurrencyCodes)
    static let cryptoNames = ["BTC": "Bitcoin", "ETH": "Ethereum", "SOL": "Solana", "USDC": "USD Coin",
                              "USDT": "Tether", "XRP": "XRP", "ADA": "Cardano", "DOGE": "Dogecoin",
                              "AVAX": "Avalanche", "DOT": "Polkadot", "LTC": "Litecoin", "LINK": "Chainlink"]
    static func name(_ code: String) -> String {
        cryptoNames[code] ?? Locale.current.localizedString(forCurrencyCode: code) ?? code
    }
    static func symbol(_ code: String) -> String {
        ["EUR": "€", "USD": "$", "GBP": "£", "JPY": "¥", "BTC": "₿", "ETH": "Ξ", "SOL": "◎"][code]
            ?? String(code.prefix(1))
    }
}
