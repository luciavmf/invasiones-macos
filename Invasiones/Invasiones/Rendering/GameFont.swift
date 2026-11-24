//
//  GameFont.swift
//  Invasiones
//
//  Created by Lucia Medina Fretes on 06.04.26.
//
//  Port of Fuente.cs — wrapper over SDL_ttf for TrueType fonts.
//  On macOS we use NSFont; custom TTF fonts are registered with CTFontManager.
//

import AppKit
import CoreText

final class GameFont {

    // MARK: - Declarations
    private(set) var nsFont: NSFont?
    private(set) var name: String
    private(set) var size: Int

    // MARK: - Initializer
    /// Creates a font from one of the font files in res.json and a point size.
    init(family: FontFamily, size: Int) {
        self.size = size

        let paths = ResourceManager.shared.fontPaths
        guard let path = paths[safe: family.rawValue] ?? nil else {
            Log.shared.error("GameFont: invalid path for \(family)")
            self.name = ""
            return
        }

        // Register the custom TTF font if not yet registered
        let url = URL(fileURLWithPath: path) as CFURL
        CTFontManagerRegisterFontsForURL(url, .process, nil)

        // Obtain the descriptor and PostScript name from the registered URL
        if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url) as? [CTFontDescriptor],
           let descriptor = descriptors.first {
            let postscriptName = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String ?? ""
            self.name = postscriptName
            self.nsFont = NSFont(name: postscriptName, size: CGFloat(size))
        } else {
            self.name = ""
            Log.shared.error("GameFont: failed to get descriptor from \(path)")
        }

        if nsFont == nil {
            // Fall back to system font
            self.nsFont = NSFont.systemFont(ofSize: CGFloat(size))
            Log.shared.warn("GameFont: falling back to system font (size \(size))")
        }
    }

    func dispose() {
        nsFont = nil
    }
}
