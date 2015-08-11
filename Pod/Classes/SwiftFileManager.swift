import Foundation
import Backgroundable
import BLLogger
import Stringer


public enum FileType
{
    case ThumbnailImage, FullImage, AudioFile, VideoFile, Database, TempFile
    public func folder() -> NSURL?
    {
        var bgTaskId = startBgTask()
        
        //Base URL
        var result: NSURL
        switch self
        {
        case .ThumbnailImage, .FullImage, .AudioFile, .VideoFile:
            result = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask).last as! NSURL
            break
        case .Database:
            result = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).last as! NSURL
            break
        case .TempFile:
            result = NSURL.fileURLWithPath(NSTemporaryDirectory())!
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
            var error: NSError?
            if !NSFileManager.defaultManager().createDirectoryAtURL(result, withIntermediateDirectories: true, attributes: nil, error: &error)
            {
                if var finalError = error {
                    dLog("File error: \(error)")
                }
                return nil
            }
            
            if NSFileManager.shouldExcludeFileTypeFromBackup(self)
            {
                NSFileManager.excludeFileFromBackup(result)
            }
        }
        
        endBgTask(bgTaskId)
        
        return result
    }
}

public extension NSFileManager
{
    typealias FileManagerBlock = (success: Bool, finalURL: NSURL?) -> Void
    
    static func URLForFile(type: FileType, withBlock block: FileManagerBlock)
    {
        let fileManager = NSFileManager.defaultManager()
        fileManager.startBackgroundTask()
        
        toBackground {
            if let result = type.folder() {
                var uniqueId = NSUUID().UUIDString
                let fileManager = NSFileManager.defaultManager()
                
                while fileManager.fileExistsAtPath(result.URLByAppendingPathComponent(uniqueId).path!)
                {
                    uniqueId = NSUUID().UUIDString
                }
                
                toMainThread {
                    block(success: true, finalURL: result.URLByAppendingPathComponent(uniqueId))
                    fileManager.endBackgroundTask()
                }
                return
            }
            
            toMainThread {
                block(success: false, finalURL: nil)
                fileManager.endBackgroundTask()
            }
        }
    }
    
    static func URLForFile(type: FileType, withName name: NSString, andBlock block: FileManagerBlock)
    {
        assert(name.length > 2, "Invalid file name")
        assert(name.rangeOfString(".").location != NSNotFound, "File name should contain file extension")
        
        let fileManager = NSFileManager.defaultManager()
        fileManager.startBackgroundTask()
        
        toBackground {
            NSFileManager.URLForFileRecursive(type, withName: name, andBlock: { (success, finalURL) -> Void in
                toMainThread {
                    block(success: success, finalURL: finalURL)
                    fileManager.endBackgroundTask()
                }
            })
        }
    }
    
    private static func URLForFileRecursive(type: FileType, withName name: NSString, andBlock block: FileManagerBlock)
    {
        if let result = type.folder()?.URLByAppendingPathComponent((name as String).cleanForFileSystem()) {
            if !NSFileManager.defaultManager().fileExistsAtPath(result.path!) {
                block(success: true, finalURL: result)
                return
            }
        }
        
        var components = name.componentsSeparatedByString(".") as! [String]
        components[0] = components[0] + "1"
        NSFileManager.URLForFileRecursive(type, withName: name, andBlock: block)
    }
    
    static func save(data: NSData, type: FileType, andBlock block: FileManagerBlock)
    {
        assert(data.length > 0, "Data should not be empty")
        
        NSFileManager.URLForFile(type, withBlock: { (success, finalURL) -> Void in
            if !success {
                block(success: false, finalURL: nil)
            } else {
                NSFileManager.save(data, toURL: finalURL!, withBlock: block)
            }
        })
    }
    
