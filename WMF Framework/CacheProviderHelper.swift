
import Foundation

public extension HTTPURLResponse {
    static let etagHeaderKey = "Etag"
    static let ifNoneMatchHeaderKey = "If-None-Match"
}

final class CacheProviderHelper {
    
    static func persistedCacheResponse(url: URL, itemKey: String, variant: String?, cacheKeyGenerator: CacheKeyGenerating.Type) -> CachedURLResponse? {
        
        let responseFileName = cacheKeyGenerator.uniqueFileNameForItemKey(itemKey, variant: variant)
        let responseHeaderFileName = cacheKeyGenerator.uniqueHeaderFileNameForItemKey(itemKey, variant: variant)
        
        guard let responseData = FileManager.default.contents(atPath: CacheFileWriterHelper.fileURL(for: responseFileName).path) else {
            return nil
        }
        
        //missing response header file could happen as a result of migrating saved articles for mobile-html response and images.
        //artifically returning a header here in this case, though maybe better would be to create a response header file during migration.
        guard let responseHeaderData = FileManager.default.contents(atPath: CacheFileWriterHelper.fileURL(for: responseHeaderFileName).path) else {
            
            var mimeType = FileManager.default.getValueForExtendedFileAttributeNamed(WMFExtendedFileAttributeNameMIMEType, forFileAtPath: responseFileName) ?? (url as NSURL).wmf_mimeTypeForExtension()
            if url.absoluteString.contains("mobile-html") {
                mimeType = "text/html"
            }
            let headerFields = mimeType.isEmpty ? [:] : ["Content-Type": mimeType]
            
            if let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headerFields) {
                return CachedURLResponse(response: httpResponse, data: responseData)
            }
            
            return nil
        }
    
        var responseHeaders: [String: String]?
        do {
            if let unarchivedHeaders = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(responseHeaderData) as? [String: String] {
                responseHeaders = unarchivedHeaders
            }
        } catch {
            
        }
        
        if let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: responseHeaders) {
            return CachedURLResponse(response: httpResponse, data: responseData)
        }
        
        return nil
    }
    
    static func fallbackCacheResponse(url: URL, itemKey: String, variant: String?, itemType: Session.Header.ItemType, cacheKeyGenerator: CacheKeyGenerating.Type, moc: NSManagedObjectContext) -> CachedURLResponse? {
        
        //lookup fallback itemKey/variant in DB (language fallback logic for article item type, size fallback logic for image item type)
        
        var allVariantItems = CacheDBWriterHelper.allDownloadedVariantItems(itemKey: itemKey, in: moc)
        
        switch itemType {
        case .image:
            allVariantItems.sort { (lhs, rhs) -> Bool in

                guard let lhsVariant = lhs.variant,
                    let lhsSize = Int64(lhsVariant),
                    let rhsVariant = rhs.variant,
                    let rhsSize = Int64(rhsVariant) else {
                        return true
                }

                return lhsSize < rhsSize
            }
        case .article, .imageInfo:
            //allVariantItems.sort { (lhs, rhs) -> Bool in

                //tonitodo: sort based on NSLocale language preferences?
            //}
            break
        }
        
        if let fallbackItemKey = allVariantItems.first?.key,
            let fallbackVariant = allVariantItems.first?.variant,
            let fallbackURL = allVariantItems.first?.url {
            
            //first see if URLCache has the fallback
            let request = URLRequest(url: fallbackURL)
            if let response = URLCache.shared.cachedResponse(for: request) {
                return response
            }
            
            //then see if persistent cache has the fallback
            return persistedCacheResponse(url: url, itemKey: fallbackItemKey, variant: fallbackVariant, cacheKeyGenerator: cacheKeyGenerator)
        }
        
        return nil
    }
}
