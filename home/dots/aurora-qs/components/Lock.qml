import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

Scope {
    id: root

    property bool inputOpen: false
    property string currentText: ""
    property bool unlocking: false
    property bool showFailure: false
    property int failTick: 0
    readonly property string userName: Quickshell.env("USER") || ""

    onCurrentTextChanged: root.showFailure = false

    function lockSession() {
        root.inputOpen = false;
        root.currentText = "";
        root.showFailure = false;
        root.unlocking = false;
        sessionLock.locked = true;
    }

    function revealInput() {
        if (!sessionLock.locked || root.unlocking)
            return;
        root.inputOpen = true;
    }

    function hideInput() {
        if (root.unlocking)
            return;
        root.inputOpen = false;
        root.currentText = "";
        root.showFailure = false;
    }

    function failAttempt() {
        root.showFailure = true;
        root.failTick++;
    }

    function tryUnlock() {
        if (!sessionLock.locked || root.unlocking)
            return;
        if (root.currentText === "") {
            root.revealInput();
            return;
        }
        root.unlocking = true;
        if (!pam.start()) {
            root.unlocking = false;
            root.currentText = "";
            root.showFailure = true;
            root.failTick++;
        }
    }

    function handleKey(event) {
        if (!sessionLock.locked || root.unlocking)
            return;

        if (event.key === Qt.Key_Escape) {
            if (root.inputOpen)
                root.hideInput();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.revealInput();
            root.tryUnlock();
            event.accepted = true;
            return;
        }

        if (!root.inputOpen)
            root.revealInput();

        if (event.key === Qt.Key_Backspace) {
            if (event.modifiers & Qt.ControlModifier)
                root.currentText = "";
            else
                root.currentText = root.currentText.slice(0, -1);
            event.accepted = true;
            return;
        }

        const text = String(event.text || "");
        if (text.length > 0 && !/[\x00-\x1F\x7F]/.test(text)) {
            root.currentText += text;
            event.accepted = true;
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        onLockedChanged: {
            if (sessionLock.locked) {
                root.inputOpen = false;
                root.currentText = "";
                root.showFailure = false;
                root.unlocking = false;
            } else {
                pam.abort();
                root.inputOpen = false;
                root.currentText = "";
                root.unlocking = false;
            }
        }

        LockSurface {
            session: root
        }
    }

    PamContext {
        id: pam
        config: "hyprlock"
        user: root.userName

        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(root.currentText);
        }

        onCompleted: function (result) {
            if (result === PamResult.Success) {
                root.inputOpen = false;
                sessionLock.locked = false;
            } else {
                root.currentText = "";
                root.showFailure = true;
                root.failTick++;
            }
            root.unlocking = false;
        }

        onError: {
            root.currentText = "";
            root.showFailure = true;
            root.unlocking = false;
            root.failTick++;
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lockSession();
        }

        function toggle(): void {
            if (!sessionLock.locked)
                root.lockSession();
        }
    }
}
