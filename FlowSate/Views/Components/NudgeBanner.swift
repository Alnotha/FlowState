//
//  NudgeBanner.swift
//  FlowSate
//
//  Created by Alyan Tharani on 2/9/26.
//

import SwiftUI

struct NudgeBanner: View {
    let nudge: EmotionalNudge
    let onAction: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: nudge.type.icon)
                .font(.title2)
                .foregroundStyle(nudge.type.color.gradient)
                .frame(width: 40, height: 40)
                .background(nudge.type.color.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(nudge.message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineSpacing(2)

                if let actionLabel = nudge.actionLabel, let onAction {
                    Button {
                        onAction()
                    } label: {
                        Text(actionLabel)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}
