import FamilyControls
import SwiftUI

/// 設定画面（S-05）。
struct SettingsView: View {
    @State private var model = SettingsModel()

    var body: some View {
        NavigationStack {
            List {
                Section("曜日ごとの集中タイム") {
                    ForEach(WeekdayOrder.mondayFirst, id: \.self) { weekday in
                        NavigationLink {
                            DayEditView(model: model, weekday: weekday)
                        } label: {
                            DayRow(weekday: weekday, day: model.settings.days[weekday])
                        }
                    }
                }

                Section("目標と記録") {
                    GoalStepper(minutes: Binding(
                        get: { model.settings.goalMinutes },
                        set: { newValue in model.update(reschedule: false) { $0.goalMinutes = newValue } }
                    ))
                    NavigationLink {
                        SkipDatesView(model: model)
                    } label: {
                        LabeledContent("記録しない日") {
                            Text(model.settings.skipDates.isEmpty ? String(localized: "なし") : String(localized: "\(model.settings.skipDates.count)件"))
                        }
                    }
                }

                Section("許可") {
                    LabeledContent("スクリーンタイム") {
                        Text(screenTimeStatus)
                            .foregroundStyle(Theme.accentBright)
                    }
                    if AuthorizationCenter.shared.authorizationStatus != .approved {
                        Button("スクリーンタイムの利用を許可") {
                            Task { try? await AuthorizationCenter.shared.requestAuthorization(for: .individual) }
                        }
                    }
                }

                if let error = model.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("設定")
        }
    }

    private var screenTimeStatus: String {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved: String(localized: "許可済み")
        case .denied: String(localized: "許可されていません")
        default: String(localized: "未設定")
        }
    }
}

/// 一覧の1行：「月　9:00〜18:00 / フリータイム 12:00〜13:00」
private struct DayRow: View {
    let weekday: Int
    let day: DaySchedule?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(WeekdayOrder.shortName(weekday))
                .frame(width: 32, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                if let day, !day.focus.isEmpty {
                    Text(day.focus.sorted { $0.start < $1.start }.map { "\($0.start.text)〜\($0.end.text)" }.joined(separator: "、"))
                    if !day.free.isEmpty {
                        Text("フリータイム \(day.free.sorted { $0.start < $1.start }.map { "\($0.start.text)〜\($0.end.text)" }.joined(separator: "、"))")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                } else {
                    Text("なし").foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }
}

/// 1つの曜日の編集（デザイン「設定：曜日の編集」）。
struct DayEditView: View {
    @Bindable var model: SettingsModel
    let weekday: Int

    @State private var draft: DaySchedule
    @State private var showCopy = false
    @Environment(\.dismiss) private var dismiss

    init(model: SettingsModel, weekday: Int) {
        self.model = model
        self.weekday = weekday
        _draft = State(initialValue: model.settings.days[weekday] ?? DaySchedule())
    }

    var body: some View {
        List {
            Section {
                DayTimelineBar(day: draft)
                    .listRowBackground(Color.clear)
            }

            Section("集中タイム") {
                ForEach($draft.focus) { $range in
                    TimeRangeRow(range: $range)
                }
                .onDelete { draft.focus.remove(atOffsets: $0) }
                Button {
                    draft.focus.append(DaySchedule.nextRange(after: draft.focus))
                } label: {
                    Label("集中タイムを追加", systemImage: "plus")
                }
            }

            Section {
                ForEach($draft.free) { $range in
                    TimeRangeRow(range: $range)
                }
                .onDelete { draft.free.remove(atOffsets: $0) }
                Button {
                    draft.free.append(DaySchedule.nextRange(after: draft.free))
                } label: {
                    Label("フリータイムを追加", systemImage: "plus")
                }
            } header: {
                Text("フリータイム（触ってよい時間）")
            } footer: {
                Text("記録の対象は \(DurationFormat.hm(draft.targetMinutes))（集中タイム − フリータイム）。15分より短い区間は設定できません。")
            }

            Section {
                Button("この設定をほかの曜日にコピー") { showCopy = true }
            }

            if let error = model.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(WeekdayOrder.fullName(weekday))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完了") { save(to: [weekday]) }
            }
        }
        .sheet(isPresented: $showCopy) {
            CopyDaysSheet(source: weekday) { targets in
                save(to: targets.union([weekday]))
            }
        }
        .onAppear { model.errorMessage = nil }
    }

    private func save(to weekdays: Set<Int>) {
        let day = draft
        let saved = model.update { settings in
            for w in weekdays {
                settings.days[w] = day.focus.isEmpty ? nil : day
            }
        }
        if saved { dismiss() }
    }
}

/// 「この設定をほかの曜日にコピー」で、コピー先の曜日を選ぶ。
private struct CopyDaysSheet: View {
    let source: Int
    let onCopy: (Set<Int>) -> Void

    @State private var targets: Set<Int> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(WeekdayOrder.mondayFirst.filter { $0 != source }, id: \.self) { weekday in
                Button {
                    if targets.contains(weekday) { targets.remove(weekday) } else { targets.insert(weekday) }
                } label: {
                    HStack {
                        Text(WeekdayOrder.fullName(weekday))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if targets.contains(weekday) {
                            Image(systemName: "checkmark").foregroundStyle(Theme.accentBright)
                        }
                    }
                }
            }
            .navigationTitle("コピー先の曜日")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("コピー") {
                        dismiss()
                        onCopy(targets)
                    }
                    .disabled(targets.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// 記録しない日（休日・休暇など）。
struct SkipDatesView: View {
    @Bindable var model: SettingsModel
    @State private var selection: Set<DateComponents> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                MultiDatePicker("記録しない日", selection: $selection, in: Calendar.current.startOfDay(for: Date())...)
            } footer: {
                Text("選んだ日は集中タイムの記録と通知を行いません。")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("記録しない日")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完了") {
                    let keys = Set(selection.compactMap { components -> String? in
                        guard let date = Calendar.current.date(from: components) else { return nil }
                        return FocusSettings.dayKey(date)
                    })
                    if model.update(reschedule: false, { $0.skipDates = keys }) { dismiss() }
                }
            }
        }
        .onAppear {
            selection = Set(model.settings.skipDates.compactMap { key -> DateComponents? in
                let parts = key.split(separator: "-").compactMap { Int($0) }
                guard parts.count == 3 else { return nil }
                return DateComponents(calendar: Calendar.current, era: 1, year: parts[0], month: parts[1], day: parts[2])
            })
        }
    }
}
