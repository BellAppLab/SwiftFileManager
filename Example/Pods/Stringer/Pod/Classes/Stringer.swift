import UIKit

//MARK: - Internals
private extension NSCharacterSet
{
    @nonobjc private static let whitespaceAndNewline = NSCharacterSet.whitespaceAndNewlineCharacterSet()
    @nonobjc private static let whitespace = NSCharacterSet.whitespaceCharacterSet()
    @nonobjc private static let newline = NSCharacterSet.newlineCharacterSet()
    @nonobjc private static let letter = NSCharacterSet.letterCharacterSet()
    @nonobjc private static let punctuation = NSCharacterSet.punctuationCharacterSet()
    @nonobjc private static let symbol = NSCharacterSet.symbolCharacterSet()
    @nonobjc private static let decimalDigit = NSCharacterSet.decimalDigitCharacterSet()
}

//MARK: - String manipulation
public extension String
{
    //MARK: Consts
    public static let dot = "."
    public static let space = " "
    public static let comma = ","
    public static let semicolon = ";"
    public static let colon = ":"
    public static let empty = ""
    
    //MARK: Cleaning Text
    func cleanWhiteSpacesAndNewLineCharacters() -> String {
        if !self.isEmpty {
            return self.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewline).joinWithSeparator(String.empty)
        }
        return self
    }
    
    func cleanLetters() -> String {
        if !self.isEmpty {
            return self.componentsSeparatedByCharactersInSet(NSCharacterSet.letter).joinWithSeparator(String.empty)
        }
        return self
    }
    
    func cleanPunctuation() -> String {
        if !self.isEmpty {
            return self.componentsSeparatedByCharactersInSet(NSCharacterSet.punctuation).joinWithSeparator(String.empty)
        }
        return self
    }
    
    func cleanSymbols() -> String {
        if !self.isEmpty {
            return self.componentsSeparatedByCharactersInSet(NSCharacterSet.symbol).joinWithSeparator(String.empty)
        }
        return self
    }
    
    func cleanNumbers() -> String {
        if !self.isEmpty {
            return self.componentsSeparatedByCharactersInSet(NSCharacterSet.decimalDigit).joinWithSeparator(String.empty)
        }
        return self
    }
    
    func cleanForFileSystem() -> String {
        if !self.isEmpty {
            var result = self.cleanWhiteSpacesAndNewLineCharacters()
            if let _ = result.rangeOfString(String.dot) {
                var components = result.componentsSeparatedByString(String.dot)
                let type = components.removeLast()
                result = components.joinWithSeparator(String.empty)
                result = result.cleanSymbols().cleanPunctuation()
                return "\(result)\(String.dot)\(type)"
            }
        }
        return self
    }
    
    func trim() -> String {
        if !self.isEmpty {
            return self.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewline)
        }
        return self
    }
    
    
    //MARK: General Checks
    var isLetter: Bool {
        return (self.componentsSeparatedByCharactersInSet(NSCharacterSet.letter).count == 0)
    }
    
    var isNumber: Bool {
        let string = self.componentsSeparatedByCharactersInSet(NSCharacterSet.punctuation).joinWithSeparator(String.empty)
        if !string.isEmpty {
            return (self.componentsSeparatedByCharactersInSet(NSCharacterSet.decimalDigit).count == 0)
        }
        return false
    }
    
    var isSpaceCharacter: Bool {
        return (self.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespace).count == 0)
    }
    
    var isNewLineCharacter: Bool {
        return (self.componentsSeparatedByCharactersInSet(NSCharacterSet.newline).count == 0)
    }
}


//MARK: - Locales

private let localeComponents = NSLocale.componentsFromLocaleIdentifier(NSLocale.currentLocale().localeIdentifier)


//MARK: - Validation

public enum ValidationType
{
    case File
    case Name
    case Email
    case Password
    case PhoneNumber
    case PostalCode
    case City
    case State
}

public protocol Validatable
{
    func clean(type: ValidationType) -> String
    func isValid(type: ValidationType) -> Bool
}

extension String: Validatable
{
    public func clean(type: ValidationType) -> String
    {
        switch type
        {
        case .Name, .City:
            return self.cleanWhiteSpacesAndNewLineCharacters().cleanPunctuation().cleanSymbols().cleanNumbers()
        case .Email, .Password:
            return self.trim()
        case .PhoneNumber:
            return self.cleanWhiteSpacesAndNewLineCharacters().cleanPunctuation().cleanSymbols().cleanLetters()
        case .PostalCode:
            return self.cleanPunctuation().cleanSymbols()
        case .State:
            return self.cleanWhiteSpacesAndNewLineCharacters().cleanPunctuation().cleanSymbols().cleanNumbers().uppercaseString
        case .File:
            return self.cleanForFileSystem()
        }
    }
    
    public func isValid(type: ValidationType) -> Bool
    {
        let cleanSelf = self.clean(type)
        if cleanSelf.isEmpty {
            return false
        }
        
        switch type
        {
        case .Name, .City:
            return true
        case .Email:
            return NSPredicate(format: "SELF MATCHES %@","[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?").evaluateWithObject(cleanSelf)
        case .Password:
            return !cleanSelf.componentsSeparatedByCharactersInSet(NSCharacterSet.URLPasswordAllowedCharacterSet()).joinWithSeparator("").isEmpty
        case .PhoneNumber, .PostalCode, .State:
            return localizedValidation(type, cleanString: cleanSelf)
        case .File:
            return self == self.cleanForFileSystem()
        }
    }
    
    private func localizedValidation(type: ValidationType, cleanString: String) -> Bool
    {
        if localeComponents[NSLocaleCountryCode] == "BR" {
            switch type
            {
            case .PhoneNumber:
                return cleanString.characters.count >= 10 && cleanString.characters.count <= 12
            case .PostalCode:
                return cleanString.characters.count == 8
            case .State:
                return cleanString.characters.count == 2
            default:
                return true
            }
        }
        return true
    }
}


//MARK: - Custom Font UI Kit

public protocol CustomFont
{
    var fontName: String { get set }
}

extension UILabel: CustomFont
{
    @IBInspectable public var fontName: String {
        get {
            return self.font.fontName
        }
        set {
            self.font = UIFont(name: newValue, size: self.font.pointSize)
        }
    }
}

extension UIButton: CustomFont
{
    @IBInspectable public var fontName: String {
        get {
            if let result = self.titleLabel?.fontName {
                return result
            }
            return ""
        }
        set {
            if let label = self.titleLabel {
                label.font = UIFont(name: newValue, size: label.font.pointSize)
            }
        }
    }
}

extension UITextField: CustomFont
{
    @IBInspectable public var fontName: String {
        get {
            return self.font!.fontName
        }
        set {
            self.font = UIFont(name: newValue, size: self.font!.pointSize)
        }
    }
}

extension UITextView: CustomFont
{
    @IBInspectable public var fontName: String {
        get {
            return self.font!.fontName
        }
        set {
            self.font = UIFont(name: newValue, size: self.font!.pointSize)
        }
    }
}
