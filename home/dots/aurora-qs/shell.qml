//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "components"
import "core" as Core
import "modules"
import "services" as Services

Scope {
    id: root

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
        target: "screenshot"

        function toggle(): void {
            Core.Session.toggleScreenshot();
        }

        function open(): void {
            Core.Session.screenshotOpen = true;
        }

        function close(): void {
            Core.Session.screenshotOpen = false;
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

        OverviewOverlay {}
    }

    Variants {
        model: Quickshell.screens

        ScreenshotBar {}
    }

    Variants {
        model: Quickshell.screens

        DesktopOverlay {}
    }

    LauncherOverlay {}
    NetworkPopup {}
    CpuPopup {}
    MemoryPopup {}
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
                sourceSize.width: 384
                sourceSize.height: 216
                source: modelData && modelData.thumb ? "file://" + modelData.thumb : ""
            }
        }
    }
}
