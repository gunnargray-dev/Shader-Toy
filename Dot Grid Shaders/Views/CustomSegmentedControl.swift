import SwiftUI

struct CustomSegmentedControl: View {
    @Binding var selection: PatternType
    let items: [PatternType]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = item
                    }
                }) {
                    Text(item.name)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(selection == item ? .semibold : .regular)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background {
                            if selection == item {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white)
                                    .matchedGeometryEffect(id: "SegmentHighlight", in: namespace)
                            }
                        }
                }
                .foregroundColor(selection == item ? .black : .white)
            }
        }
        .padding(4)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray, lineWidth: 1)
         }
    }

    @Namespace private var namespace
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        CustomSegmentedControl(
            selection: .constant(.verticalWave),
            items: PatternType.allCases
        )
        .padding()
    }
}
