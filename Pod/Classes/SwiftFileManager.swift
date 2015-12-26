import Foundation
import Backgroundable
import BLLogger
import Stringer


public enum FileType
{
    case ThumbnailImage, FullImage, AudioFile, VideoFile, Database, TempFile
    public func folder() -> NSURL?
    {
        //Base URL
        var result: NSURL
        switch self
        {
        case .ThumbnailImage, .FullImage, .AudioFile, .VideoFile:
            result = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask).last!
            break
        case .Database:
            result = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).last!
            break
        case .TempFile:
            result = NSURL.fileURLWithPath(NSTemporaryDirectory())
            break
        }
        
        //Custom URL
        result = result.URLByAppendingPathComponent("SwiftFileManager")
        switch self
        {
        case .ThumbnailImage:
            result = result.URLByAppendingPathComponent("Thumbs")
            break
        case .FullImage:
            result = result.URLByAppendingPathComponent("Images")
            break
        case .AudioFile:
            result = result.URLByAppendingPathComponent("Audio")
            break
        case .VideoFile:
            result = result.URLByAppendingPathComponent("Video")
            break
        case .Database:
            result = result.URLByAppendingPathComponent("Database")
            break
        default:
            break
        }
        
        //Creating folder if needed
        if !NSFileManager.defaultManager().fileExistsAtPath(result.path!)
        {
            do {
                try NSFileManager.defaultManager().createDirectoryAtURL(result, withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                dLog("File error: \(error)")
                return nil
            }
            
            if self.shouldExcludeFileTypeFromBackup()
            {
                NSFileManager.excludeFileFromBackup(result)
            }
        }
        
        return result.filePathURL
    }
    
    private func shouldExcludeFileTypeFromBackup() -> Bool
    {
        switch self
        {
        case .ThumbnailImage, .FullImage, .AudioFile, .VideoFile, .TempFile:
            return true
        case .Database:
            return false
        }
    }
}

public protocol Filer
{
    func fileType() -> FileType
    func fileExtension() -> String
}

public extension NSFileManager
{
    public typealias Block = (url: NSURL?) -> Void
    
    public static func uniqueURL(filer: Filer, _ block: Block)
    {
        startBackgroundTask()
        
        toBackground {
            if let result = filer.fileType().folder() {
                func uniqueId() -> String {
                    return "\(NSUUID().UUIDString)\(String.dot)\(filer.fileExtension())"
                }
                
                let fileManager = NSFileManager.defaultManager()
                var tempId = uniqueId()
                
                while fileManager.fileExistsAtPath(result.URLByAppendingPathComponent(tempId).path!)
                {
                    tempId = uniqueId()
                }
                
                toMainThread {
                    block(url: result.URLByAppendingPathComponent(tempId))
                    endBackgroundTask()
                }
                return
            }
            
            toMainThread {
                block(url: nil)
                endBackgroundTask()
            }
        }
    }
    
    public static func makeURL(filer: Filer, fileName: String, _ block: Block)
    {
        self.URL(filer, fileName, false, block)
    }
    
    public static func getURL(filer: Filer, fileName: String, _ block: Block)
    {
        self.URL(filer, fileName, true, block)
    }
    
    private static func URL(filer: Filer, _ fileName: String, _ shouldExist: Bool, _ block: Block)
    {
        assert(fileName.characters.count > 2, "Invalid file name")
        
        startBackgroundTask()
        
        func end(url: NSURL?) {
            toMainThread {
                block(url: url)
                endBackgroundTask()
            }
        }
        
        toBackground {
            let fullFileName = "\(fileName)\(String.dot)\(filer.fileExtension())"
            if let url = filer.fileType().folder()?.URLByAppendingPathComponent(fullFileName) {
                if shouldExist {
                    let fileManager = NSFileManager.defaultManager()
                    if fileManager.fileExistsAtPath(url.path!) {
                        end(url)
                        return
                    }
                }
                end(url)
            }
        }
    }
    
    public static func save(data: NSData, forFiler filer: Filer, _ block: Block)
    {
        if data.length == 0 {
            dLog("Trying to save empty data as a file")
            block(url: nil)
            return
        }
        
        startBackgroundTask()
        
        func end(url: NSURL?) {
            toMainThread {
                block(url: url)
                endBackgroundTask()
            }
        }
        
        NSFileManager.uniqueURL(filer) { (url) -> Void in
            if let finalURL = url {
                NSFileManager.save(data, toURL: finalURL, { (url) -> Void in
                    end(url)
                })
                return
            }
            end(nil)
        }
    }
    
