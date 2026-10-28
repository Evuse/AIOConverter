import Foundation

struct RateService {
    func fetch() async throws -> RateSnapshot {
        do {
            let data = try await request("https://api.coinbase.com/v2/exchange-rates?currency=USD")
            return try RateSnapshot.coinbase(data)
        } catch {
            try Task.checkCancellation()
            let data = try await request("https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json")
            return try RateSnapshot.daily(data)
        }
    }

    private func request(_ address: String) async throws -> Data {
        var request = URLRequest(url: URL(string: address)!)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw RateError.invalidResponse }
        guard response.statusCode == 200 else { throw RateError.http(response.statusCode) }
        return data
    }
}
