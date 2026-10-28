import XCTest
@testable import ConverterCore

final class ConversionTests: XCTestCase {
    let rates: [String: Decimal] = ["USD": 1, "EUR": Decimal(string: "0.9")!,
                                    "BTC": Decimal(string: "0.00002")!, "SOL": Decimal(string: "0.01")!]

    func testCrossRatesUseTheSameBase() {
        XCTAssertEqual(Conversion.convert(90, from: "EUR", to: "USD", rates: rates), 100)
        XCTAssertEqual(Conversion.convert(100, from: "USD", to: "SOL", rates: rates), 1)
        XCTAssertEqual(Conversion.convert(1, from: "BTC", to: "EUR", rates: rates), 45000)
    }

    func testZeroIdentityAndMissingRates() {
        XCTAssertEqual(Conversion.convert(0, from: "BTC", to: "EUR", rates: rates), 0)
        XCTAssertEqual(Conversion.convert(12, from: "EUR", to: "EUR", rates: rates), 12)
        XCTAssertNil(Conversion.convert(10, from: "EUR", to: "UNKNOWN", rates: rates))
        XCTAssertNil(Conversion.convert(10, from: "USD", to: "EUR", rates: ["USD": 0, "EUR": 1]))
    }

    func testLocalizedInputAndInvalidInput() {
        XCTAssertEqual(Conversion.parse("12,50"), Decimal(string: "12.5"))
        XCTAssertEqual(Conversion.parse(" 12.50 "), Decimal(string: "12.5"))
        XCTAssertEqual(Conversion.parse("0,"), 0)
        for input in ["", "abc", "-1", "1,234.56", "1.2.3", "1e9", "NaN", String(repeating: "9", count: 31)] {
            XCTAssertNil(Conversion.parse(input), input)
        }
    }

    func testFormattingDoesNotRoundTinyCryptoToZero() {
        let tiny = Conversion.formatted(Decimal(string: "0.0000000012")!, digits: 4, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(tiny.contains("E"), tiny)
        XCTAssertEqual(Conversion.formatted(Decimal(string: "12.34567")!, digits: 4, locale: Locale(identifier: "it_IT")), "12,3457")
    }

    func testCoinbasePayloadAndInvalidRates() throws {
        let data = Data(#"{"data":{"currency":"USD","rates":{"USD":"1","EUR":"0.9","BTC":"0.00002","BAD":"NaN","ZERO":"0"}}}"#.utf8)
        let snapshot = try RateSnapshot.coinbase(data)
        XCTAssertEqual(snapshot.rates["EUR"], Decimal(string: "0.9"))
        XCTAssertNil(snapshot.rates["BAD"])
        XCTAssertNil(snapshot.rates["ZERO"])
        XCTAssertEqual(snapshot.source, "Coinbase")
        XCTAssertNil(snapshot.rateDate)
    }

    func testDailyPayloadAndCacheRoundTrip() throws {
        let data = Data(#"{"date":"2026-01-01","usd":{"usd":1,"eur":0.9,"btc":0.00002,"bad":-1}}"#.utf8)
        let snapshot = try RateSnapshot.daily(data, now: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(snapshot.rates["BTC"], Decimal(string: "0.00002"))
        XCTAssertNil(snapshot.rates["BAD"])
        XCTAssertEqual(snapshot.rateDate, "2026-01-01")
        XCTAssertEqual(try JSONDecoder().decode(RateSnapshot.self, from: JSONEncoder().encode(snapshot)), snapshot)
    }

    func testMalformedAndIncompletePayloadsAreRejected() {
        XCTAssertThrowsError(try RateSnapshot.coinbase(Data("{}".utf8)))
        XCTAssertThrowsError(try RateSnapshot.coinbase(Data(#"{"data":{"currency":"EUR","rates":{"USD":"1","EUR":"1","BTC":"1"}}}"#.utf8)))
        XCTAssertThrowsError(try RateSnapshot.daily(Data(#"{"date":"2026-01-01","usd":{"usd":1}}"#.utf8)))
        XCTAssertThrowsError(try RateSnapshot.daily(Data(#"{"date":"invalid","usd":{"usd":1,"eur":1,"btc":1}}"#.utf8)))
    }
}