    public static func save(data: NSData, forFiler filer: Filer, withFileName fileName: String, overwrite: Bool, _ block: Block)
    {
        if data.length == 0 {
            dLog("Trying to save empty data as a file")
            block(url: nil)
            return
        }
        
        startBackgroundTask()
        
        func end(url: NSURL?) {
            toMainThread {
                block(url: url)
                endBackgroundTask()
            }
        }
        
        func proceed(finalURL: NSURL) {
            let fileManager = NSFileManager.defaultManager()
            if fileManager.fileExistsAtPath(finalURL.path!) {
                if !overwrite {
                    end(nil)
                    return
                }
                NSFileManager.deleteFile(finalURL, { (url) -> Void in
                    NSFileManager.save(data, toURL: finalURL, { (url) -> Void in
                        end(url)
                    })
                })
                return
            }
            NSFileManager.save(data, toURL: finalURL) { (url) -> Void in
                end(url)
            }
        }
        
        NSFileManager.makeURL(filer, fileName: fileName) { (url) -> Void in
            if let finalURL = url {
                toBackground {
                    proceed(finalURL)
                }
                return
            }
            end(nil)
        }
    }
    
    private static func save(data: NSData, toURL: NSURL, _ block: Block)
    {
        toBackground {
            do {
                try data.writeToURL(toURL, options: .DataWritingAtomic)
                block(url: toURL)
            } catch let error as NSError {
                dLog("File save error: \(error)")
                block(url: nil)
            }
        }
    }
    
    public static func moveFile(fromURL: NSURL, toDestinationWithFileType fileType: FileType, _ block: Block)
    {
        startBackgroundTask()
        
        func end(url: NSURL?) {
            toMainThread {
                block(url: url)
                endBackgroundTask()
            }
        }
        
        toBackground {
            if !NSFileManager.defaultManager().fileExistsAtPath(fromURL.path!) {
                end(nil)
                return
            }
            
            func delete(finalURL: NSURL) {
                NSFileManager.deleteFile(fromURL, { (url) -> Void in
                    end(finalURL)
                })
            }
            
            func save(data: NSData) {
                toBackground {
                    if let folder = fileType.folder() {
                        NSFileManager.save(data, toURL: folder.URLByAppendingPathComponent(fromURL.lastPathComponent!), { (url) -> Void in
                            if let finalURL = url {
                                delete(finalURL)
                                return
                            }
                            end(nil)
                        })
                        return
                    }
                    end(nil)
                }
            }
            
            do {
                let data = try NSData(contentsOfURL: fromURL, options: .DataReadingUncached)
                save(data)
            } catch let error as NSError {
                dLog("File copy error: \(error)")
                end(nil)
            }
        }
    }
    
    public static func deleteFile(atURL: NSURL, _ block: Block?)
    {
        let fileManager = NSFileManager.defaultManager()
        startBackgroundTask()
        
        func end(url: NSURL?) {
            if let finalBlock = block {
                toMainThread {
                    finalBlock(url: url)
                }
            }
            endBackgroundTask()
        }
        
        toBackground {
            if !fileManager.fileExistsAtPath(atURL.path!) {
                end(nil)
                return
            }
            
            do {
                try fileManager.removeItemAtURL(atURL)
                end(atURL)
            } catch let error as NSError {
                dLog("File deletion error: \(error)")
                end(nil)
            }
        }
    }
    
    public static func deleteAllFiles(type: FileType, _ block: Block?)
    {
        if let url = type.folder() {
            self.deleteFile(url, block)
        } else {
            if block != nil {
                toMainThread {
                    block!(url: nil)
                }
            }
        }
    }
    
    public static func deleteTempFiles(block: Block?)
    {
        self.deleteAllFiles(.TempFile, block)
    }
    
    private static func excludeFileFromBackup(url: NSURL) -> Bool
    {
        var error: NSError?
        var result: Bool
        do {
            try url.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)
            result = true
        } catch let error1 as NSError {
            error = error1
            result = false
        }
        if !result && error != nil {
            dLog("File error: \(error)")
        }
        return result
    }
}
