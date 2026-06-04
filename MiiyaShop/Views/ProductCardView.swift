import SwiftUI

struct ProductCardView: View {
    let product: Product
    let accentColor: Color

    var body: some View {
        HStack(spacing: 14) {
            // Product image from base64
            if let img = product.uiImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                imagePlaceholder
            }

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
}
