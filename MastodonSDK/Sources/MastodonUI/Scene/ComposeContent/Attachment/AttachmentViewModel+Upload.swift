//
//  AttachmentViewModel+Upload.swift
//  
//
//  Created by MainasuK on 2021-11-26.
//

import UIKit
import UniformTypeIdentifiers
import MastodonCore
import MastodonSDK

// objc.io
// ref: https://talk.objc.io/episodes/S01E269-swift-concurrency-async-sequences-part-1
struct Chunked<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
    var base: Base
    var chunkSize: Int = 1 * 1024 * 1024      // 1 MiB
    typealias Element = Data
    
    struct AsyncIterator: AsyncIteratorProtocol {
        var base: Base.AsyncIterator
        var chunkSize: Int
        
        mutating func next() async throws -> Data? {
            var result = Data()
            while let element = try await base.next() {
                result.append(element)
                if result.count == chunkSize { return result }
            }
            return result.isEmpty ? nil : result
        }
    }
    
    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: base.makeAsyncIterator(), chunkSize: chunkSize)
    }
}

extension AsyncSequence where Element == UInt8 {
    var chunked: Chunked<Self> {
        Chunked(base: self)
    }
}

extension Data {
    fileprivate func chunks(size: Int) -> [Data] {
        return stride(from: 0, to: count, by: size).map {
            Data(self[$0..<Swift.min(count, $0 + size)])
        }
    }
}

extension AttachmentViewModel {
    public enum UploadState {
        case none
        case compressing
        case ready
        case uploading
        case fail
        case finish
    }
    
    struct UploadContext {
        let apiService: APIService
        let authenticationBox: MastodonAuthenticationBox
    }
    
    public enum UploadResult {
        case uploadedMastodonAttachment(Mastodon.Entity.Attachment)
        case exists
    }
}

extension AttachmentViewModel {
    @MainActor
    func upload(isRetry: Bool = false) async throws {
        do {
            let result = try await upload(
                context: .init(
                    apiService: APIService.shared,
                    authenticationBox: self.authenticationBox
                ),
                isRetry: isRetry
            )
            update(uploadResult: result)
        } catch {
            self.error = error
        }
    }
    
    @MainActor
    private func upload(context: UploadContext, isRetry: Bool) async throws -> UploadResult {
        if isRetry {
            guard uploadState == .fail else { throw AppError.badRequest }
            self.error = nil
            self.fractionCompleted = 0
        } else {
            guard uploadState == .ready else { throw AppError.badRequest }
        }
        do {
            update(uploadState: .uploading)
            let result = try await uploadMastodonMedia(
                context: context
            )
            update(uploadState: .finish)
            return result
        } catch {
            update(uploadState: .fail)
            throw error
        }
    }
    
    // MainActor is required here to trigger stream upload task
    @MainActor
    private func uploadMastodonMedia(
        context: UploadContext
    ) async throws -> UploadResult {
        guard let output = self.output else {
            throw AppError.badRequest
        }
        
        let attachment = output.asAttachment

        let query = Mastodon.API.Media.UploadMediaQuery(
            file: attachment,
            thumbnail: nil,
            description: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            focus: nil
        )
        
        // upload + N * check upload
        // upload : check = 9 : 1
        let uploadTaskCount: Int64 = 540
        let checkUploadTaskCount: Int64 = 1
        let checkUploadTaskRetryLimit: Int64 = 60
        
        progress.totalUnitCount = uploadTaskCount + checkUploadTaskCount * checkUploadTaskRetryLimit
        progress.completedUnitCount = 0
        
        let attachmentUploadResponse: Mastodon.Response.Content<Mastodon.Entity.Attachment> = try await {
            do {
                progress.addChild(query.progress, withPendingUnitCount: uploadTaskCount)
                return try await context.apiService.uploadMedia(
                    domain: context.authenticationBox.domain,
                    query: query,
                    mastodonAuthenticationBox: context.authenticationBox,
                    needsFallback: false
                ).singleOutput()
            } catch {
                // check needs fallback
                guard let apiError = error as? Mastodon.API.Error,
                      apiError.httpResponseStatus == .notFound
                else { throw error }
                
                progress.addChild(query.progress, withPendingUnitCount: uploadTaskCount)
                return try await context.apiService.uploadMedia(
                    domain: context.authenticationBox.domain,
                    query: query,
                    mastodonAuthenticationBox: context.authenticationBox,
                    needsFallback: true
                ).singleOutput()
            }
        }()
        
        // check needs wait processing (until get the `url`)
        if attachmentUploadResponse.statusCode == 202 {
            // note:
            // the Mastodon server append the attachments in order by upload time
            // can not upload parallels
            let waitProcessRetryLimit = checkUploadTaskRetryLimit
            var waitProcessRetryCount: Int64 = 0
            
            repeat {
                defer {
                    // make sure always count + 1
                    waitProcessRetryCount += checkUploadTaskCount
                }

                let attachmentStatusResponse = try await context.apiService.getMedia(
                    attachmentID: attachmentUploadResponse.value.id,
                    mastodonAuthenticationBox: context.authenticationBox
                ).singleOutput()
                progress.completedUnitCount += checkUploadTaskCount
                
                if attachmentStatusResponse.value.url != nil {
                    // escape here
                    progress.completedUnitCount = progress.totalUnitCount
                    return .uploadedMastodonAttachment(attachmentStatusResponse.value)
                    
                } else {
                    try await Task.sleep(nanoseconds: 1_000_000_000 * 3)     // 3s
                }
            } while waitProcessRetryCount < waitProcessRetryLimit
         
            throw AppError.badRequest
        } else {
            return .uploadedMastodonAttachment(attachmentUploadResponse.value)
        }
    }
}

extension AttachmentViewModel.Output {
    var asAttachment: Mastodon.Query.MediaAttachment {
        switch self {
        case .image(let data, let kind):
            switch kind {
            case .png:      return .png(data)
            case .jpg:      return .jpeg(data)
            }
        case .video(let url, _):
            return .other(url, fileExtension: url.pathExtension, mimeType: "video/mp4")
        }
    }
}
