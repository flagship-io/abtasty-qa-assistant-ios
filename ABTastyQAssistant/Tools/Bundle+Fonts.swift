import CoreText
import Foundation

extension Bundle {
    static func registerLatoFonts() {
        let names = ["Lato-Regular", "Lato-Bold", "Lato-Italic"]
        let bundle = Bundle.qaAssistant
        for name in names {
            guard let url = bundle.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
