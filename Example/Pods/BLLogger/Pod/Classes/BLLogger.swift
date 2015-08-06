import Foundation

public func dLog(@autoclosure message:  () -> String, filename: String = __FILE__, function: String = __FUNCTION__, line: Int = __LINE__) {
    #if DEBUG
        NSLog("[\(filename.lastPathComponent):\(line)] \(function) - %@", message())
        #else
    #endif
}
public func aLog(message: String, filename: String = __FILE__, function: String = __FUNCTION__, line: Int = __LINE__) {
    NSLog("[\(filename.lastPathComponent):\(line)] \(function) - %@", message)
}