//
//  ProductImageRepository.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import Foundation

actor ProductImageRepository {
    private let dataStore: DataStore
    private let fileManager = FileManager.default
    private let session: URLSession

    init(dataStore: DataStore) {
        self.dataStore = dataStore

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 4
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: configuration)
    }

    func loadImageData(for key: String, remoteURL: URL?) async -> Data? {
        if let data = try? await cachedData(for: key) {
            return data
        }

        guard let remoteURL else {
            return nil
        }

        do {
            let (data, _) = try await session.data(from: remoteURL)
            try await persist(data: data, for: key)
            return data
        } catch {
            return nil
        }
    }

    func recentCachedProducts(limit: Int) async -> [AnalyzedProduct] {
        (try? await dataStore.recentCachedProducts(limit: limit)) ?? []
    }

    private func cachedData(for key: String) async throws -> Data? {
        if let relativePath = try await dataStore.cachedImageRelativePath(for: key) {
            let url = cacheDirectory().appending(path: relativePath)
            return try Data(contentsOf: url)
        }

        let fallbackURL = cacheDirectory().appending(path: "\(key).img")
        if fileManager.fileExists(atPath: fallbackURL.path()) {
            return try Data(contentsOf: fallbackURL)
        }

        return nil
    }

    private func persist(data: Data, for key: String) async throws {
        let directory = cacheDirectory()
        if !fileManager.fileExists(atPath: directory.path()) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let relativePath = "\(key).img"
        let url = directory.appending(path: relativePath)
        try data.write(to: url, options: .atomic)

        try await dataStore.registerCachedImage(key: key, relativePath: relativePath)
    }

    private func cacheDirectory() -> URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "ProductImages", directoryHint: .isDirectory)
    }
}
