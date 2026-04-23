import Foundation

// MARK: - Contract types

/// Resumen liviano de un ScanVerdict para inyectar en el coach context.
struct CoachVerdictSummary: Codable, Sendable, Hashable {
    var verdictId: String
    var productName: String
    var fit: String
    var createdAt: Date
}

/// Entrada de check-in para el coach context.
struct CoachCheckInEntry: Codable, Sendable, Hashable {
    var date: String  // yyyy-MM-dd
    var energy: Int
    var bloating: Int
    var mood: Int
    var note: String?
}

/// Turno de conversación previo.
struct CoachThreadTurn: Codable, Sendable, Hashable {
    var role: String  // "user" | "assistant"
    var content: String
    var timestamp: Date?
}

struct CoachAgentRequest: Sendable {
    var userMessage: String
    var profile: UserProfile
    var biometrics: BiometricsSnapshot?

    var latestVerdict: LILADomain.ScanVerdict?
    var recentVerdicts: [LILADomain.ScanVerdict]
    var recentCheckIns: [CheckInEvent]
    var memorySummaries: [String]
    var patternInsights: [String]
    var threadHistory: [CoachThreadTurn]
}

// MARK: - Reply (maps 1:1 to CoachReplySchema.json)

enum CoachTone: String, Codable, Sendable, Hashable {
    case warmDirect
    case supportive
    case cautious
    case celebratory
}

enum CoachEvidenceTier: String, Codable, Sendable, Hashable {
    case high
    case emerging
    case personalPattern
}

enum CoachSuggestedActionType: String, Codable, Sendable, Hashable {
    case scan
    case checkIn = "check_in"
    case viewVerdict = "view_verdict"
    case consultProfessional = "consult_professional"
    case none
}

enum CoachSafetyFlag: String, Codable, Sendable, Hashable {
    case crisisSignal = "crisis_signal"
    case edGuardrail = "ed_guardrail"
    case pregnancyGuardrail = "pregnancy_guardrail"
    case diabetesGuardrail = "diabetes_guardrail"
    case minorDetected = "minor_detected"
}

enum CoachVoiceTag: String, Codable, Sendable, Hashable {
    case warm
    case calm
    case curious
    case encouraging
    case cautious
    case gentle
    case confident
    case playful
}

struct CoachSuggestedAction: Codable, Sendable, Hashable {
    var type: CoachSuggestedActionType
    var label: String
    var deepLinkHint: String?
}

struct CoachReply: Codable, Sendable, Hashable, Identifiable {
    var id: String { replyId }

    var replyId: String
    var createdAt: Date

    var message: String
    var tone: CoachTone

    var referencedVerdictId: String?
    var referencedVerdictSummary: String?
    var referencedPatterns: [String]

    var suggestedActions: [CoachSuggestedAction]
    var followUpQuestion: String?

    var safetyFlags: [CoachSafetyFlag]
    var evidenceTier: CoachEvidenceTier
    var disclaimer: String

    // Voice-ready (ignorados en V1)
    var voiceTags: [CoachVoiceTag]?
    var voiceDirective: String?
    var spokenVersion: String?
}

// MARK: - Protocol

protocol CoachAgentServing: Sendable {
    func generateReply(for request: CoachAgentRequest) async -> CoachReply
}

// MARK: - DeterministicCoachAgent

