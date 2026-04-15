import SwiftUI

struct CheckInView: View {
    @Environment(AppModel.self) private var model

    @State private var energy = 3.0
    @State private var skin = 3.0
    @State private var bloatingRelief = 3.0
    @State private var cravingControl = 3.0
    @State private var mood = 3.0
    @State private var note = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Quick daily check-in")
                    .font(.title2.bold())

                metricSlider(title: "Energy", value: $energy, helper: "1 = drained, 5 = steady")
                metricSlider(title: "Skin", value: $skin, helper: "1 = irritated, 5 = clear and calm")
                metricSlider(title: "Bloating relief", value: $bloatingRelief, helper: "1 = uncomfortable, 5 = calm")
                metricSlider(title: "Craving control", value: $cravingControl, helper: "1 = constant, 5 = stable")
                metricSlider(title: "Mood", value: $mood, helper: "1 = flat, 5 = lifted")

                TextEditor(text: $note)
                    .frame(minHeight: 120)
                    .padding(10)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if note.isEmpty {
                            Text("Optional note")
                                .foregroundStyle(.secondary)
                                .padding(18)
                        }
                    }

                Button("Save check-in") {
                    model.addCheckIn(
                        energy: Int(energy.rounded()),
                        skin: Int(skin.rounded()),
                        bloatingRelief: Int(bloatingRelief.rounded()),
                        cravingControl: Int(cravingControl.rounded()),
                        mood: Int(mood.rounded()),
                        note: note
                    )
                    note = ""
                }
                .buttonStyle(.borderedProminent)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Weekly signals")
                        .font(.headline)
                    ForEach(model.weeklyInsights) { insight in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title)
                                .font(.subheadline.bold())
                            Text(insight.summary)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Check-In")
        .background(Color(red: 0.98, green: 0.97, blue: 0.99))
    }

    private func metricSlider(title: String, value: Binding<Double>, helper: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded())) / 5")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            Slider(value: value, in: 1...5, step: 1)
            Text(helper)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
