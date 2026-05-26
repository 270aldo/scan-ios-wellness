import SwiftUI

/// Dedicated, lightweight screen for managing consents.
/// This is the start of moving consent management out of the heavy ProfileStrategistEditor (Phase B).
struct ConsentSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WLScreen {
                VStack(alignment: .leading, spacing: WLSpacing.l) {
                    WLSectionHeader(
                        title: "Privacidad y Consentimientos",
                        subtitle: "Controla qué datos puede usar la app para personalizar tus guías.",
                        systemImage: "hand.raised"
                    )

                    // AI Processing
                    consentToggle(
                        title: "Procesamiento con IA",
                        description: "Permite que los análisis de escaneo y las respuestas del coach usen inteligencia artificial (Vertex AI / Gemini) para mayor personalización. Cuando está desactivado, todo se genera localmente en tu dispositivo.",
                        isOn: Binding(
                            get: { model.userProfile.consentFlags.aiProcessing },
                            set: { newValue in
                                var updated = model.userProfile
                                updated.consentFlags.aiProcessing = newValue
                                model.updateUserProfile(updated)
                            }
                        )
                    )

                    Divider()

                    // Health Data Processing
                    consentToggle(
                        title: "Datos de salud (ciclo, sueño, HRV, etc.)",
                        description: "Permite que la app lea datos de HealthKit (ciclo menstrual, sueño, variabilidad cardíaca, temperatura de muñeca, entrenamientos) para adaptar las recomendaciones a tu biología actual. Estos datos solo salen de tu dispositivo si también tienes activado el procesamiento con IA.",
                        isOn: Binding(
                            get: { model.userProfile.consentFlags.healthDataProcessing },
                            set: { newValue in
                                var updated = model.userProfile
                                updated.consentFlags.healthDataProcessing = newValue
                                model.updateUserProfile(updated)
                            }
                        )
                    )

                    Divider()

                    // Analytics
                    consentToggle(
                        title: "Analíticas",
                        description: "Permite enviar datos de uso anonimizados (sin notas privadas) para mejorar la aplicación.",
                        isOn: Binding(
                            get: { model.userProfile.consentFlags.analytics },
                            set: { newValue in
                                var updated = model.userProfile
                                updated.consentFlags.analytics = newValue
                                model.updateUserProfile(updated)
                            }
                        )
                    )

                    Divider()

                    // Notifications
                    consentToggle(
                        title: "Notificaciones",
                        description: "Permitir notificaciones push (Daily Brief y recordatorios).",
                        isOn: Binding(
                            get: { model.userProfile.consentFlags.notifications },
                            set: { newValue in
                                var updated = model.userProfile
                                updated.consentFlags.notifications = newValue
                                model.updateUserProfile(updated)
                            }
                        )
                    )

                    Spacer(minLength: WLSpacing.l)

                    // Link to full privacy notice
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Para más detalles sobre cómo tratamos tus datos, consulta el")
                            .font(WLTypography.caption)
                            .foregroundStyle(WLPalette.inkSoft)

                        if let url = model.services.configuration.privacyPolicyURL {
                            Link("Aviso de Privacidad completo", destination: url)
                                .font(WLTypography.captionStrong)
                        } else {
                            Text("Aviso de Privacidad")
                                .font(WLTypography.captionStrong)
                                .foregroundStyle(WLPalette.inkSoft)
                        }
                    }
                    .padding(.top, WLSpacing.m)
                }
            }
            .navigationTitle("Privacidad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func consentToggle(title: String, description: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: WLSpacing.xs) {
            Toggle(title, isOn: isOn)
                .font(WLTypography.bodyStrong)
                .tint(WLPalette.tint)

            Text(description)
                .font(WLTypography.caption)
                .foregroundStyle(WLPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ConsentSettingsView()
        .environment(AppModel())
}