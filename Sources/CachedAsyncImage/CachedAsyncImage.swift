//
//  CachedAsyncImage.swift
//  CachedImageLoader
//
//  Created by Mercen on 10/16/24.
//

import SwiftUI
import CachedImageLoader

@available(iOS 15, *)
public struct CachedAsyncImage<Content: View>: View {
    private let url: URL?
    private let imageLoader: CachedImageLoader
    private let scale: CGFloat
    private let transaction: Transaction
    private let content: (AsyncImagePhase) -> Content
    @State private var phase: AsyncImagePhase
    
    public init(
        url: URL?,
        imageLoader: CachedImageLoader = .shared,
        scale: CGFloat = 1
    ) where Content == Image {
        self.init(
            url: url,
            imageLoader: imageLoader,
            scale: scale
        ) { phase in
            phase.image ?? Image(uiImage: .init())
        }
    }
    
    public init<I: View, P: View>(
        url: URL?,
        imageLoader: CachedImageLoader = .shared,
        scale: CGFloat = 1,
        @ViewBuilder content: @escaping (Image) -> I,
        @ViewBuilder placeholder: @escaping () -> P
    ) where Content == _ConditionalContent<I, P> {
        self.init(
            url: url,
            imageLoader: imageLoader,
            scale: scale
        ) { phase in
            if let image = phase.image {
                content(image)
            } else {
                placeholder()
            }
        }
    }
    
    public init(
        url: URL?,
        imageLoader: CachedImageLoader = .shared,
        scale: CGFloat = 1,
        transaction: Transaction = .init(),
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.imageLoader = imageLoader
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
        self._phase = State(wrappedValue: .empty)
    }
    
    private func load() async {
        do {
            if let data = try await imageLoader.load(url) {
                withAnimation(transaction.animation) {
                    let uiImage = UIImage(data: data, scale: scale)!
                    phase = .success(Image(uiImage: uiImage))
                }
            } else {
                withAnimation(transaction.animation) {
                    phase = .empty
                }
            }
        } catch {
            withAnimation(transaction.animation) {
                phase = .failure(error)
            }
        }
    }
    
    public var body: some View {
        content(phase)
            .task {
                await load()
            }
    }
}
