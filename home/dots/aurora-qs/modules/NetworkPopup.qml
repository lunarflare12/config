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
                title: ""
                subtitle: ""
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

            Components.ListRow {
                width: parent.width
                themeIcon: Core.Icons.networkTheme(popup.svc.ethConnected)
                title: popup.svc.ethConnection !== "" ? popup.svc.ethConnection : "Wired"
                subtitle: {
                    const mac = popup.svc.ethMac;
                    if (popup.svc.ethConnected) {
                        const parts = ["Connected"];
                        if (popup.svc.ethIp !== "")
                            parts.push(popup.svc.ethIp);
                        if (mac !== "")
                            parts.push(mac);
                        if (popup.svc.ethDevice !== "")
                            parts.push(popup.svc.ethDevice);
                        return parts.join(" · ");
                    }
                    if (popup.svc.ethState === "unavailable")
                        return mac !== "" ? "Unplugged · " + mac : "Cable unplugged";
                    if (popup.svc.ethAvailable)
                        return mac !== "" ? "Disconnected · " + mac : "Disconnected";
                    return "No ethernet adapter";
                }
                trailingName: popup.svc.ethConnected ? "check" : ""
                trailing: ""
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
