import QtQuick
import QtQuick.Shapes

// Vector metric icons. Nerd glyphs at widget size render as tofu.
Item {
    id: root

    property string name: ""
    property color color: "#FFFFFF"

    implicitWidth: 16
    implicitHeight: 16

    readonly property real u: Math.min(width, height) / 16
    readonly property real sw: Math.max(1.35, u * 1.45)
    readonly property color fill: Qt.rgba(color.r, color.g, color.b, 0.18)

    readonly property string assetFile: {
        switch (root.name) {
        case "ethernet":
            return "ethernet.png";
        case "network":
            return "network.png";
        case "screenshot":
            return "screenshot.png";
        case "satty":
            return "satty.png";
        default:
            return "";
        }
    }

    readonly property bool hasAsset: root.assetFile !== ""
    readonly property bool assetReady: root.hasAsset && pix.status === Image.Ready

    Image {
        id: pix

        anchors.fill: parent
        visible: root.assetReady
        source: root.hasAsset ? Qt.resolvedUrl("../assets/" + root.assetFile) : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
    }

    Shape {
        visible: root.name === "cpu"
        anchors.fill: parent

        ShapePath {
            strokeColor: root.color
            fillColor: root.fill
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 5 * root.u
            startY: 5 * root.u
            PathLine { x: 11 * root.u; y: 5 * root.u }
            PathLine { x: 11 * root.u; y: 11 * root.u }
            PathLine { x: 5 * root.u; y: 11 * root.u }
            PathLine { x: 5 * root.u; y: 5 * root.u }
        }

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            startX: 7 * root.u
            startY: 2.4 * root.u
            PathLine { x: 7 * root.u; y: 5 * root.u }
            PathMove { x: 9 * root.u; y: 2.4 * root.u }
            PathLine { x: 9 * root.u; y: 5 * root.u }
            PathMove { x: 7 * root.u; y: 11 * root.u }
            PathLine { x: 7 * root.u; y: 13.6 * root.u }
            PathMove { x: 9 * root.u; y: 11 * root.u }
            PathLine { x: 9 * root.u; y: 13.6 * root.u }
            PathMove { x: 2.4 * root.u; y: 7 * root.u }
            PathLine { x: 5 * root.u; y: 7 * root.u }
            PathMove { x: 2.4 * root.u; y: 9 * root.u }
            PathLine { x: 5 * root.u; y: 9 * root.u }
            PathMove { x: 11 * root.u; y: 7 * root.u }
            PathLine { x: 13.6 * root.u; y: 7 * root.u }
            PathMove { x: 11 * root.u; y: 9 * root.u }
            PathLine { x: 13.6 * root.u; y: 9 * root.u }
        }
    }

    Shape {
        visible: root.name === "gpu"
        anchors.fill: parent

        ShapePath {
            strokeColor: root.color
            fillColor: root.fill
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 2.5 * root.u
            startY: 4.5 * root.u
            PathLine { x: 13.5 * root.u; y: 4.5 * root.u }
            PathLine { x: 13.5 * root.u; y: 11.2 * root.u }
            PathLine { x: 2.5 * root.u; y: 11.2 * root.u }
            PathLine { x: 2.5 * root.u; y: 4.5 * root.u }
        }

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            startX: 5.2 * root.u
            startY: 6.6 * root.u
            PathArc {
                x: 8.4 * root.u
                y: 6.6 * root.u
                radiusX: 1.6 * root.u
                radiusY: 1.6 * root.u
            }
            PathArc {
                x: 5.2 * root.u
                y: 6.6 * root.u
                radiusX: 1.6 * root.u
                radiusY: 1.6 * root.u
            }
            PathMove { x: 4.2 * root.u; y: 13.4 * root.u }
            PathLine { x: 4.2 * root.u; y: 11.2 * root.u }
            PathMove { x: 6.4 * root.u; y: 13.4 * root.u }
            PathLine { x: 6.4 * root.u; y: 11.2 * root.u }
            PathMove { x: 8.6 * root.u; y: 13.4 * root.u }
            PathLine { x: 8.6 * root.u; y: 11.2 * root.u }
            PathMove { x: 10.8 * root.u; y: 13.4 * root.u }
            PathLine { x: 10.8 * root.u; y: 11.2 * root.u }
        }
    }

    Shape {
        visible: root.name === "ram"
        anchors.fill: parent

        ShapePath {
            strokeColor: root.color
            fillColor: root.fill
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 2 * root.u
            startY: 5.2 * root.u
            PathLine { x: 14 * root.u; y: 5.2 * root.u }
            PathLine { x: 14 * root.u; y: 10.4 * root.u }
            PathLine { x: 9.3 * root.u; y: 10.4 * root.u }
            PathLine { x: 8.8 * root.u; y: 9.2 * root.u }
            PathLine { x: 7.2 * root.u; y: 9.2 * root.u }
            PathLine { x: 6.7 * root.u; y: 10.4 * root.u }
            PathLine { x: 2 * root.u; y: 10.4 * root.u }
            PathLine { x: 2 * root.u; y: 5.2 * root.u }
        }

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            startX: 4 * root.u
            startY: 12.6 * root.u
            PathLine { x: 4 * root.u; y: 10.4 * root.u }
            PathMove { x: 6.2 * root.u; y: 12.6 * root.u }
            PathLine { x: 6.2 * root.u; y: 10.4 * root.u }
            PathMove { x: 9.8 * root.u; y: 12.6 * root.u }
            PathLine { x: 9.8 * root.u; y: 10.4 * root.u }
            PathMove { x: 12 * root.u; y: 12.6 * root.u }
            PathLine { x: 12 * root.u; y: 10.4 * root.u }
        }
    }

    Shape {
        visible: root.name === "swap"
        anchors.fill: parent

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 3 * root.u
            startY: 10.5 * root.u
            PathLine { x: 3 * root.u; y: 5.5 * root.u }
            PathLine { x: 9.5 * root.u; y: 5.5 * root.u }
            PathMove { x: 7.2 * root.u; y: 3.6 * root.u }
            PathLine { x: 9.8 * root.u; y: 5.5 * root.u }
            PathLine { x: 7.2 * root.u; y: 7.4 * root.u }
            PathMove { x: 13 * root.u; y: 5.5 * root.u }
            PathLine { x: 13 * root.u; y: 10.5 * root.u }
            PathLine { x: 6.5 * root.u; y: 10.5 * root.u }
            PathMove { x: 8.8 * root.u; y: 8.6 * root.u }
            PathLine { x: 6.2 * root.u; y: 10.5 * root.u }
            PathLine { x: 8.8 * root.u; y: 12.4 * root.u }
        }
    }

    Shape {
        visible: root.name === "disk"
        anchors.fill: parent

        ShapePath {
            strokeColor: root.color
            fillColor: root.fill
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 3 * root.u
            startY: 4.2 * root.u
            PathLine { x: 13 * root.u; y: 4.2 * root.u }
            PathLine { x: 13 * root.u; y: 11.8 * root.u }
            PathLine { x: 3 * root.u; y: 11.8 * root.u }
            PathLine { x: 3 * root.u; y: 4.2 * root.u }
        }

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            startX: 5.2 * root.u
            startY: 7 * root.u
            PathLine { x: 10.8 * root.u; y: 7 * root.u }
            PathMove { x: 5.2 * root.u; y: 9.2 * root.u }
            PathLine { x: 8.4 * root.u; y: 9.2 * root.u }
        }
    }

    Shape {
        visible: root.name === "temp"
        anchors.fill: parent

        ShapePath {
            strokeColor: root.color
            fillColor: root.fill
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 7.2 * root.u
            startY: 2.8 * root.u
            PathLine { x: 8.8 * root.u; y: 2.8 * root.u }
            PathLine { x: 8.8 * root.u; y: 9.6 * root.u }
            PathLine { x: 7.2 * root.u; y: 9.6 * root.u }
            PathLine { x: 7.2 * root.u; y: 2.8 * root.u }
        }

        ShapePath {
            strokeColor: root.color
            fillColor: root.fill
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            startX: 5.4 * root.u
            startY: 11.4 * root.u
            PathArc {
                x: 10.6 * root.u
                y: 11.4 * root.u
                radiusX: 2.6 * root.u
                radiusY: 2.6 * root.u
            }
            PathArc {
                x: 5.4 * root.u
                y: 11.4 * root.u
                radiusX: 2.6 * root.u
                radiusY: 2.6 * root.u
            }
        }
    }

    Shape {
        visible: root.name === "ethernet" && !root.assetReady
        anchors.fill: parent

        ShapePath {
            strokeColor: root.color
            fillColor: root.fill
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 5.2 * root.u
            startY: 3.2 * root.u
            PathLine { x: 10.8 * root.u; y: 3.2 * root.u }
            PathLine { x: 13 * root.u; y: 8.2 * root.u }
            PathLine { x: 13 * root.u; y: 11.6 * root.u }
            PathLine { x: 3 * root.u; y: 11.6 * root.u }
            PathLine { x: 3 * root.u; y: 8.2 * root.u }
            PathLine { x: 5.2 * root.u; y: 3.2 * root.u }
        }

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            startX: 5.4 * root.u
            startY: 13.6 * root.u
            PathLine { x: 5.4 * root.u; y: 11.6 * root.u }
            PathMove { x: 7.3 * root.u; y: 13.6 * root.u }
            PathLine { x: 7.3 * root.u; y: 11.6 * root.u }
            PathMove { x: 8.7 * root.u; y: 13.6 * root.u }
            PathLine { x: 8.7 * root.u; y: 11.6 * root.u }
            PathMove { x: 10.6 * root.u; y: 13.6 * root.u }
            PathLine { x: 10.6 * root.u; y: 11.6 * root.u }
        }
    }

    Shape {
        visible: root.name === "network" && !root.assetReady
        anchors.fill: parent

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            startX: 4.2 * root.u
            startY: 11.4 * root.u
            PathArc {
                x: 11.8 * root.u
                y: 11.4 * root.u
                radiusX: 5.2 * root.u
                radiusY: 5.2 * root.u
            }
            PathMove { x: 5.8 * root.u; y: 12.6 * root.u }
            PathArc {
                x: 10.2 * root.u
                y: 12.6 * root.u
                radiusX: 3.1 * root.u
                radiusY: 3.1 * root.u
            }
        }

        ShapePath {
            strokeColor: root.color
            fillColor: root.color
            strokeWidth: 0
            startX: 7.2 * root.u
            startY: 13.4 * root.u
            PathArc {
                x: 8.8 * root.u
                y: 13.4 * root.u
                radiusX: 0.8 * root.u
                radiusY: 0.8 * root.u
            }
            PathArc {
                x: 7.2 * root.u
                y: 13.4 * root.u
                radiusX: 0.8 * root.u
                radiusY: 0.8 * root.u
            }
        }
    }

    Shape {
        visible: root.name === "check"
        anchors.fill: parent

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 3.2 * root.u
            startY: 8.2 * root.u
            PathLine { x: 6.6 * root.u; y: 11.6 * root.u }
            PathLine { x: 12.8 * root.u; y: 4.4 * root.u }
        }
    }

    Shape {
        visible: root.name === "download"
        anchors.fill: parent

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 8 * root.u
            startY: 3.2 * root.u
            PathLine { x: 8 * root.u; y: 11.2 * root.u }
            PathMove { x: 4.6 * root.u; y: 8.2 * root.u }
            PathLine { x: 8 * root.u; y: 12.4 * root.u }
            PathLine { x: 11.4 * root.u; y: 8.2 * root.u }
        }
    }

    Shape {
        visible: root.name === "upload"
        anchors.fill: parent

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.sw
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 8 * root.u
            startY: 12.8 * root.u
            PathLine { x: 8 * root.u; y: 4.8 * root.u }
            PathMove { x: 4.6 * root.u; y: 7.8 * root.u }
            PathLine { x: 8 * root.u; y: 3.6 * root.u }
            PathLine { x: 11.4 * root.u; y: 7.8 * root.u }
        }
    }
}
