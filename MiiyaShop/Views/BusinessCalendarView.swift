import SwiftUI

struct BusinessCalendarView: View {
    let days: [String: BusinessDayStatus]
    var isEditable = false
    var onTapDate: (Date) -> Void = { _ in }

    @State private var displayedMonth = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: Date())
    ) ?? Date()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    moveMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.system(size: 18, weight: .bold))

                Spacer()

                Button {
                    moveMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarSlots.indices, id: \.self) { index in
                    if let date = calendarSlots[index] {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 46)
                    }
                }
            }

            HStack(spacing: 12) {
                legend(status: .open)
                legend(status: .closed)
                Text("未設定")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var monthTitle: String {
        let components = Calendar.current.dateComponents([.year, .month], from: displayedMonth)
        return "\(components.year ?? 0)年\(components.month ?? 0)月"
    }

    private var calendarSlots: [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }

        let leadingBlanks = calendar.component(.weekday, from: firstDay) - 1
        let dates = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }

        return Array(repeating: nil, count: leadingBlanks) + dates
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let day = Calendar.current.component(.day, from: date)
        let status = days[BusinessCalendarKey.key(for: date)]
        let content = VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            Text(status?.symbol ?? "-")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(status?.color ?? .secondary)
                .frame(height: 20)
        }
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill((status?.color ?? Color.gray).opacity(status == nil ? 0.06 : 0.12))
        )

        if isEditable {
            Button {
                onTapDate(date)
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(day)日")
            .accessibilityHint("営業日を切り替えます")
        } else {
            content
        }
    }

    private func legend(status: BusinessDayStatus) -> some View {
        HStack(spacing: 4) {
            Text(status.symbol)
                .font(.caption.weight(.bold))
                .foregroundColor(status.color)
            Text(status.label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func moveMonth(_ value: Int) {
        displayedMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
    }
}
