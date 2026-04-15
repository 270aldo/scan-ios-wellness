import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedRecordIDs = Set<UUID>()

    var body: some View {
        @Bindable var model = model

        List {
            if model.history.isEmpty {
                ContentUnavailableView(
                    "No history yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Scans build your pantry + vanity memory here.")
                )
            } else {
                ForEach(model.history) { record in
                    HStack(alignment: .top, spacing: 12) {
                        Button {
                            model.latestAnalysis = record.analysis
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(record.analysis.resolvedProduct.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(record.analysis.overallSummary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            Button {
                                model.toggleFavorite(for: record.id)
                            } label: {
                                Image(systemName: record.isFavorite ? "star.fill" : "star")
                                    .foregroundStyle(record.isFavorite ? .yellow : .secondary)
                            }
                            .buttonStyle(.plain)

                            Button {
                                toggleComparisonSelection(for: record.id)
                            } label: {
                                Text(selectedRecordIDs.contains(record.id) ? "Selected" : "Compare")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(selectedRecordIDs.contains(record.id) ? Color.accentColor : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if selectedRecordIDs.count == 2 {
                    Button("Compare") {
                        let selectedRecords = model.history.filter { selectedRecordIDs.contains($0.id) }
                        model.compare(selectedRecords)
                    }
                }
            }
        }
        .sheet(item: $model.activeComparison, onDismiss: {
            model.dismissComparison()
        }) { comparison in
            ComparisonView(comparison: comparison)
        }
    }

    private func toggleComparisonSelection(for id: UUID) {
        if selectedRecordIDs.contains(id) {
            selectedRecordIDs.remove(id)
            return
        }
        if selectedRecordIDs.count == 2, let first = selectedRecordIDs.first {
            selectedRecordIDs.remove(first)
        }
        selectedRecordIDs.insert(id)
    }
}

struct ComparisonView: View {
    let comparison: ProductComparison
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Products") {
                    comparisonRow(
                        title: comparison.left.resolvedProduct.name,
                        subtitle: comparison.left.overallSummary
                    )
                    comparisonRow(
                        title: comparison.right.resolvedProduct.name,
                        subtitle: comparison.right.overallSummary
                    )
                }

                Section("Lens delta") {
                    ForEach(comparison.deltas) { delta in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(delta.lens.title)
                                .font(.headline)
                            Text("\(comparison.left.resolvedProduct.name): \(delta.leftScore)")
                            Text("\(comparison.right.resolvedProduct.name): \(delta.rightScore)")
                                .foregroundStyle(.secondary)
                            Text(delta.delta >= 0 ? "+\(delta.delta) improvement" : "\(delta.delta) lower")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(delta.delta >= 0 ? .green : .orange)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Compare")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func comparisonRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }
}
