import SwiftUI

struct ProductCardView: View {
    let product: Product
    let accentColor: Color
    var onAddToMemo: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            productImages

            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if !product.description.isEmpty {
                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text(product.priceText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(accentColor)

                if let onAddToMemo {
                    Button(action: onAddToMemo) {
                        Label("買い物メモに追加", systemImage: "checklist")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(accentColor)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.gray.opacity(0.15))
            .frame(width: 90, height: 90)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray.opacity(0.4))
                    .font(.title2)
            )
    }

    @ViewBuilder
    private var productImages: some View {
        let images = product.uiImages
        if images.isEmpty {
            imagePlaceholder
        } else if images.count == 1, let image = images.first {
            productImage(image)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(46), spacing: 4), count: 2),
                spacing: 4
            ) {
                ForEach(images.prefix(4).indices, id: \.self) { index in
                    productThumbnail(images[index])
                }
            }
            .frame(width: 96, height: 96)
        }
    }

    private func productImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func productThumbnail(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
