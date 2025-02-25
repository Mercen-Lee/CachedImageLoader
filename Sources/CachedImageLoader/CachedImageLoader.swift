//
//  ReactorViewStore.swift
//  
//
//  Created by Tony on 2024/07/09.
//

import Foundation

extension CachedImageLoader {
  public static var shared: CachedImageLoader = .init()
}

public final class CachedImageLoader {
  private let remoteLoader: RemoteLoader
  private let diskCacheLoader: CacheLoader
  private let memoryCacheLoader: CacheLoader

  private init(
    remoteLoader: RemoteLoader = RemoteLoaderImpl(),
    diskCacheLoader: CacheLoader = DiskCacheLoader(),
    memoryCacheLoader: CacheLoader = MemoryCacheLoader()
  ) {
    self.remoteLoader = remoteLoader
    self.diskCacheLoader = diskCacheLoader
    self.memoryCacheLoader = memoryCacheLoader
  }

  public func load(_ url: URL?, activeDiskCache: Bool = true) async throws -> Data? {
    guard let url = url else { return nil }

    // If the image is not in memory cache, try to get it from disk cache
    var imageContainer: CacheContainer?

    // Get image container from memory cache
    let imageContainerFromMemoryCache = try await memoryCacheLoader.get(for: url.absoluteString)
    imageContainer = imageContainerFromMemoryCache

    // If the image is not in memory cache and the disk cache is active, try to get it from disk cache
    if imageContainerFromMemoryCache == nil && activeDiskCache {
      let imageContainerFromDiskCache = try await diskCacheLoader.get(for: url.absoluteString)
      imageContainer = imageContainerFromDiskCache
    }

    // Fetch image
    let response = try await remoteLoader.fetch(for: url, etag: imageContainer?.etag)

    switch response {
    case let .success(data, etag):
      async {
        await withTaskGroup(of: Void.self) { [weak self] group in
          guard let self = self else { return }

          group.addTask {
            try? await self.memoryCacheLoader.save(
              for: url.absoluteString,
              .init(image: data, etag: etag)
            )
          }
          
          group.addTask {
            try? await self.diskCacheLoader.save(
              for: url.absoluteString,
              .init(image: data, etag: etag)
            )
          }
        }
      }

      return data

    case .notModified:
      async {
        guard let imageContainer = imageContainer else { return }
        if imageContainerFromMemoryCache == nil {
          try await self.memoryCacheLoader.save(
            for: url.absoluteString,
            imageContainer
          )
        }
      }

      return imageContainer?.image

    case let .failure(error):
      throw error
    }
  }

  public func clearCache() async throws {
    try await diskCacheLoader.clear()
    try await memoryCacheLoader.clear()
  }
}
