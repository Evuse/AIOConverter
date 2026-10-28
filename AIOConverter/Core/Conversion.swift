import Foundation

public enum Conversion {
    /// Quotes must share one base: number of currency units per USD.
    public static func convert(_ amount: Decimal, from: String, to: String,
                               rates: [String: Decimal]) -> Decimal? {
        guard let source = rates[from], let target = rates[to],
              source > 0, target > 0, !amount.isNaN else { return nil }
        let result = amount / source * target
        return result.isNaN ? nil : result
    }

    /// Accept both iPhone decimal separators, without ambiguous grouping separators.
    public static func parse(_ text: String) -> Decimal? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard normalized.count <= 30,
              normalized.range(of: #"^\d+(\.\d*)?$"#, options: .regularExpression) != nil
        else { return nil }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    public static func formatted(_ amount: Decimal, digits: Int,
                                 locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = digits
        let threshold = pow(10.0, -Double(digits))
        if amount != 0, abs(NSDecimalNumber(decimal: amount).doubleValue) < threshold {
            formatter.numberStyle = .scientific
            formatter.maximumFractionDigits = min(digits, 6)
        }
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "—"
    }
}

public struct RateSnapshot: Codable, Equatable {
    public let rates: [String: Decimal]
    public let fetchedAt: Date
    public let source: String
    public let rateDate: String?

    public init(rates: [String: Decimal], fetchedAt: Date, source: String, rateDate: String?) {
        self.rates = rates
        self.fetchedAt = fetchedAt
        self.source = source
        self.rateDate = rateDate
    }

    public static func coinbase(_ data: Data, now: Date = Date()) throws -> RateSnapshot {
        struct Response: Decodable {
            struct Body: Decodable { let currency: String; let rates: [String: String] }
            let data: Body
        }
        let body = try JSONDecoder().decode(Response.self, from: data).data
        guard body.currency == "USD" else { throw RateError.invalidResponse }
        let rates = body.rates.reduce(into: [String: Decimal]()) { result, pair in
            if let value = Decimal(string: pair.value, locale: Locale(identifier: "en_US_POSIX")),
               !value.isNaN, value > 0 { result[pair.key.uppercased()] = value }
        }
        return try checked(rates, now: now, source: "Coinbase", rateDate: nil)
    }

    public static func daily(_ data: Data, now: Date = Date()) throws -> RateSnapshot {
        struct Response: Decodable { let date: String; let usd: [String: Decimal] }
        let body = try JSONDecoder().decode(Response.self, from: data)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: body.date),
              formatter.string(from: date) == body.date,
              date <= now.addingTimeInterval(86400) else { throw RateError.invalidResponse }
        let rates = body.usd.reduce(into: [String: Decimal]()) { result, pair in
            if !pair.value.isNaN, pair.value > 0 { result[pair.key.uppercased()] = pair.value }
        }
        return try checked(rates, now: now, source: "Currency API · giornaliero", rateDate: body.date)
    }

    private static func checked(_ rates: [String: Decimal], now: Date,
                                source: String, rateDate: String?) throws -> RateSnapshot {
        guard rates["USD"] == 1, rates["EUR"] != nil, rates["BTC"] != nil else {
            throw RateError.invalidResponse
        }
        return RateSnapshot(rates: rates, fetchedAt: now, source: source, rateDate: rateDate)
    }
}

public enum RateError: Error { case invalidResponse, http(Int) }
