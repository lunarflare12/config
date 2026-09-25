import QtQuick

import "../components" as Components
import "../core" as Core
import "../services" as Services

Components.PopupSurface {
    id: popup

    popupId: "network"
    cardWidth: Core.Theme.rightSheetWidth
    maxCardHeight: 420

    readonly property var svc: Services.NetworkService

    contentComponent: Component {
        Column {
            id: body
            spacing: 8

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
                        return parts.join(" · ");
                    }
                    if (popup.svc.ethState === "unavailable")
                        return "Unplugged";
                    if (popup.svc.ethAvailable)
                        return "Disconnected";
                    return "No ethernet adapter";
                }
                trailingName: popup.svc.ethConnected ? "check" : ""
                trailing: ""
                trailingColor: Core.Theme.success
                active: popup.svc.ethConnected
                dimmed: !popup.svc.ethAvailable
                onActivated: popup.svc.toggleEthernet()
            }

            Components.NetworkBoard {
                width: parent.width
                height: 200
            }
        }
    }
}
