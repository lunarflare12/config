import QtQuick

import Quickshell

import "../core" as Core
import "../services" as Services
import "../components" as Components

Components.PopupSurface {
    id: popup

    popupId: "network"
    cardWidth: 360
    maxCardHeight: 420

    readonly property var svc: Services.NetworkService

    contentComponent: Component {
        Column {
            id: body
            spacing: Core.Theme.spacing

            Components.PopupHeader {
                width: parent.width
                title: "Ethernet"
                subtitle: popup.svc.linkLabel
                showToggle: false
                actions: [
                    {
                        icon: Core.Icons.gear,
                        action: function () {
                            popup.svc.openEditor();
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

            Components.ListRow {
                width: parent.width
                icon: "\udb80\ude00"
                title: popup.svc.ethConnection !== "" ? popup.svc.ethConnection : "Wired"
                subtitle: {
                    if (popup.svc.ethConnected) {
                        const parts = ["Connected"];
                        if (popup.svc.ethIp !== "")
                            parts.push(popup.svc.ethIp);
                        if (popup.svc.ethDevice !== "")
                            parts.push(popup.svc.ethDevice);
                        return parts.join(" · ");
                    }
                    if (popup.svc.ethState === "unavailable")
                        return "Cable unplugged";
                    return popup.svc.ethAvailable ? "Disconnected" : "No ethernet adapter";
                }
                trailing: popup.svc.ethConnected ? "\udb80\udd34" : ""
                trailingColor: Core.Theme.success
                active: popup.svc.ethConnected
                dimmed: !popup.svc.ethAvailable
                onActivated: popup.svc.toggleEthernet()
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Core.Theme.separator
            }

            Components.NetworkBoard {
                width: parent.width
                height: 168
            }
        }
    }
}
