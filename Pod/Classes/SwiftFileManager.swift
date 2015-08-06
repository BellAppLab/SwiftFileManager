import Foundation
import Backgroundable
import BLLogger
import Stringer


public enum FileType
{
    case ThumbnailImage, FullImage, AudioFile, VideoFile, Database, TempFile
    func folder() -> NSURL?
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
        result = result.URLByAppendingPathComponent("Filer")
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
    
    static func URLForFileType(type: FileType) -> NSURL?
    {
        return type.folder()
    }
    
    static func URLForFileType(type: FileType, andFileName name: NSString) -> NSURL?
    {
        assert(name.length > 2, "Invalid file name")
        assert(name.rangeOfString(".").location != NSNotFound, "File name should contain file extension")
        
        if var result = type.folder()?.URLByAppendingPathComponent((name as String).cleanForFileSystem()) {
            if !NSFileManager.defaultManager().fileExistsAtPath(result.path!) {
                return result
            }
            
            var components = name.componentsSeparatedByString(".") as! [String]
            components[0] = components[0] + "1"
            return URLForFileType(type, andFileName: ".".join(components))
        }
        
        return nil
    }
    
    static func save(data: NSData, withName name: NSString, type: FileType, andBlock block: FileManagerBlock)
    {
        assert(data.length > 0, "Data should not be empty")
        
        var bgTaskId = startBgTask()
        
        toBackground {
            var result = false
            if var destinationURL = self.URLForFileType(type, andFileName: name)
            {
                var error: NSError?
                result = data.writeToURL(destinationURL, options: .AtomicWrite, error: &error)
                if !result && error != nil {
                    dLog("File save error: \(error)")
                }
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    block(success: result, finalURL: destinationURL)
                })
            } else {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    block(success: result, finalURL: nil)
                })
            }
            
            endBgTask(bgTaskId)
        }
    }
    
    static func copyFile(fromURL url: NSURL, withType type: FileType, andBlock block: FileManagerBlock?)
    {
        assert(url.scheme != nil, "Origin URL should not be empty")
        
        var bgTaskId = startBgTask()
        
        var finalBlock: FileManagerBlock = { (success, finalURL) -> Void in
            if block != nil {
                toMainThread {
                    block!(success: success, finalURL: finalURL)
                }
            }
            endBgTask(bgTaskId)
        }
        
        toBackground {
            if !NSFileManager.defaultManager().fileExistsAtPath(url.path!) {
                finalBlock(success: false, finalURL: nil)
                return
            }
            
            var error: NSError?
            var data = NSData(contentsOfURL: url, options: .DataReadingUncached, error: &error)
            if data == nil {
                if error != nil {
                    dLog("File copy error: \(error)")
                }
                finalBlock(success: false, finalURL: nil)
                return
            }
            
            NSFileManager.save(data!, withName: url.lastPathComponent!, type: type, andBlock: { (success, finalURL) -> Void in
                if !success {
                    finalBlock(success: false, finalURL: nil)
                } else {
                    NSFileManager.deleteFile(url, withBlock: { (success, tempURL) -> Void in
                        finalBlock(success: success, finalURL: finalURL)
                    })
                }
            })
        }
    }
    
    static func deleteFile(atURL: NSURL, withBlock block: FileManagerBlock?)
    {
        assert(atURL.scheme != nil, "URL should not be empty")
        
        var bgTaskId = startBgTask()
        
        var finalBlock: FileManagerBlock = { (success, finalURL) -> Void in
            if block != nil {
                toMainThread {
                    block!(success: success, finalURL: finalURL)
                }
            }
            endBgTask(bgTaskId)
        }
        
        toBackground {
            if !NSFileManager.defaultManager().fileExistsAtPath(atURL.path!) {
                finalBlock(success: false, finalURL: nil)
                return
            }
            
            var error: NSError?
            var result = NSFileManager.defaultManager().removeItemAtURL(atURL, error: &error)
            if !result && error != nil {
                dLog("File deletion error: \(error)")
            }
            finalBlock(success: result, finalURL: nil)
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
    
    static func shouldExcludeFileTypeFromBackup(fileType: FileType) -> Bool
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
