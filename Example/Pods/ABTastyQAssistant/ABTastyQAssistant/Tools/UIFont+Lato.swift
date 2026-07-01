import UIKit

extension UIFont {
    static func lato(size: CGFloat) -> UIFont {
        UIFont(name: "Lato-Regular", size: size) ?? .systemFont(ofSize: size)
    }

    static func latoBold(size: CGFloat) -> UIFont {
        UIFont(name: "Lato-Bold", size: size) ?? .boldSystemFont(ofSize: size)
    }

    static func latoItalic(size: CGFloat) -> UIFont {
        UIFont(name: "Lato-Italic", size: size) ?? .italicSystemFont(ofSize: size)
    }
}
