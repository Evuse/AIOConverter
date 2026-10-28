import SwiftUI

private let accent = Color(red: 0.30, green: 0.51, blue: 1)

@MainActor
struct ContentView: View {
    @ObservedObject var model: ConverterModel
    @AppStorage("digits") private var digits = 4
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = false
    @FocusState private var editing: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .foregroundStyle(accent)
                        Text("AIO CONVERTER").tracking(2).font(.caption.weight(.bold))
                        Spacer()
                        Button { settings = true } label: {
                            Image(systemName: "slider.horizontal.3").font(.title3)
                                .frame(width: 44, height: 44)
                        }.accessibilityLabel("Impostazioni")
                    }
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Ogni valuta.\nUn solo posto.")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text("FIAT & CRYPTO").font(.caption2.weight(.semibold))
                                .tracking(2).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button { Task { await model.refresh() } } label: {
                            Group {
                                if model.loading { ProgressView() }
                                else { Image(systemName: "arrow.clockwise") }
                            }.frame(width: 44, height: 44)
                                .background(accent.opacity(0.12), in: Circle())
                        }.disabled(model.loading).accessibilityLabel("Aggiorna tassi")
                    }
                    status
                    ForEach($model.rows) { $row in
                        ConversionCard(row: $row, rates: model.snapshot?.rates ?? [:],
                                       codes: model.codes, digits: digits, editing: $editing)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                        Text("Tassi indicativi, senza commissioni o spread. Calcolo istantaneo; aggiornamento automatico ogni minuto quando l’app è attiva.")
                    }.font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                    if let snapshot = model.snapshot {
                        Text("\(snapshot.rates.count) valute · \(snapshot.source)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 20).padding(.bottom, 24)
            }
            .background {
                ZStack(alignment: .topTrailing) {
                    Color(uiColor: .systemGroupedBackground)
                    Circle().fill(accent.opacity(0.10)).frame(width: 280, height: 280)
                        .blur(radius: 70).offset(x: 120, y: -120)
                }.ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fine") { editing = nil }
                }
            }
            .sheet(isPresented: $settings) { SettingsView() }
            .task {
                await model.refresh()
                while !Task.isCancelled {
                    do { try await Task.sleep(nanoseconds: 60_000_000_000) }
                    catch { break }
                    if scenePhase == .active { await model.refresh() }
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active { Task { await model.refresh() } }
            }
        }.tint(accent)
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle().fill(model.usingCache ? Color.orange : model.snapshot == nil ? .gray : .green)
                    .frame(width: 6, height: 6).accessibilityHidden(true)
                if let snapshot = model.snapshot {
                    if model.usingCache {
                        Text("Cache · scaricata \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                    } else if let date = snapshot.rateDate {
                        Text("Tassi giornalieri · \(date)")
                    } else {
                        Text("Tassi ricevuti alle \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                    }
                } else { Text(model.loading ? "Caricamento dei tassi…" : "In attesa dei tassi") }
            }.font(.caption.weight(.medium)).foregroundStyle(.secondary)
            if let date = model.snapshot?.rateDate, model.usingCache {
                Text("Data dei tassi: \(date)").font(.caption).foregroundStyle(.secondary)
            }
            if let message = model.message {
                Text(message).font(.caption).foregroundStyle(.orange)
            }
        }.padding(.vertical, 4).accessibilityElement(children: .combine)
    }
}

private struct ConversionCard: View {
    @Binding var row: ConversionRow
    let rates: [String: Decimal]
    let codes: [String]
    let digits: Int
    var editing: FocusState<UUID?>.Binding
    @State private var selection: Selection?

    private enum Selection: String, Identifiable {
        case from, to
        var id: String { rawValue }
    }