/// Fallback local sin red. Cubre guardrails críticos, detección básica de intent
/// y generación de CoachReply en español MX. No reemplaza al backend real; sostiene
/// conversaciones cuando no hay conectividad.
struct DeterministicCoachAgent: CoachAgentServing {
    func generateReply(for request: CoachAgentRequest) async -> CoachReply {
        let context = request.lilaContext
        let combined = [
            request.userMessage,
            request.coachContextSummary,
            request.memorySummaries.joined(separator: " "),
            request.recentCheckIns.map(\.notes).joined(separator: " ")
        ].joined(separator: " ").lowercased()

        // Guardrail priorities
        if containsAny(combined, ["no puedo más", "no puedo mas", "no quiero estar aquí",
                                  "no quiero estar aqui", "lastimarme", "suicid", "desespera"]) {
            return crisisReply(request: request)
        }
        if context.hasEDGuardrail
            || containsAny(combined, ["edhistory", "trastorno aliment", "eating disorder"])
            || containsEDIntent(userMessage: request.userMessage.lowercased()) {
            return edGuardrailReply(request: request)
        }
        if context.hasPregnancyGuardrail
            || containsAny(combined, ["embaraz", "pregnan", "obstetra", "primer trimestre"]) {
            return pregnancyGuardrailReply(request: request)
        }
        if context.hasDiabetesGuardrail
            || containsAny(combined, ["diabetes", "glucosa", "insulina"]) {
            return diabetesGuardrailReply(request: request)
        }

        // Intent routing
        let userLower = request.userMessage.lowercased()
        if containsAny(userLower, ["estoy harta", "ya no puedo", "estoy cansada",
                                   "estoy agotada", "no me siento bien"]) {
            return frustrationReply(request: request)
        }
        if containsAny(userLower, ["está bien", "esta bien", "me conviene",
                                   "puedo tomar", "recomiendas", "qué onda con",
                                   "que onda con"]) {
            return productWithoutScanReply(request: request)
        }
        if containsAny(userLower, ["por qué me siento", "por que me siento",
                                   "por qué llevo", "por que llevo",
                                   "varios días", "varios dias"])
            && !request.recentCheckIns.isEmpty {
            return patternInterpretationReply(request: request)
        }
        if containsAny(userLower, ["¿qué es", "qué es", "que es",
                                   "por qué", "por que", "cómo funciona",
                                   "como funciona", "es normal"]) {
            return educationalReply(request: request)
        }

        return openConversationReply(request: request)
    }

    // MARK: Guardrail builders

    private func crisisReply(request: CoachAgentRequest) -> CoachReply {
        CoachReply(
            replyId: UUID().uuidString,
            createdAt: .now,
            message: """
            Lo que me cuentas me importa. No tienes que sostener esto sola, y hay \
            líneas profesionales que atienden exactamente lo que estás viviendo. \
            En México puedes marcar al 800-290-0024 (SAPTEL), y si estás en \
            Estados Unidos, el 988 de la Línea de Crisis. ¿Hay alguien cercano a \
            quien puedas llamar ahora mismo?
            """,
            tone: .supportive,
            referencedVerdictId: nil,
            referencedVerdictSummary: nil,
            referencedPatterns: [],
            suggestedActions: [
                CoachSuggestedAction(
                    type: .consultProfessional,
                    label: "Marca una línea de apoyo ahora",
                    deepLinkHint: nil
                )
            ],
            followUpQuestion: "¿Quieres que te acompañe hasta que llegues con alguien?",
            safetyFlags: [.crisisSignal],
            evidenceTier: .high,
            disclaimer: """
            Si estás en crisis, por favor busca apoyo profesional inmediato. \
            Nácar ofrece guía direccional de wellness, no diagnóstico ni tratamiento médico.
            """,
            voiceTags: [.gentle, .warm, .calm],
            voiceDirective: "pause-after-sentence-1",
            spokenVersion: nil
        )
    }

    private func edGuardrailReply(request: CoachAgentRequest) -> CoachReply {
        CoachReply(
            replyId: UUID().uuidString,
            createdAt: .now,
            message: """
            Aquí vamos con calma. Lo que está sobre la mesa no lo vamos a tratar con \
            números ni con lógica de restricción; eso suele volver el ciclo más difícil, \
            no más fácil. Lo que sí suma es cerrar el día con algo que se sienta nutritivo \
            y tranquilo. Si te está pesando, platicarlo con tu terapeuta vale mucho.
            """,
            tone: .supportive,
            referencedVerdictId: nil,
            referencedVerdictSummary: nil,
            referencedPatterns: [],
            suggestedActions: [
                CoachSuggestedAction(
                    type: .consultProfessional,
                    label: "Platícalo con tu terapeuta si aplica",
                    deepLinkHint: nil
                )
            ],
            followUpQuestion: "¿Qué te sentiría cuidar bien hoy?",
            safetyFlags: [.edGuardrail],
            evidenceTier: .high,
            disclaimer: """
            Si este tipo de análisis te activa restricción, prioriza apoyo clínico y una \
            lectura más amable. Nácar ofrece guía direccional de wellness, no diagnóstico \
            ni tratamiento médico.
            """,
            voiceTags: [.gentle, .warm],
            voiceDirective: "pause-after-sentence-1",
            spokenVersion: nil
        )
    }

