import Foundation


//MARK: - String manipulation
public extension String
{
    //MARK: Cleaning Text
    func cleanWhiteSpacesAndNewLineCharacters() -> String {
        if !self.isEmpty {
            return self.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).joinWithSeparator("")
        }
        return self
    }
    
    func cleanLetters() -> String {
        if !self.isEmpty {
            return self.componentsSeparatedByCharactersInSet(NSCharacterSet.letterCharacterSet()).joinWithSeparator("")
        }
        return self
    }
    
    func cleanPunctuation() -> String {
        if !self.isEmpty {
            return self.componentsSeparatedByCharactersInSet(NSCharacterSet.punctuationCharacterSet()).joinWithSeparator("")
        }
        return self
    }
    
    func cleanSymbols() -> String {
        if !self.isEmpty {
            return self.componentsSeparatedByCharactersInSet(NSCharacterSet.symbolCharacterSet()).joinWithSeparator("")
        }
        return self
    }
    
    func cleanNumbers() -> String {
        if !self.isEmpty {
            return self.componentsSeparatedByCharactersInSet(NSCharacterSet.decimalDigitCharacterSet()).joinWithSeparator("")
        }
        return self
    }
    
    func cleanForFileSystem() -> String {
        if !self.isEmpty {
            var result = self.cleanWhiteSpacesAndNewLineCharacters().cleanSymbols()
            if (result as NSString).rangeOfString(".").location != NSNotFound {
                let components = NSMutableArray(array: result.componentsSeparatedByString("."))
                let type = components.lastObject as! String
                components.removeLastObject()
                result = components.componentsJoinedByString("")
                result = result.cleanPunctuation()
                return NSString(format: "%@.%@", result, type.cleanPunctuation()) as String
            }
        }
        return self
    }
    
    func trim() -> String {
        if !self.isEmpty {
            return self.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        }
        return self
    }
    
    
    //MARK: General Checks
    var isLetter: Bool {
        return (self.componentsSeparatedByCharactersInSet(NSCharacterSet.letterCharacterSet()).count == 0)
    }
    
    var isNumber: Bool {
        let string = self.componentsSeparatedByCharactersInSet(NSCharacterSet.punctuationCharacterSet()).joinWithSeparator("")
        if !string.isEmpty {
            return (self.componentsSeparatedByCharactersInSet(NSCharacterSet.decimalDigitCharacterSet()).count == 0)
        }
        return false
    }
    
    var isSpaceCharacter: Bool {
        return (self.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet()).count == 0)
    }
    
    var isNewLineCharacter: Bool {
        return (self.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet()).count == 0)
    }
}


//MARK: - Locales

private let localeComponents = NSLocale.componentsFromLocaleIdentifier(NSLocale.currentLocale().localeIdentifier)


//MARK: - Validation

public enum ValidationType
{
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
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "", name: "", object: nil)
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