    static func save(data: NSData, withName name: NSString, type: FileType, andBlock block: FileManagerBlock)
    {
        assert(data.length > 0, "Data should not be empty")
        
        NSFileManager.URLForFile(type, withName: name) { (success, finalURL) -> Void in
            if !success {
                block(success: false, finalURL: nil)
            } else {
                NSFileManager.save(data, toURL: finalURL!, withBlock: block)
            }
        }
    }
    
    private static func save(data: NSData, toURL: NSURL, withBlock: FileManagerBlock)
    {
        var fileManager = NSFileManager.defaultManager()
        fileManager.startBackgroundTask()
        
        toBackground {
            var error: NSError?
            var result = data.writeToURL(toURL, options: .AtomicWrite, error: &error)
            if !result && error != nil {
                dLog("File save error: \(error)")
            }
            toMainThread {
                withBlock(success: result, finalURL: toURL)
                fileManager.endBackgroundTask()
            }
        }
    }
    
    static func moveFile(fromURL url: NSURL, toDestinationWithType type: FileType, withBlock block: FileManagerBlock)
    {
        assert(url.scheme != nil, "Origin URL should not be empty")
        
        let fileManager = NSFileManager.defaultManager()
        fileManager.startBackgroundTask()
        
        var resultBlock: FileManagerBlock = { (success, finalURL) -> Void in
            toMainThread {
                block(success: success, finalURL: finalURL)
                fileManager.endBackgroundTask()
            }
        }
        
        toBackground {
            if !fileManager.fileExistsAtPath(url.path!) {
                resultBlock(success: false, finalURL: nil)
                return
            }
            
            var error: NSError?
            if var data = NSData(contentsOfURL: url, options: .DataReadingUncached, error: &error)
            {
                NSFileManager.save(data, withName: url.lastPathComponent!, type: type, andBlock: { (success, finalURL) -> Void in
                    if !success {
                        resultBlock(success: false, finalURL: nil)
                    } else {
                        NSFileManager.deleteFile(url, withBlock: resultBlock)
                    }
                })
            }
            else
            {
                if error != nil {
                    dLog("File copy error: \(error)")
                }
                resultBlock(success: false, finalURL: nil)
            }
        }
    }
    
    static func deleteFile(atURL: NSURL, withBlock block: FileManagerBlock?)
    {
        assert(atURL.scheme != nil, "URL should not be empty")
        
        let fileManager = NSFileManager.defaultManager()
        fileManager.startBackgroundTask()
        
        let resultBlock: FileManagerBlock = { (success, finalURL) -> Void in
            if var finalBlock = block {
                toMainThread {
                    finalBlock(success: success, finalURL: finalURL)
                }
            }
            fileManager.endBackgroundTask()
        }
        
        toBackground {
            if !NSFileManager.defaultManager().fileExistsAtPath(atURL.path!) {
                resultBlock(success: false, finalURL: nil)
                return
            }
            
            var error: NSError?
            var result = NSFileManager.defaultManager().removeItemAtURL(atURL, error: &error)
            if !result && error != nil {
                dLog("File deletion error: \(error)")
            }
            resultBlock(success: result, finalURL: nil)
        }
    }
    
    static func deleteAllFiles(type: FileType, andBlock block: FileManagerBlock?)
    {
        if var url = type.folder() {
            self.deleteFile(url, withBlock: block)
        } else {
            if block != nil {
                toMainThread {
                    block!(success: false, finalURL: nil)
                }
            }
        }
    }
    
    static func deleteTempFiles(block: FileManagerBlock?)
    {
        self.deleteAllFiles(.TempFile, andBlock: block)
    }
    
    private static func shouldExcludeFileTypeFromBackup(fileType: FileType) -> Bool
    {
        switch fileType
        {
        case .ThumbnailImage, .FullImage, .AudioFile, .VideoFile, .TempFile:
            return true
        case .Database:
            return false
        }
    }
    
    static func excludeFileFromBackup(url: NSURL) -> Bool
    {
        var error: NSError?
        var result = url.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey, error: &error)
        if !result && error != nil {
            dLog("File error: \(error)")
        }
        return result
    }
}
