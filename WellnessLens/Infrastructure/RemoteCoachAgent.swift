import Foundation

/// Cliente HTTP que llama al endpoint `POST /v1/coach/reply` del agent-service.
///
/// Si la red falla, el servidor devuelve error, el payload no valida, o el
/// timeout se cumple, hace auto-fallback al `DeterministicCoachAgent` local
/// sin propagar el error a la UI.
///
/// El contract a mantener es: `generateReply(for:)` **siempre** devuelve un
/// `CoachReply` válido. Si hay fallback, la UI ni se entera.
struct RemoteCoachAgent: CoachAgentServing {
    let endpoint: URL
    let session: URLSession
    let timeoutSeconds: TimeInterval
    let localFallback: CoachAgentServing

    init(
        endpoint: URL,
        session: URLSession = .shared,
        timeoutSeconds: TimeInterval = 8,
        localFallback: CoachAgentServing = DeterministicCoachAgent()
    ) {
        self.endpoint = endpoint
        self.session = session
        self.timeoutSeconds = timeoutSeconds
        self.localFallback = localFallback
    }

    func generateReply(for request: CoachAgentRequest) async -> CoachReply {
        do {
            let payload = try buildRequestPayload(from: request)
            var urlRequest = URLRequest(url: endpoint)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.httpBody = payload
            urlRequest.timeoutInterval = timeoutSeconds

            let (data, response) = try await session.data(for: urlRequest)

            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return await localFallback.generateReply(for: request)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom(Self.decodeDate)
            let reply = try decoder.decode(CoachReply.self, from: data)
            return reply
        } catch {
            return await localFallback.generateReply(for: request)
        }
    }

    // MARK: - Request payload construction

    private func buildRequestPayload(from request: CoachAgentRequest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.makeRequestDateFormatter().string(from: date))
        }

        let wire = CoachReplyRequestWire(
            userMessage: request.userMessage,
            userContextSummary: request.coachContextSummary,
            latestVerdictSummary: request.latestVerdict.map(Self.summary(from:)),
            recentVerdictSummaries: request.recentVerdicts.prefix(5).map(Self.summary(from:)),
            recentCheckIns: request.recentCheckIns.prefix(3).map(Self.checkInEntry(from:)),
            memorySummaries: Array(request.memorySummaries.prefix(5)),
            patternInsights: Array(request.patternInsights.prefix(3)),
            threadHistory: Array(request.threadHistory.suffix(10))
        )

        return try encoder.encode(wire)
    }

    private static func summary(from verdict: LILADomain.ScanVerdict) -> CoachVerdictSummaryWire {
        CoachVerdictSummaryWire(
            verdictId: verdict.id.uuidString,
            productName: verdict.resolvedProduct.name,
            fit: verdict.fit.rawValue,
            createdAt: verdict.createdAt
        )
    }

    private static func checkInEntry(from event: CheckInEvent) -> CoachCheckInEntryWire {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")

        return CoachCheckInEntryWire(
            date: formatter.string(from: event.timestamp),
            energy: event.energy,
            bloating: event.bloating,
            mood: event.mood,
            note: event.notes
        )
    }

    private static func decodeDate(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        for formatter in makeResponseDateFormatters() {
            if let date = formatter.date(from: rawValue) {
                return date
            }
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported date format: \(rawValue)"
        )
    }

    private static func makeRequestDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    private static func makeResponseDateFormatters() -> [ISO8601DateFormatter] {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        fractional.timeZone = TimeZone(secondsFromGMT: 0)

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        plain.timeZone = TimeZone(secondsFromGMT: 0)

        return [fractional, plain]
    }
}

// MARK: - Wire models

/// Estos structs son el formato de wire al backend. Se mantienen separados de
/// los structs del contract iOS para que Codex pueda ajustar uno sin romper el
/// otro si el schema cambia.

private struct CoachReplyRequestWire: Encodable {
    let userMessage: String
    let userContextSummary: String
    let latestVerdictSummary: CoachVerdictSummaryWire?
    let recentVerdictSummaries: [CoachVerdictSummaryWire]
    let recentCheckIns: [CoachCheckInEntryWire]
    let memorySummaries: [String]
    let patternInsights: [String]
    let threadHistory: [CoachThreadTurn]

    init(
        userMessage: String,
        userContextSummary: String,
        latestVerdictSummary: CoachVerdictSummaryWire?,
        recentVerdictSummaries: any Sequence<CoachVerdictSummaryWire>,
        recentCheckIns: any Sequence<CoachCheckInEntryWire>,
        memorySummaries: [String],
        patternInsights: [String],
        threadHistory: [CoachThreadTurn]
    ) {
        self.userMessage = userMessage
        self.userContextSummary = userContextSummary
        self.latestVerdictSummary = latestVerdictSummary
        self.recentVerdictSummaries = Array(recentVerdictSummaries)
        self.recentCheckIns = Array(recentCheckIns)
        self.memorySummaries = memorySummaries
        self.patternInsights = patternInsights
        self.threadHistory = threadHistory
    }
}

private struct CoachVerdictSummaryWire: Codable {
    let verdictId: String
    let productName: String
    let fit: String
    let createdAt: Date
}

private struct CoachCheckInEntryWire: Codable {
    let date: String
    let energy: Int
    let bloating: Int
    let mood: Int
    let note: String?
}
