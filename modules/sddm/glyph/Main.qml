import QtQuick 2.15

import "components"

Rectangle {
    id: container
    width: 1920
    height: 1080
    color: "black"
    focus: true

    property bool inputOpen: false
    property int userIdx: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIdx: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0

    Component.onCompleted: {
        if (userModel.lastIndex >= 0)
            userIdx = userModel.lastIndex;
        if (sessionModel.lastIndex >= 0)
            sessionIdx = sessionModel.lastIndex;
    }

    FontLoader {
        id: ndotFont
        source: "assets/fonts/Ndot-57-Aligned.ttf"
    }
    FontLoader {
        id: symbolFont
        source: "assets/fonts/SymbolsNerdFont.ttf"
    }
    property string globalFont: "Inter"

    Image {
        id: bg
        anchors.fill: parent
        source: config.background || "assets/images/background.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: container.inputOpen ? 0.42 : 0.12
        Behavior on opacity {
            NumberAnimation {
                duration: 420
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !container.inputOpen
        onClicked: container.revealInput()
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            container.hideInput();
            event.accepted = true;
            return;
        }
        var ch = event.text || "";
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            container.revealInput();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Backspace) {
            container.revealInput();
            event.accepted = true;
            return;
        }
        if (ch.length > 0 && ch.charCodeAt(0) >= 32) {
            container.revealInput(ch);
            event.accepted = true;
            return;
        }
        container.revealInput();
        event.accepted = true;
    }

    function revealInput(ch) {
        container.inputOpen = true;
        Qt.callLater(function () {
            if (ch)
                loginPanel.prependPassword(ch);
            else
                loginPanel.focusPassword();
        });
    }

    function hideInput() {
        container.inputOpen = false;
        loginPanel.reset();
        container.focus = true;
    }

    Clock {
        id: clock
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 72
        symbolFontName: symbolFont.name
        fontName: container.globalFont
        textColor: "white"
        opacity: container.inputOpen ? 0.55 : 1.0
        Behavior on opacity {
            NumberAnimation {
                duration: 420
                easing.type: Easing.OutCubic
            }
        }
    }

    LoginPanel {
        id: loginPanel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 90
        width: 400
        fontName: container.globalFont
        textColor: "white"
        userIndex: container.userIdx
        sessionIndex: container.sessionIdx
        onUserSelected: container.userIdx = index
        onSessionSelected: container.sessionIdx = index
        onDismissed: container.hideInput()
        opacity: container.inputOpen ? 1.0 : 0.0
        scale: container.inputOpen ? 1.0 : 0.96
        transformOrigin: Item.Bottom
        visible: opacity > 0.01
        enabled: container.inputOpen
        property real slide: container.inputOpen ? 0 : 1
        transform: Translate {
            y: loginPanel.slide * 360
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 380
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 560
                easing.type: Easing.OutCubic
            }
        }
        Behavior on slide {
            NumberAnimation {
                duration: 560
                easing.type: Easing.OutCubic
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            loginPanel.triggerError();
        }
        function onLoginSucceeded() {
            container.inputOpen = false;
        }
    }

    PowerMenu {
        id: powerMenu
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 50
        symbolFontName: symbolFont.name
        fontName: container.globalFont
        textColor: "white"
        opacity: container.inputOpen ? 0.55 : 1.0
        Behavior on opacity {
            NumberAnimation {
                duration: 420
                easing.type: Easing.OutCubic
            }
        }
    }
}
