import QtQuick
import Quickshell
import Quickshell.Wayland

import "../core" as Core
import "../services" as Services
import "../components" as Components

PanelWindow {
    id: root

    property var modelData: null
    screen: root.modelData

    readonly property var svc: Services.ShaderService
    readonly property string monitorName: Core.Session.monitorNameForScreen(root.screen)
    readonly property bool open: Core.PopupManager.isOpen("shaders") && root.svc.hostMonitor === root.monitorName

    function rowAction(game) {
        if (!game)
            return;
        if (game.shaders === "building") {
            root.svc.stop();
            return;
        }
        if (game.canBuild && game.gameCurrent !== false && !game.updating)
            root.svc.buildOne(game.id);
        else
            root.svc.updateOne(game.id);
    }

    function fmtSize(n) {
        const b = Number(n) || 0;
        if (b >= 1073741824)
            return (b / 1073741824).toFixed(1) + " ГиБ";
        if (b >= 1048576)
            return (b / 1048576).toFixed(1) + " МиБ";
        if (b >= 1024)
            return (b / 1024).toFixed(0) + " КиБ";
        return b + " Б";
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.open
    exclusiveZone: 0

    onOpenChanged: {
        if (root.open) {
            root.svc.check();
            Qt.callLater(function () {
                shaderEsc.forceActiveFocus();
            });
        }
    }

    WlrLayershell.namespace: "aurora-shaders"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: root.open ? null : emptyMask

    property Region emptyMask: Region {
        width: 0
        height: 0
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.open
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: Core.PopupManager.close()
    }

    Item {
        id: shaderEsc
        anchors.fill: parent
        focus: root.open
        Keys.onEscapePressed: Core.PopupManager.dismissAll()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        visible: root.open
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 620
        height: Math.min(600, cardCol.implicitHeight + Core.Theme.padding * 2)
        radius: Core.Theme.radiusMenu
        color: "transparent"
        antialiasing: true
        visible: root.open

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: Core.Theme.borderWidth
            border.color: Core.Theme.borderActive
            antialiasing: true

            Components.Glass {
                anchors.fill: parent
                radius: parent.radius
                strength: 1.0
            }
        }

        Column {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Core.Theme.padding
            spacing: Core.Theme.spacing

            Components.PopupHeader {
                width: parent.width
                title: "Шейдеры"
                subtitle: {
                    if (root.svc.checking)
                        return "Сверяю buildid со Steam PICS";
                    if (root.svc.updating)
                        return "Качаю " + (root.svc.updatingName || "игру") + " · " + Math.round(root.svc.downloadPercent) + "%";
                    if (root.svc.building)
                        return (root.svc.buildingName !== "" ? "Собираю " + root.svc.buildingName : "Собираю без запуска игр")
                            + (root.svc.barPercent > 0 ? " · " + Math.round(root.svc.barPercent) + "%" : "");
                    if (root.svc.stale)
                        return "Есть патч или несобранные шейдеры";
                    if (root.svc.checkedAt > 0)
                        return "Сверка со Steam есть";
                    return "Нажми обновление — сверка со Steam";
                }
                showToggle: false
                actions: [
                    {
                        icon: Core.Icons.refresh,
                        spinning: root.svc.checking || root.svc.building,
                        action: function () {
                            root.svc.check();
                        }
                    },
                    {
                        icon: Core.Icons.close,
                        action: function () {
                            Core.PopupManager.close();
                        }
                    }
                ]
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Core.Theme.separator
            }

            Flickable {
                width: parent.width
                height: Math.min(360, Math.max(listCol.implicitHeight, 1))
                contentHeight: listCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: listCol
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.svc.games

                        Rectangle {
                            id: row
                            required property var modelData
                            width: parent.width
                            height: 56
                            radius: Core.Theme.radiusRow
                            color: "transparent"
                            opacity: modelData.installed ? 1 : 0.45

                            readonly property bool compiling: modelData.shaders === "building"
                            readonly property bool downloading: !!modelData.updating
                            readonly property int shownPercent: {
                                if (row.compiling)
                                    return Math.round(Number(modelData.buildPercent) || 0);
                                if (row.downloading)
                                    return Math.round(Number(modelData.downloadPercent) || 0);
                                return 0;
                            }
                            readonly property color stripColor: {
                                if (row.compiling)
                                    return Core.Theme.success;
                                if (row.downloading || modelData.gameCurrent === false)
                                    return Core.Theme.error;
                                if (modelData.shaders === "stale" || modelData.shaders === "missing" || modelData.shadersOk === false)
                                    return Core.Theme.warning;
                                if (modelData.installed && (modelData.shaders === "ready" || modelData.shadersOk === true))
                                    return Core.Theme.success;
                                return Core.Theme.foregroundMuted;
                            }
                            readonly property real stripProgress: {
                                if (row.downloading) {
                                    const pct = Number(modelData.downloadPercent) || 0;
                                    if (pct > 0)
                                        return Math.min(1, Math.max(0.04, pct / 100));
                                    const tot = Number(modelData.downloadTotal) || 0;
                                    const got = Number(modelData.downloadBytes) || 0;
                                    if (tot > 0)
                                        return Math.min(1, Math.max(0.04, got / tot));
                                    return 0.18;
                                }
                                if (row.compiling) {
                                    let pct = Number(modelData.buildPercent) || 0;
                                    if (pct <= 0) {
                                        const m = String(modelData.detail || "").match(/(\d+(?:\.\d+)?)\s*%/);
                                        if (m)
                                            pct = Number(m[1]);
                                    }
                                    return Math.min(1, Math.max(0.06, pct / 100));
                                }
                                return 1;
                            }

                            function markColor(ok) {
                                if (ok === true)
                                    return Core.Theme.success;
                                if (ok === false)
                                    return Core.Theme.error;
                                return Core.Theme.foregroundMuted;
                            }

                            function markIcon(ok) {
                                if (ok === true)
                                    return Core.Icons.checkCircle;
                                if (ok === false)
                                    return Core.Icons.closeCircle;
                                return Core.Icons.info;
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Qt.rgba(row.stripColor.r, row.stripColor.g, row.stripColor.b, 0.12)
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.round(parent.width * row.stripProgress)
                                radius: parent.radius
                                color: Qt.rgba(row.stripColor.r, row.stripColor.g, row.stripColor.b, row.downloading || row.compiling ? 0.32 : 0.20)
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: parent.height - 16
                                radius: 2
                                color: row.stripColor
                            }

                            Text {
                                id: rowIcon
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.downloading ? Core.Icons.download : (row.compiling ? Core.Icons.spinner : Core.Icons.gamepad)
                                color: row.stripColor
                                font.family: Core.Theme.iconFont
                                font.pixelSize: Core.Theme.iconSize
                                font.hintingPreference: Font.PreferNoHinting
                                renderType: Text.QtRendering
                                RotationAnimator on rotation {
                                    running: row.compiling
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 900
                                }
                            }

                            Column {
                                anchors.left: rowIcon.right
                                anchors.leftMargin: 10
                                anchors.right: marks.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    width: parent.width
                                    text: modelData.name
                                    elide: Text.ElideRight
                                    color: Core.Theme.foreground
                                    font.family: Core.Theme.fontFamily
                                    font.pixelSize: Core.Theme.fontSize
                                    font.weight: Font.Medium
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    width: parent.width
                                    text: {
                                        const bits = [];
                                        if (row.shownPercent > 0)
                                            bits.push(row.shownPercent + "%");
                                        if (row.downloading)
                                            bits.push("качаю " + root.fmtSize(modelData.downloadBytes) + " / " + root.fmtSize(modelData.downloadTotal));
                                        if (modelData.running)
                                            bits.push("запущена");
                                        bits.push("игра " + root.fmtSize(modelData.installBytes));
                                        bits.push("кэш " + root.fmtSize(modelData.cacheBytes));
                                        if (modelData.detail)
                                            bits.push(modelData.detail);
                                        return bits.join(" · ");
                                    }
                                    elide: Text.ElideRight
                                    color: Core.Theme.foregroundMuted
                                    font.family: Core.Theme.fontFamily
                                    font.pixelSize: Core.Theme.fontSizeSmall
                                    renderType: Text.NativeRendering
                                }
                            }

                            MouseArea {
                                anchors.left: parent.left
                                anchors.right: marks.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.rowAction(modelData)
                            }

                            Row {
                                id: marks
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                z: 1

                                Rectangle {
                                    visible: String(modelData.action || "") !== ""
                                    width: Math.max(52, actionLbl.implicitWidth + 16)
                                    height: 28
                                    radius: 8
                                    color: Qt.rgba(row.stripColor.r, row.stripColor.g, row.stripColor.b, 0.28)
                                    Text {
                                        id: actionLbl
                                        anchors.centerIn: parent
                                        text: modelData.action || ""
                                        color: row.stripColor
                                        font.family: Core.Theme.fontFamily
                                        font.pixelSize: Core.Theme.fontSizeSmall
                                        font.weight: Font.DemiBold
                                        renderType: Text.NativeRendering
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: function (mouse) {
                                            mouse.accepted = true;
                                            root.rowAction(modelData);
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 48
                                    height: 44
                                    radius: 10
                                    color: "transparent"
                                    Components.Tactile {
                                        anchors.fill: parent
                                        radius: 10
                                        hovered: checkMouse.containsMouse
                                        pressed: checkMouse.pressed
                                    }
                                    MouseArea {
                                        id: checkMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: function (mouse) {
                                            mouse.accepted = true;
                                            root.svc.checkOne(modelData.id);
                                        }
                                    }
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: markIcon(modelData.gameCurrent)
                                            color: markColor(modelData.gameCurrent)
                                            font.family: Core.Theme.iconFont
                                            font.pixelSize: Core.Theme.iconSize
                                            font.hintingPreference: Font.PreferNoHinting
                                            renderType: Text.QtRendering
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: row.downloading ? (row.shownPercent + "%") : "игра"
                                            color: markColor(modelData.gameCurrent)
                                            font.family: Core.Theme.fontFamily
                                            font.pixelSize: 8
                                            renderType: Text.NativeRendering
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 56
                                    height: 44
                                    radius: 10
                                    color: "transparent"
                                    Components.Tactile {
                                        anchors.fill: parent
                                        radius: 10
                                        hovered: updateMouse.containsMouse
                                        pressed: updateMouse.pressed
                                    }
                                    MouseArea {
                                        id: updateMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: function (mouse) {
                                            mouse.accepted = true;
                                            root.rowAction(modelData);
                                        }
                                    }
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: row.compiling ? Core.Icons.spinner : markIcon(modelData.shadersOk)
                                            color: row.compiling || modelData.shadersOk ? Core.Theme.success : Core.Theme.warning
                                            font.family: Core.Theme.iconFont
                                            font.pixelSize: Core.Theme.iconSize
                                            font.hintingPreference: Font.PreferNoHinting
                                            renderType: Text.QtRendering
                                            RotationAnimator on rotation {
                                                running: row.compiling
                                                loops: Animation.Infinite
                                                from: 0
                                                to: 360
                                                duration: 900
                                            }
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: row.compiling ? (row.shownPercent + "%") : "шейдеры"
                                            color: row.compiling || modelData.shadersOk ? Core.Theme.success : Core.Theme.warning
                                            font.family: Core.Theme.fontFamily
                                            font.pixelSize: 8
                                            renderType: Text.NativeRendering
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: root.svc.games.length === 0
                text: "Нет установленных игр в Steam"
                color: Core.Theme.foregroundMuted
                font.family: Core.Theme.fontFamily
                font.pixelSize: Core.Theme.fontSizeSmall
                renderType: Text.NativeRendering
            }
        }
    }
}
