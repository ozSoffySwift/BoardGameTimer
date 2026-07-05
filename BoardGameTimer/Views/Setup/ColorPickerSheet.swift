import SwiftUI

// ColorPickerSheet is the bottom sheet from the design showing all ten meeple colors in a
// grid — used both for a player's color on the setup screen and for the default color
// slots on the Settings tab. It doesn't know or care WHOSE color it's picking; the caller
// passes in the current selection and receives the tapped index via `onPick`.
struct ColorPickerSheet: View {
    // The currently-selected color index, marked with a small dot under its meeple.
    let selectedColorIndex: Int

    // Called with the tapped color's index — the caller applies it and closes the sheet.
    let onPick: (Int) -> Void

    // Closes the sheet via the X button without picking anything.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // --- Header: title + close button ---
            HStack {
                Text("Choose Color")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MeeplePalette.silver)
                        .frame(width: 28, height: 28)
                        .background(MeeplePalette.control, in: Circle())
                }
            }

            // --- The 5-across grid of meeple swatches ---
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 5), spacing: 14) {
                ForEach(0..<10) { colorIndex in
                    Button {
                        onPick(colorIndex)
                    } label: {
                        VStack(spacing: 6) {
                            MeepleView(colorIndex: colorIndex)
                                .frame(width: 44)
                            // The little silver dot marking the current selection.
                            Circle()
                                .fill(MeeplePalette.silver)
                                .frame(width: 6, height: 6)
                                .opacity(colorIndex == selectedColorIndex ? 1 : 0)
                        }
                    }
                }
            }
        }
        .padding(20)
        .padding(.bottom, 12)
        .presentationDetents([.height(280)]) // a short sheet — just tall enough for the grid
        .presentationBackground(MeeplePalette.card)
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        ColorPickerSheet(selectedColorIndex: 2, onPick: { _ in })
    }
}