    private var result: Decimal? {
        guard let amount = Conversion.parse(row.amount) else { return nil }
        return Conversion.convert(amount, from: row.from, to: row.to, rates: rates)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                currencyButton(row.from, label: "Valuta di partenza") { selection = .from }
                Button {
                    let previous = row.from
                    row.from = row.to
                    row.to = previous
                } label: {
                    Image(systemName: "arrow.left.arrow.right").font(.caption.weight(.bold))
                        .frame(width: 40, height: 44)
                        .background(Color.primary.opacity(0.05), in: Circle())
                }.accessibilityLabel("Scambia \(row.from) e \(row.to)")
                currencyButton(row.to, label: "Valuta di destinazione") { selection = .to }
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TextField("Importo", text: $row.amount)
                    .keyboardType(.decimalPad).focused(editing, equals: row.id)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .accessibilityLabel("Importo in \(row.from)")
                    .onChange(of: row.amount) { value in
                        if value.count > 30 { row.amount = String(value.prefix(30)) }
                    }
                Text(row.from).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 1)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("=").foregroundStyle(.secondary)
                Text(result.map { Conversion.formatted($0, digits: digits) } ?? "—")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.5)
                    .textSelection(.enabled)
                    .accessibilityLabel("Risultato: \(result.map { Conversion.formatted($0, digits: digits) } ?? "non disponibile") \(row.to)")
                Spacer(minLength: 0)
                Text(row.to).font(.caption.weight(.semibold)).foregroundStyle(accent)
            }
            if !row.amount.isEmpty && Conversion.parse(row.amount) == nil {
                Text("Inserisci un importo positivo, senza separatori delle migliaia.")
                    .font(.caption2).foregroundStyle(.orange)
            } else if !rates.isEmpty && (rates[row.from] == nil || rates[row.to] == nil) {
                Text("Valuta non disponibile da questa fonte. Selezionane un’altra.")
                    .font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.primary.opacity(0.05)))
        .sheet(item: $selection) { side in
            CurrencyPicker(codes: codes, selected: side == .from ? row.from : row.to) { code in
                if side == .from { row.from = code } else { row.to = code }
            }
        }
    }

    private func currencyButton(_ code: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(CurrencyInfo.symbol(code)).font(.headline)
                    .frame(width: 28, height: 28)
                    .background(accent.opacity(0.1), in: Circle())
                Text(code).font(.subheadline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("\(label): \(CurrencyInfo.name(code)), \(code)")
    }
}

private struct CurrencyPicker: View {
    let codes: [String]
    let selected: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var filter = "Tutte"
    private let popular = ["EUR", "USD", "GBP", "CHF", "BTC", "ETH", "SOL", "USDC", "USDT"]

    private var filtered: [String] {
        codes.filter { code in
            (filter == "Tutte" || (filter == "FIAT" ? CurrencyInfo.fiat.contains(code) : !CurrencyInfo.fiat.contains(code))) &&
            (search.isEmpty || code.localizedCaseInsensitiveContains(search) || CurrencyInfo.name(code).localizedCaseInsensitiveContains(search))
        }.sorted { lhs, rhs in
            let a = popular.firstIndex(of: lhs) ?? Int.max
            let b = popular.firstIndex(of: rhs) ?? Int.max
            return a == b ? lhs < rhs : a < b
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tipo di valuta", selection: $filter) {
                    ForEach(["Tutte", "FIAT", "Crypto"], id: \.self) { Text($0) }
                }.pickerStyle(.segmented).padding()
                List {
                    if filtered.isEmpty {
                        Text(codes.isEmpty ? "Connettiti e aggiorna i tassi per caricare le valute." : "Nessuna valuta trovata.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(filtered, id: \.self) { code in
                        Button {
                            onSelect(code)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Text(CurrencyInfo.symbol(code)).font(.title3.weight(.semibold))
                                    .frame(width: 40, height: 40)
                                    .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(code).fontWeight(.semibold)
                                    Text(CurrencyInfo.name(code)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if code == selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(accent) }
                            }.foregroundStyle(Color.primary)
                        }.accessibilityAddTraits(code == selected ? .isSelected : [])
                    }
                }.listStyle(.plain)
            }
            .searchable(text: $search, prompt: "Nome o simbolo, es. Bitcoin")
            .navigationTitle("Scegli valuta").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
        }
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("digits") private var digits = 4
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        NavigationStack {
            Form {
                Section("Aspetto") {
                    Picker("Tema", selection: $appearance) {
                        Text("Sistema").tag("system")
                        Text("Chiaro").tag("light")
                        Text("Scuro").tag("dark")
                    }
                    Picker("Decimali", selection: $digits) {
                        ForEach([2, 4, 6, 8], id: \.self) { Text("\($0)").tag($0) }
                    }
                }
                Section("Tassi e privacy") {
                    Text("Coinbase fornisce i tassi pubblici senza chiave API. Se non è raggiungibile, viene usata Currency API tramite jsDelivr, aggiornata giornalmente. La disponibilità dipende dalla fonte: non tutte le valute o i token esistenti sono quotati.")
                    Text("Le richieste sono distanziate di almeno 60 secondi. Importi e preferenze restano sul dispositivo: alla fonte viene richiesto soltanto l’elenco dei tassi con base USD. Nessun account e nessuna analisi del comportamento.")
                    Text("I tassi sono indicativi e possono differire dal prezzo effettivo di acquisto o vendita. Gli importi molto piccoli sono mostrati in notazione scientifica.")
                    Link("API Coinbase", destination: URL(string: "https://docs.cdp.coinbase.com/coinbase-app/track-apis/exchange-rates")!)
                    Link("Currency API · progetto e licenza", destination: URL(string: "https://github.com/fawazahmed0/exchange-api")!)
                }.font(.subheadline)
            }
            .navigationTitle("Impostazioni").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
        }
    }
}
