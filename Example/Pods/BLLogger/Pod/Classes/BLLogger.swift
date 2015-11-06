import Foundation

public func dLog(@autoclosure message:  () -> String, filename: String = __FILE__, function: String = __FUNCTION__, line: Int = __LINE__) {
#if DEBUG
    NSLog("[\(NSURL(string: filename)?.lastPathComponent):\(line)] \(function) - %@", message())
#else
#endif
}
public func aLog(@autoclosure message:  () -> String, filename: String = __FILE__, function: String = __FUNCTION__, line: Int = __LINE__) {
    NSLog("[\(NSURL(string: filename)?.lastPathComponent):\(line)] \(function) - %@", message())
}