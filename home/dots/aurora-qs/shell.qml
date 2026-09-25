//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io

import "components"
import "core" as Core
import "modules"
import "services" as Services

Scope {
    id: root

    IpcHandler {
        target: "island"

        function next(): void {
            Services.IslandService.cycle(1);
        }

        function prev(): void {
            Services.IslandService.cycle(-1);
        }
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            Core.Session.toggleOverview();
        }

        function open(): void {
            Core.Session.overviewOpen = true;
        }

        function close(): void {
            Core.Session.overviewOpen = false;
        }
    }

    IpcHandler {
        target: "preview"

        function toggle(paths: string): void {
            Core.Session.togglePreview(paths);
        }

        function show(paths: string): void {
            Core.Session.openPreview(paths);
        }

        function close(): void {
            Core.Session.closePreview();
        }
    }

    IpcHandler {
        target: "screenshot"

        function toggle(): void {
            Core.Session.toggleScreenshot();
        }

        function open(): void {
            Core.Session.screenshotOpen = true;
        }

        function close(): void {
            Core.Session.dismissScreenshot();
        }
    }

    IpcHandler {
        target: "bar"

        function hide(): void {
            Core.Session.forceHideGameBar = true;
        }

        function show(): void {
            Core.Session.forceHideGameBar = false;
        }
    }

    IpcHandler {
        target: "shaders"

        function toggle(): void {
            Services.ShaderService.toggleOn("");
        }

        function open(): void {
            Services.ShaderService.showOn("");
        }

        function close(): void {
            Core.PopupManager.close();
        }

        function build(): void {
            Services.ShaderService.build();
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            Core.PopupManager.toggle("launcher");
        }

        function open(): void {
            Core.PopupManager.open("launcher");
        }

        function close(): void {
            Core.PopupManager.close();
        }
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            Core.PopupManager.toggleAppearance("wallpaper");
        }

        function open(): void {
            Core.PopupManager.appearanceMode = "wallpaper";
            Core.PopupManager.open("wallpaper");
        }

        function close(): void {
            Core.PopupManager.close();
        }
    }

    IpcHandler {
        target: "theme"

        function toggle(): void {
            Core.PopupManager.toggleAppearance("theme");
        }

        function open(): void {
            Core.PopupManager.appearanceMode = "theme";
            Core.PopupManager.open("theme");
        }

        function close(): void {
            Core.PopupManager.close();
        }
    }

    IpcHandler {
        target: "cursor"

        function toggle(): void {
            Core.PopupManager.toggleAppearance("cursor");
        }

        function open(): void {
            Core.PopupManager.appearanceMode = "cursor";
            Core.PopupManager.open("cursor");
        }

        function close(): void {
            Core.PopupManager.close();
        }

        function apply(id: string): void {
            Services.CursorService.apply(id);
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            Core.PopupManager.toggle("clipboard");
        }

        function open(): void {
            Core.PopupManager.open("clipboard");
        }

        function close(): void {
            Core.PopupManager.close();
        }
    }

    IpcHandler {
        target: "emoji"

        function toggle(): void {
            Core.PopupManager.toggle("emoji");
        }

        function open(): void {
            Core.PopupManager.open("emoji");
        }

        function close(): void {
            Core.PopupManager.close();
        }
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            Core.PopupManager.toggle("power");
        }

        function open(): void {
            Core.PopupManager.open("power");
        }

        function close(): void {
            Core.PopupManager.close();
        }
    }

    IpcHandler {
        target: "brightness"

        function up(): void {
            Services.BrightnessService.step(true);
        }

        function down(): void {
            Services.BrightnessService.step(false);
        }
    }

    Variants {
        model: Quickshell.screens

        BrightnessDim {}
    }

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Variants {
        model: Quickshell.screens

        ScreenBorder {
            edge: "left"
        }
    }

    Variants {
        model: Quickshell.screens

        ScreenBorder {
            edge: "right"
        }
    }

    Variants {
        model: Quickshell.screens

        ScreenBorder {
            edge: "bottom"
        }
    }

    Variants {
        model: Quickshell.screens

        OverviewOverlay {}
    }

    Variants {
        model: Quickshell.screens

        ScreenshotBar {}
    }

    Variants {
        model: Quickshell.screens

        QuickLook {}
    }

    Variants {
        model: Quickshell.screens

        DesktopOverlay {}
    }

    Variants {
        model: Quickshell.screens

        LauncherOverlay {}
    }

    Variants {
        model: Quickshell.screens

        EdgeWallpaper {}
    }

    Variants {
        model: Quickshell.screens

        EdgeAudio {}
    }

    Lock {}
    NetworkPopup {}
    AudioPopup {}
    BrightnessPopup {}
    CalendarPopup {}
    NotificationPopup {}
    Notifications {}

    Variants {
        model: Quickshell.screens

        ShaderPopup {}
    }

    // Decode wallpaper thumbs once at startup so the picker does not hitch.
    Item {
        visible: false
        width: 0
        height: 0

        Repeater {
            model: Services.WallpaperService.wallpapers

            Image {
                required property var modelData
                width: 1
                height: 1
                asynchronous: true
                cache: true
                sourceSize.width: 640
                sourceSize.height: 360
                source: modelData && modelData.thumb ? "file://" + modelData.thumb : ""
            }
        }

        Image {
            width: 1
            height: 1
            asynchronous: true
            cache: true
            source: {
                const p = Services.WallpaperService.currentPreview;
                if (!p || Services.WallpaperService.isLivePath(p))
                    return "";
                return "file://" + p;
            }
        }
    }
}
