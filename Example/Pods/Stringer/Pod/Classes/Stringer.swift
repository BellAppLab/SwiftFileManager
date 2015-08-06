import Foundation


public extension String
{
    //MARK: Cleaning Text
    func cleanWhiteSpacesAndNewLineCharacters() -> String {
        if !self.isEmpty {
            return "".join(self.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()))
        }
        return self
    }
    
    func cleanLetters() -> String {
        if !self.isEmpty {
            return "".join(self.componentsSeparatedByCharactersInSet(NSCharacterSet.letterCharacterSet()))
        }
        return self
    }
    
    func cleanPunctuation() -> String {
        if !self.isEmpty {
            return "".join(self.componentsSeparatedByCharactersInSet(NSCharacterSet.punctuationCharacterSet()))
        }
        return self
    }
    
    func cleanSymbols() -> String {
        if !self.isEmpty {
            return "".join(self.componentsSeparatedByCharactersInSet(NSCharacterSet.symbolCharacterSet()))
        }
        return self
    }
    
    func cleanNumbers() -> String {
        if !self.isEmpty {
            return "".join(self.componentsSeparatedByCharactersInSet(NSCharacterSet.decimalDigitCharacterSet()))
        }
        return self
    }
    
    func cleanForFileSystem() -> String {
        if !self.isEmpty {
            var result = self.cleanWhiteSpacesAndNewLineCharacters().cleanSymbols()
            if (result as NSString).rangeOfString(".").location != NSNotFound {
                var components = NSMutableArray(array: result.componentsSeparatedByString("."))
                var type = components.lastObject as! String
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
        var string = "".join(self.componentsSeparatedByCharactersInSet(NSCharacterSet.punctuationCharacterSet()))
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
        var cleanSelf = self.clean(type)
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
            return !"".join(cleanSelf.componentsSeparatedByCharactersInSet(NSCharacterSet.URLPasswordAllowedCharacterSet())).isEmpty
        case .PhoneNumber, .PostalCode, .State:
            return localizedValidation(type, cleanString: cleanSelf)
        }
    }
    
    private func localizedValidation(type: ValidationType, cleanString: String) -> Bool
    {
        if localeComponents[NSLocaleCountryCode] as! String == "BR" {
            switch type
            {
            case .PhoneNumber:
                return count(cleanString) >= 10 && count(cleanString) <= 12
            case .PostalCode:
                return count(cleanString) == 8
            case .State:
                return count(cleanString) == 2
            default:
                return true
            }
        }
        return true
    }
}
