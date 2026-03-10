// CategoryChipView.swift
// MyBaliMap
//
// Capsule chip for category selection in the horizontal scroll row.
// Layout (from UI screenshot):
//   - Selected: blue text, subtle background (or blue fill + white text)
//   - Unselected: plain text, no fill
//   - Min 44pt touch target
//   - Capsule shape
//
// Apple UI Components Used:
//   Text, Capsule (overlay/background), onTapGesture

import SwiftUI

struct CategoryChipView: View {

    // MARK: - Properties

    let category: Category
    let isSelected: Bool
    let onTap: () -> Void

    // MARK: - Body

    var body: some View {
        // TODO: Phase 3 — Finalize styling to match screenshot
        Text(category.name)
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(isSelected ? .blue : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: AppConstants.minTouchTarget)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue.opacity(0.12) : Color.clear)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(Capsule()) // Ensure full area is tappable
            .onTapGesture(perform: onTap)
            .accessibilityLabel("\(category.name) category")
            .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 12) {
        CategoryChipView(
            category: .defaultShopping,
            isSelected: true,
            onTap: {}
        )
        CategoryChipView(
            category: .defaultViewpoints,
            isSelected: false,
            onTap: {}
        )
        CategoryChipView(
            category: .defaultEateries,
            isSelected: false,
            onTap: {}
        )
    }
    .padding()
}
