import SwiftUI

struct HandoverWarningView: View {
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.red)
                }
                .padding(.top, 32)
                .padding(.bottom, 20)

                // Title
                Text("Hand Device to Supervisor")
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Body
                Text("Before starting navigation, hand your phone to your supervising driver. The device should be mounted or held by your supervisor — not the learner driver.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 12)

                // Buttons
                VStack(spacing: 10) {
                    Button {
                        onConfirm()
                    } label: {
                        Text("Supervisor has the device")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.glassRounded)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                    )

                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16))
                            .foregroundStyle(.red.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.glassRounded)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.red.opacity(0.15), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 28)
            }
            .modifier(GlassFrostedModifier(cornerRadius: 40))
            .overlay(
                RoundedRectangle(cornerRadius: 40)
                    .strokeBorder(Color.red.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .shadow(color: .black.opacity(0.4), radius: 30, y: 10)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }
}
