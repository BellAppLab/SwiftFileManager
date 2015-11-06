import Foundation
import Backgroundable
import BLLogger
import Stringer


public enum FileType
{
    case ThumbnailImage, FullImage, AudioFile, VideoFile, Database, TempFile
    public func folder() -> NSURL?
    {
        startBackgroundTask()
        
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
            
            if NSFileManager.shouldExcludeFileTypeFromBackup(self)
            {
                NSFileManager.excludeFileFromBackup(result)
            }
        }
        
        endBackgroundTask()
        
        return result
    }
}

public extension NSFileManager
{
    typealias FileManagerBlock = (success: Bool, finalURL: NSURL?) -> Void
    
    static func URLForFile(type: FileType, withBlock block: FileManagerBlock)
    {
        startBackgroundTask()
        
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
                    endBackgroundTask()
                }
                return
            }
            
            toMainThread {
                block(success: false, finalURL: nil)
                endBackgroundTask()
            }
        }
    }
    
    static func URLForFile(type: FileType, withName name: NSString, andBlock block: FileManagerBlock)
    {
        assert(name.length > 2, "Invalid file name")
        assert(name.rangeOfString(".").location != NSNotFound, "File name should contain file extension")
        
        startBackgroundTask()
        
        toBackground {
            NSFileManager.URLForFileRecursive(type, withName: name, andBlock: { (success, finalURL) -> Void in
                toMainThread {
                    block(success: success, finalURL: finalURL)
                    endBackgroundTask()
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
        
        var components = name.componentsSeparatedByString(".") 
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
        startBackgroundTask()
        
        toBackground {
            var success = true
            do {
                try data.writeToURL(toURL, options: .DataWritingAtomic)
            } catch let error as NSError {
                success = false
                dLog("File save error: \(error)")
            }
            
            toMainThread {
                withBlock(success: success, finalURL: toURL)
                endBackgroundTask()
            }
        }
    }
    
    static func moveFile(fromURL url: NSURL, toDestinationWithType type: FileType, withBlock block: FileManagerBlock)
    {
        let fileManager = NSFileManager.defaultManager()
        startBackgroundTask()
        
        let resultBlock: FileManagerBlock = { (success, finalURL) -> Void in
            toMainThread {
                block(success: success, finalURL: finalURL)
                endBackgroundTask()
            }
        }
        
        toBackground {
            if !fileManager.fileExistsAtPath(url.path!) {
                resultBlock(success: false, finalURL: nil)
                return
            }
            
            var data: NSData?
            
            do {
                data = try NSData(contentsOfURL: url, options: .DataReadingUncached)
            } catch let error as NSError {
                dLog("File copy error: \(error)")
            }
            if data != nil
            {
                NSFileManager.save(data!, withName: url.lastPathComponent!, type: type, andBlock: { (success, finalURL) -> Void in
                    if !success {
                        resultBlock(success: false, finalURL: nil)
                    } else {
                        NSFileManager.deleteFile(url, withBlock: resultBlock)
                    }
                })
            }
            else
            {
                resultBlock(success: false, finalURL: nil)
            }
        }
    }
    
    static func deleteFile(atURL: NSURL, withBlock block: FileManagerBlock?)
    {
        let fileManager = NSFileManager.defaultManager()
        startBackgroundTask()
        
        let resultBlock: FileManagerBlock = { (success, finalURL) -> Void in
            if let finalBlock = block {
                toMainThread {
                    finalBlock(success: success, finalURL: finalURL)
                }
            }
            endBackgroundTask()
        }
        
        toBackground {
            if !fileManager.fileExistsAtPath(atURL.path!) {
                resultBlock(success: false, finalURL: nil)
                return
            }
            
            var result = true
            
            do {
                try fileManager.removeItemAtURL(atURL)
            } catch let error as NSError {
                result = false
                dLog("File deletion error: \(error)")
            }
            
            resultBlock(success: result, finalURL: nil)
        }
    }
    
    static func deleteAllFiles(type: FileType, andBlock block: FileManagerBlock?)
    {
        if let url = type.folder() {
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
