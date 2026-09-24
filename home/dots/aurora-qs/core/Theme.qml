pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme

    // Aurora Runtime Theme

    readonly property string auroraDirectory: Quickshell.env("HOME") + "/.config/aurora"

    readonly property string activeThemePath: auroraDirectory + "/active-theme"

    // Active Theme

    property var activeThemeFile: FileView {
        path: theme.activeThemePath

        watchChanges: true
        blockLoading: false

        onFileChanged: {
            this.reload();
            theme.themeFile.reload();
        }
    }

    // Active Theme ID

    readonly property string activeTheme: activeThemeFile.loaded ? activeThemeFile.text().trim() : "catppuccin-mocha"

    // Active Theme JSON

    property var themeFile: FileView {
        path: theme.auroraDirectory + "/themes/" + theme.activeTheme + ".json"

        watchChanges: true
        blockLoading: true

        onFileChanged: {
            this.reload();
        }
    }

    // Parsed Theme

    readonly property var data: {
        if (!theme.themeFile.loaded)
            return ({});

        try {
            return JSON.parse(theme.themeFile.text());
        } catch (error) {
            console.warn("Aurora Theme: invalid JSON:", error);

            return ({});
        }
    }

    readonly property var fonts: data.fonts || ({})

    readonly property var colors: data.colors || ({})

    readonly property var ui: data.ui || ({})

    // Background

    readonly property color background: colors.background || "#181D25"

    // Surfaces

    readonly property color surface: colors.surface || "#282E37"

    readonly property color surfaceHover: colors.surfaceHover || "#303743"

    // Borders

    readonly property color border: colors.border || "#3B4350"

    readonly property color borderActive: colors.accent || "#A970FF"

    readonly property color separator: colors.separator || "#343B47"

    // Text

    readonly property color text: colors.text || "#F2F3F7"

    readonly property color textSecondary: colors.textSecondary || "#B9BEC8"

    readonly property color textMuted: colors.textMuted || "#858D9A"

    // Accent

    readonly property color accent: colors.accent || "#A970FF"

    readonly property color accentHover: colors.accentHover || "#B98AFF"

    readonly property color accentActive: colors.accentActive || "#C7A6FF"

    readonly property color accentMuted: colors.accentMuted || "#55406F"

    readonly property color accentForeground: colors.accentForeground || "#181D25"

    // Semantic States

    readonly property color success: colors.success || "#8FE3A5"

    readonly property color warning: colors.warning || "#FFD479"

    readonly property color error: colors.error || "#FF7F96"

    readonly property color info: colors.info || "#8FB8FF"

    // Compatibility Aliases

    readonly property color foreground: text

    readonly property color foregroundMuted: textSecondary

    readonly property color foregroundFaint: textMuted

    readonly property color danger: error

    readonly property color accentSoft: accentMuted

    // Semantic Color Resolver

    function resolveColor(name, fallback) {
        switch (name) {
        case "foreground":
            return foreground;
        case "foregroundMuted":
            return foregroundMuted;
        case "foregroundFaint":
            return foregroundFaint;
        case "accent":
            return accent;
        case "accentHover":
            return accentHover;
        case "accentActive":
            return accentActive;
        case "success":
            return success;
        case "warning":
            return warning;
        case "danger":
            return danger;
        case "info":
            return info;
        default:
            return fallback;
        }
    }

    // Clock

    readonly property color clockHour: resolveColor(ui.clock?.hour, foreground)

    // Glass surfaces
    //
    // A theme may ship a translucent surface colour, but the bar and popups
    // draw their own backdrop, so alpha is forced opaque here.

    readonly property color surfaceGlass: Qt.alpha(surface, 1.0)

    // UI
    //
    // Same `!== undefined` idiom as the glass knobs above: `0 || 10` is 10, so
    // `||` would make radius = 0 (square corners) or borderWidth = 0 impossible.

    readonly property int borderWidth: ui.borderWidth !== undefined ? ui.borderWidth : 3

    readonly property int radius: ui.radius !== undefined ? ui.radius : 0

    readonly property int radiusSmall: ui.radiusSmall !== undefined ? ui.radiusSmall : 0

    readonly property int radiusLarge: ui.radiusLarge !== undefined ? ui.radiusLarge : 0

    readonly property int iconSize: Math.max(8, ui.iconSize !== undefined ? ui.iconSize : 16)

    // Glyph sizes were spread across ten different expressions from 10px to 26px,
    // several taken from FONT tokens, which is why some icons looked large and
    // others small. Four steps, derived from iconSize so they move together.
    readonly property int iconSizeSmall: Math.round(iconSize * 0.875)

    readonly property int iconSizeMedium: Math.round(iconSize * 1.25)

    readonly property int fontSize: Math.max(8, ui.fontSize !== undefined ? ui.fontSize : 13)
    readonly property int fontSizeSmall: Math.max(8, ui.fontSizeSmall !== undefined ? ui.fontSizeSmall : 10)
    readonly property int fontSizeLarge: Math.max(8, ui.fontSizeLarge !== undefined ? ui.fontSizeLarge : 15)

    // Geometry

    readonly property int barHeight: 24

    // 8px inset + 64px glass. Extra reserve here leaves wallpaper
    // between the dock and tiled windows.
    readonly property int dockReserve: 72

    readonly property int moduleHeight: 22

    readonly property int barMarginTop: 0

    // Was a hardcoded 18, identical to radiusLarge.
    readonly property int radiusMenu: radiusLarge

    // Was a hardcoded 12, an undeclared fourth radius step between radius (10) and radiusLarge (18).
    readonly property int radiusRow: radius + 2

    readonly property int padding: 8

    readonly property int spacing: 4

    // Typography

    readonly property string fontFamily: fonts.interface || "Inter"
    readonly property string fontMono: fonts.terminal || "JetBrainsMono Nerd Font Mono"

    // The family that actually contains the Nerd Font glyphs. Derived from the
    // theme so it cannot drift from fonts.terminal the way the hardcoded string
    // here had already drifted from lib/themes.nix.
    readonly property string iconFont: fonts.terminal || "JetBrainsMono Nerd Font Mono"

    // Colour font. Only NativeRendering draws its glyphs in colour.
    readonly property string emojiFont: fonts.emoji || "Noto Color Emoji"

    // Popup Geometry

    readonly property int popupWidth: 340

    readonly property int popupMaxHeight: 460

    // Visible detachment from the bar pill. At 2 the cards looked welded to it.
    readonly property int popupGap: 6

    // Tallest a launcher popup may grow. Bar sizes its PanelWindow from this,
    // and LauncherView clamps itself to it, so the window is always big enough
    // to contain the popup it has to host.
    readonly property int launcherMaxHeight: 620

    readonly property int rowHeight: 42

    // Animation
    //
    // Motion is intentionally short and deterministic. Hover and press feel
    // lives in components/Tactile.qml, not here.

    readonly property int durFast: 110

    readonly property int durBase: 180
}