    private func pregnancyGuardrailReply(request: CoachAgentRequest) -> CoachReply {
        CoachReply(
            replyId: UUID().uuidString,
            createdAt: .now,
            message: """
            En embarazo lo que siempre cierra mejor es llevarlo con tu ginecóloga u \
            obstetra, especialmente para decisiones específicas sobre suplementos, \
            cafeína y cualquier cambio en tu alimentación. Puedo darte contexto general, \
            pero la decisión final la tomas con tu equipo de salud.
            """,
            tone: .cautious,
            referencedVerdictId: nil,
            referencedVerdictSummary: nil,
            referencedPatterns: [],
            suggestedActions: [
                CoachSuggestedAction(
                    type: .consultProfessional,
                    label: "Consulta con tu ginecóloga u obstetra",
                    deepLinkHint: nil
                )
            ],
            followUpQuestion: nil,
            safetyFlags: [.pregnancyGuardrail],
            evidenceTier: .high,
            disclaimer: """
            En embarazo, cualquier decisión específica conviene revisarla con tu equipo médico. \
            Nácar ofrece guía direccional de wellness, no diagnóstico ni tratamiento médico.
            """,
            voiceTags: [.warm, .cautious],
            voiceDirective: nil,
            spokenVersion: nil
        )
    }

    private func diabetesGuardrailReply(request: CoachAgentRequest) -> CoachReply {
        CoachReply(
            replyId: UUID().uuidString,
            createdAt: .now,
            message: """
            Con diabetes, cualquier ajuste nutricional importante conviene revisarlo con \
            tu equipo médico. Lo que puedo hacer es darte lecturas específicas de productos \
            cuando los escanees, pero sin sugerir cambios drásticos de carbos o de tu manejo.
            """,
            tone: .warmDirect,
            referencedVerdictId: nil,
            referencedVerdictSummary: nil,
            referencedPatterns: [],
            suggestedActions: [
                CoachSuggestedAction(
                    type: .consultProfessional,
                    label: "Revisa esto con tu equipo médico",
                    deepLinkHint: nil
                ),
                CoachSuggestedAction(
                    type: .scan,
                    label: "Escanea lo que quieras evaluar",
                    deepLinkHint: "scan/barcode"
                )
            ],
            followUpQuestion: nil,
            safetyFlags: [.diabetesGuardrail],
            evidenceTier: .high,
            disclaimer: """
            Consulta con tu equipo médico antes de cualquier cambio nutricional. \
            Nácar ofrece guía direccional de wellness, no diagnóstico ni tratamiento médico.
            """,
            voiceTags: [.warm, .confident],
            voiceDirective: nil,
            spokenVersion: nil
        )
    }

    // MARK: Intent builders

    private func frustrationReply(request: CoachAgentRequest) -> CoachReply {
        var patterns: [String] = []
        if !request.recentCheckIns.isEmpty {
            patterns.append("Check-ins recientes de \(request.recentCheckIns.count) días registrados")
        }
        return CoachReply(
            replyId: UUID().uuidString,
            createdAt: .now,
            message: """
            Lo escucho. Esto que describes no es falta de voluntad ni de disciplina — \
            a veces hay semanas donde el cuerpo pide otra cosa y vale la pena parar a \
            observarlo. Si quieres, podemos revisar lo que traes registrado para ver \
            si hay algún patrón.
            """,
            tone: .supportive,
            referencedVerdictId: nil,
            referencedVerdictSummary: nil,
            referencedPatterns: patterns,
            suggestedActions: [
                CoachSuggestedAction(
                    type: .checkIn,
                    label: "Registra cómo te sientes hoy",
                    deepLinkHint: "checkin/new"
                )
            ],
            followUpQuestion: "¿Qué parte pesa más hoy?",
            safetyFlags: [],
            evidenceTier: .personalPattern,
            disclaimer: "Nácar ofrece guía direccional de wellness, no diagnóstico ni tratamiento médico.",
            voiceTags: [.gentle, .warm, .calm],
            voiceDirective: "pause-after-sentence-1",
            spokenVersion: nil
        )
    }

