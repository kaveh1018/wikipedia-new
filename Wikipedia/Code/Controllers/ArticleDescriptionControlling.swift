
import Foundation

struct ArticleDescriptionWarningTypes: OptionSet {
    let rawValue: Int

    static let length = ArticleDescriptionWarningTypes(rawValue: 1 << 0)
    static let casing = ArticleDescriptionWarningTypes(rawValue: 1 << 1)
}

struct ArticleDescriptionPublishResult {
    let newRevisionID: UInt64?
    let newDescription: String
}

protocol ArticleDescriptionControlling {
    var descriptionSource: ArticleDescriptionSource { get }
    var article: WMFArticle { get }
    var articleLanguage: String { get }
    func publishDescription(_ description: String, completion: @escaping (Result<ArticleDescriptionPublishResult, Error>) -> Void)
    func currentDescription(completion: @escaping (String?) -> Void)
    func errorTextFromError(_ error: Error) -> String
    func learnMoreViewControllerWithTheme(_ theme: Theme) -> UIViewController?
    func warningTypesForDescription(_ description: String?) -> ArticleDescriptionWarningTypes
}

extension ArticleDescriptionControlling {
    var articleDisplayTitle: String? { return article.displayTitle }
    var descriptionMaxLength: Int { return 90 }
    
    func descriptionIsTooLong(_ description: String?) -> Bool {
        let isDescriptionLong = (description?.count ?? 0) > descriptionMaxLength
        return isDescriptionLong
    }
    
    func descriptionIsUppercase(_ description: String?) -> Bool {
        if let firstCharacter = description?.first,
              firstCharacter.isLetter,
              firstCharacter.isUppercase {
            return true
        }
        
        return false
    }
}
