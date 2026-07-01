import UIKit

/// A UIImageView that loads its image from the ABTastyQAssistant resource bundle.
/// Use this class in XIBs instead of plain UIImageView, then set `bundleImageName`
/// via the Identity Inspector (IBInspectable) or in code.
@IBDesignable
class BundleImageView: UIImageView {

    @IBInspectable var bundleImageName: String = "" {
        didSet {
            guard !bundleImageName.isEmpty else { return }
            image = UIImage(named: bundleImageName, in: .qaAssistant, compatibleWith: nil)
        }
    }
}

// MARK: - Bundle helper

extension Bundle {
    /// Resolves the ABTastyQAssistant resource bundle at runtime.
    /// - In local pod dev (`pod lib lint` / Example app): falls back to the framework bundle.
    /// - In production (integrated pod): loads the named `.bundle` inside the framework.
    static var qaAssistant: Bundle {
        let frameworkBundle = Bundle(for: BundleImageView.self)
        guard
            let url = frameworkBundle.url(forResource: "ABTastyQAssistant", withExtension: "bundle"),
            let bundle = Bundle(url: url)
        else {
            return frameworkBundle
        }
        // Le bundle doit être chargé explicitement pour que UINib puisse y trouver les NIBs
        if !bundle.isLoaded { bundle.load() }
        return bundle
    }
}