    private func productWithoutScanReply(request: CoachAgentRequest) -> CoachReply {
        CoachReply(
            replyId: UUID().uuidString,
            createdAt: .now,
            message: """
            Para darte una lectura real de cómo te afecta, necesito escanearlo. Mándame \
            el código de barras o una foto de la etiqueta y te doy contexto en un minuto — \
            ahí puedo ver si el perfil te va a funcionar para tu contexto actual.
            """,
            tone: .warmDirect,
            referencedVerdictId: nil,
            referencedVerdictSummary: nil,
            referencedPatterns: [],
            suggestedActions: [
                CoachSuggestedAction(
                    type: .scan,
                    label: "Escanea el producto",
                    deepLinkHint: "scan/barcode"
                )
            ],
            followUpQuestion: nil,
            safetyFlags: [],
            evidenceTier: .emerging,
            disclaimer: "Nácar ofrece guía direccional de wellness, no diagnóstico ni tratamiento médico.",
            voiceTags: [.warm, .confident],
            voiceDirective: nil,
            spokenVersion: nil
        )
    }

    private func patternInterpretationReply(request: CoachAgentRequest) -> CoachReply {
        var patterns: [String] = []
        var actions: [CoachSuggestedAction] = []
        var referencedVerdictId: String?
        var referencedVerdictSummary: String?

        if let recent = request.recentCheckIns.first {
            patterns.append("Energy \(recent.energy)/5 y bloating \(recent.bloating)/5 en tu último check-in")
        }

        if let verdict = request.latestVerdict {
            referencedVerdictId = verdict.id.uuidString
            referencedVerdictSummary = """
            Tu último scan fue \(verdict.resolvedProduct.name) con fit \(verdict.fit.rawValue).
            """
            actions.append(
                CoachSuggestedAction(
                    type: .viewVerdict,
                    label: "Revisa el último veredicto",
                    deepLinkHint: "analysis/\(verdict.id.uuidString)"
                )
            )
        }

        actions.append(
            CoachSuggestedAction(
                type: .checkIn,
                label: "Registra cómo sigues estos días",
                deepLinkHint: "checkin/new"
            )
        )

        return CoachReply(
            replyId: UUID().uuidString,
            createdAt: .now,
            message: """
            En tus check-ins recientes veo el dato que me dices. Antes de sacar \
            conclusión fuerte, me ayudaría saber más — a veces es fase del ciclo, a \
            veces comida, a veces sueño. Vale la pena registrarlo un par de días más \
            para ver qué patrón sale.
            """,
            tone: .warmDirect,
            referencedVerdictId: referencedVerdictId,
            referencedVerdictSummary: referencedVerdictSummary,
            referencedPatterns: patterns,
            suggestedActions: Array(actions.prefix(3)),
            followUpQuestion: "¿Notaste algo específico que haya cambiado esta semana?",
            safetyFlags: [],
            evidenceTier: .personalPattern,
            disclaimer: "Nácar ofrece guía direccional de wellness, no diagnóstico ni tratamiento médico.",
            voiceTags: [.warm, .curious],
            voiceDirective: nil,
            spokenVersion: nil
        )
    }

    private func educationalReply(request: CoachAgentRequest) -> CoachReply {
        CoachReply(
            replyId: UUID().uuidString,
            createdAt: .now,
            message: """
            Buena pregunta. Lo que está detrás tiene que ver con cómo cambia tu \
            biología según la fase del ciclo y tu contexto individual. Puedo darte más \
            detalle si me dices qué parte te interesa — si es el síntoma en sí, si es \
            qué hacer, o si es por qué te pasa.
            """,
            tone: .warmDirect,
            referencedVerdictId: nil,
            referencedVerdictSummary: nil,
            referencedPatterns: [],
            suggestedActions: [],
            followUpQuestion: "¿Qué parte te gustaría entender mejor?",
            safetyFlags: [],
            evidenceTier: .high,
            disclaimer: "Nácar ofrece guía direccional de wellness, no diagnóstico ni tratamiento médico.",
            voiceTags: [.warm, .confident],
            voiceDirective: nil,
            spokenVersion: nil
        )
    }

    private func openConversationReply(request: CoachAgentRequest) -> CoachReply {
        CoachReply(
            replyId: UUID().uuidString,
            createdAt: .now,
            message: """
            Cuéntame más. Puedo ayudarte mejor si me dices qué te está pasando hoy — \
            energía, digestión, ciclo, lo que sea. Y si tienes un producto específico \
            en mente, mándame el código y lo miramos juntas.
            """,
            tone: .warmDirect,
            referencedVerdictId: nil,
            referencedVerdictSummary: nil,
            referencedPatterns: [],
            suggestedActions: [
                CoachSuggestedAction(
                    type: .scan,
                    label: "Escanea un producto",
                    deepLinkHint: "scan/barcode"
                ),
                CoachSuggestedAction(
                    type: .checkIn,
                    label: "Registra cómo te sientes hoy",
                    deepLinkHint: "checkin/new"
                )
            ],
            followUpQuestion: "¿Qué tienes hoy sobre la mesa?",
            safetyFlags: [],
            evidenceTier: .emerging,
            disclaimer: "Nácar ofrece guía direccional de wellness, no diagnóstico ni tratamiento médico.",
            voiceTags: [.warm, .curious],
            voiceDirective: nil,
            spokenVersion: nil
        )
    }

    // MARK: Helpers

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains(where: { text.contains($0) })
    }

    private func containsEDIntent(userMessage: String) -> Bool {
        // Frases que indican posible intención de restricción/compensación
        let redFlags = [
            "me salto la",
            "saltar la comida",
            "saltarme",
            "compensar lo que",
            "quemar calorías",
            "déficit",
            "deficit"
        ]
        return containsAny(userMessage, redFlags)
    }
}

extension CoachAgentRequest {
    var lilaContext: LILADomain.UserContext {
        profile.lilaContext(biometrics: biometrics)
    }

    var coachContextSummary: String {
        let context = lilaContext
        var parts: [String] = []

        if let age = context.identity.age {
            parts.append("Age: \(age)")
        }
        parts.append("Biology: \(context.biology.displayTitle)")
        parts.append("Diet style: \(context.dietStyle.rawValue)")

        if let phase = context.biology.currentPhase {
            parts.append("Cycle phase: \(phase.rawValue)")
        }
        if context.biology.isBreastfeeding {
            parts.append("Breastfeeding")
        }
        if !context.conditions.isEmpty {
            parts.append("Conditions: \(context.conditions.map(\.rawValue).sorted().joined(separator: ", "))")
        }
        if !context.sensitivities.isEmpty {
            parts.append("Sensitivities: \(context.sensitivities.map(\.rawValue).sorted().joined(separator: ", "))")
        }
        if !context.goals.primary.isEmpty {
            parts.append("Goals: \(context.goals.primary.map(\.displayTitle).joined(separator: ", "))")
        }
        if biometrics?.trainingLoad?.isInAnabolicWindow == true {
            parts.append("Recently trained")
        }
        if let sleepHours = biometrics?.sleepHours, sleepHours < 6 {
            parts.append("Short sleep recent")
        }
        if let personalNote = context.personalNote, !personalNote.isEmpty {
            parts.append("Note: \(personalNote)")
        }

        return parts.joined(separator: ". ")
    }
}

private extension LILADomain.UserContext {
    var hasPregnancyGuardrail: Bool {
        switch biology {
        case .pregnant:
            true
        case let .postpartum(context):
            context.breastfeeding
        default:
            false
        }
    }

    var hasEDGuardrail: Bool {
        conditions.contains(.edHistory)
    }

    var hasDiabetesGuardrail: Bool {
        conditions.contains(.type1Diabetes)
            || conditions.contains(.type2Diabetes)
            || conditions.contains(.gestationalDiabetes)
    }
}
