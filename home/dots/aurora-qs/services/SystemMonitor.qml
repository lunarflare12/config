pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../core" as Core

Item {
    id: monitor
    visible: false

    property int cpu: 0
    property string cpuName: ""
    property string gpuName: ""
    property int memory: 0
    property int temperature: -1
    property int gpu: 0
    property int gpuTemperature: -1
    property real download: 0
    property real upload: 0

    property real ramUsedBytes: 0
    property real ramTotalBytes: 0
    property real vramUsedBytes: 0
    property real vramTotalBytes: 0
    property int vram: 0
    property real swapUsedBytes: 0
    property real swapTotalBytes: 0
    property int swap: 0
    readonly property bool swapEnabled: swapTotalBytes > 0
    property real diskUsedBytes: 0
    property real diskTotalBytes: 0
    property int disk: 0
    property real homeDiskUsedBytes: 0
    property real homeDiskTotalBytes: 0
    property int homeDisk: 0

    property real previousTotal: 0
    property real previousIdle: 0
    property real previousReceived: 0
    property real previousSent: 0
    property real previousTime: 0
    property real downloadBytesPerSec: 0
    property real uploadBytesPerSec: 0
    readonly property string downloadRate: monitor.formatRate(monitor.downloadBytesPerSec)
    readonly property string uploadRate: monitor.formatRate(monitor.uploadBytesPerSec)

    property var cpuHistory: []
    property var gpuHistory: []
    property var memoryHistory: []
    property var vramHistory: []
    property var swapHistory: []
    property var networkHistory: []
    property var downloadHistory: []
    property var uploadHistory: []
    property var networkTimestamps: []
    property var cpuTimestamps: []
    readonly property int historyLimit: 90

    readonly property string scriptPath: (Quickshell.env("HOME") || "") + "/.config/scripts/system-monitor.sh"

    // Full nvidia-smi only while a metrics popup or the desktop boards are visible.
    readonly property bool metricsOpen: {
        if (Core.Session.showDesktopMetrics)
            return true;
        const id = Core.PopupManager.current;
        return id === "network" || id === "cpu" || id === "memory";
    }

    function append(history, value) {
        const next = history.slice();
        if (next.length === 0)
            next.push(value);
        next.push(value);
        return next.slice(-monitor.historyLimit);
    }

    function networkSpeed(value) {
        return value >= 1024 ? (value / 1024).toFixed(1) + " MB/s" : Math.round(value) + " KB/s";
    }

    function toMbit(kibPerSec) {
        return kibPerSec * 1024 * 8 / 1000000;
    }

    function formatMbit(kibPerSec) {
        const mbit = monitor.toMbit(kibPerSec);
        if (mbit >= 100)
            return Math.round(mbit) + " Mbit/s";
        if (mbit >= 10)
            return mbit.toFixed(1) + " Mbit/s";
        if (mbit >= 0.01)
            return mbit.toFixed(2) + " Mbit/s";
        return "0 Mbit/s";
    }

    function formatRate(bytesPerSec) {
        const n = Math.max(0, bytesPerSec);
        if (n < 1024)
            return n.toFixed(1) + "B/s";
        if (n < 1024 * 1024)
            return (n / 1024).toFixed(1) + "KB/s";
        if (n < 1024 * 1024 * 1024)
            return (n / (1024 * 1024)).toFixed(1) + "MB/s";
        return (n / (1024 * 1024 * 1024)).toFixed(1) + "GB/s";
    }

    function tidyCpuName(raw) {
        return String(raw || "").replace(/\s+/g, " ").replace(/\s+Processor$/i, "").trim();
    }

    function tidyGpuName(raw) {
        return String(raw || "").replace(/\s+/g, " ").trim();
    }

    function readCpuName() {
        try {
            const text = String(cpuInfoFile.text());
            const match = text.match(/^model name\s*:\s*(.+)$/m);
            if (match)
                monitor.cpuName = monitor.tidyCpuName(match[1]);
        } catch (e) {
        }
    }

    function formatBytes(bytes) {
        if (bytes >= 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB";
        if (bytes >= 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(0) + " MB";
        if (bytes >= 1024)
            return (bytes / 1024).toFixed(0) + " KB";
        return Math.round(bytes) + " B";
    }

    FileView {
        id: cpuInfoFile
        path: "/proc/cpuinfo"
        watchChanges: false
        blockLoading: true
        printErrors: false
        onLoaded: monitor.readCpuName()
    }

    Process {
        id: gpuNameProc
        command: ["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = this.text.trim().split("\n")[0] || "";
                if (line !== "")
                    monitor.gpuName = monitor.tidyGpuName(line);
            }
        }
    }

    Process {
        id: statsProcess
        command: monitor.metricsOpen ? [monitor.scriptPath] : [monitor.scriptPath, "light"]

        stdout: StdioCollector {
            onStreamFinished: {
                const values = this.text.trim().split(/\s+/).map(Number);
                if (values.length < 15)
                    return;

                const total = values[0];
                const idle = values[1];
                const memTotalKb = values[2];
                const memAvailableKb = values[3];
                const cpuTempC = values[4];
                const received = values[5];
                const sent = values[6];
                const gpuUtil = values[7];
                const gpuTempC = values[8];
                const vramUsedMiB = values[9];
                const vramTotalMiB = values[10];
                const swapTotalKb = values[11];
                const swapFreeKb = values[12];
                const diskUsed = values[13];
                const diskTotal = values[14];
                const homeDiskUsed = values.length > 16 ? values[15] : 0;
                const homeDiskTotal = values.length > 16 ? values[16] : 0;

                const deltaTotal = total - monitor.previousTotal;
                const deltaIdle = idle - monitor.previousIdle;

                if (monitor.previousTotal > 0 && deltaTotal > 0)
                    monitor.cpu = Math.round(100 * (deltaTotal - deltaIdle) / deltaTotal);

                monitor.ramTotalBytes = memTotalKb * 1024;
                monitor.ramUsedBytes = Math.max(0, (memTotalKb - memAvailableKb) * 1024);
                if (memTotalKb > 0)
                    monitor.memory = Math.round(100 * (memTotalKb - memAvailableKb) / memTotalKb);

                monitor.temperature = cpuTempC > 0 ? Math.round(cpuTempC) : -1;

                // Light polls leave GPU fields as sentinels (-1 / 0); keep last full sample.
                if (gpuTempC >= 0 || gpuUtil > 0 || vramTotalMiB > 0) {
                    monitor.gpu = Math.max(0, Math.min(100, Math.round(gpuUtil)));
                    monitor.gpuTemperature = gpuTempC >= 0 ? Math.round(gpuTempC) : -1;
                    monitor.vramUsedBytes = vramUsedMiB * 1024 * 1024;
                    monitor.vramTotalBytes = vramTotalMiB * 1024 * 1024;
                    monitor.vram = vramTotalMiB > 0 ? Math.round(100 * vramUsedMiB / vramTotalMiB) : 0;
                }

                monitor.swapTotalBytes = swapTotalKb * 1024;
                monitor.swapUsedBytes = Math.max(0, (swapTotalKb - swapFreeKb) * 1024);
                monitor.swap = swapTotalKb > 0 ? Math.round(100 * (swapTotalKb - swapFreeKb) / swapTotalKb) : 0;

                if (diskTotal > 0) {
                    monitor.diskUsedBytes = diskUsed;
                    monitor.diskTotalBytes = diskTotal;
                    monitor.disk = Math.round(100 * diskUsed / diskTotal);
                }

                if (homeDiskTotal > 0) {
                    monitor.homeDiskUsedBytes = homeDiskUsed;
                    monitor.homeDiskTotalBytes = homeDiskTotal;
                    monitor.homeDisk = Math.round(100 * homeDiskUsed / homeDiskTotal);
                }

                const now = Date.now();
                const dt = Math.max(0.2, (now - monitor.previousTime) / 1000);
                if (monitor.previousReceived > 0 && monitor.previousTime > 0) {
                    monitor.downloadBytesPerSec = Math.max(0, (received - monitor.previousReceived) / dt);
                    monitor.uploadBytesPerSec = Math.max(0, (sent - monitor.previousSent) / dt);
                    monitor.download = monitor.downloadBytesPerSec / 1024;
                    monitor.upload = monitor.uploadBytesPerSec / 1024;
                }

                monitor.previousTotal = total;
                monitor.previousIdle = idle;
                monitor.previousReceived = received;
                monitor.previousSent = sent;
                monitor.previousTime = now;

                monitor.cpuHistory = monitor.append(monitor.cpuHistory, monitor.cpu);
                monitor.gpuHistory = monitor.append(monitor.gpuHistory, monitor.gpu);
                monitor.memoryHistory = monitor.append(monitor.memoryHistory, monitor.memory);
                monitor.vramHistory = monitor.append(monitor.vramHistory, monitor.vram);
                monitor.swapHistory = monitor.append(monitor.swapHistory, monitor.swap);
                monitor.networkHistory = monitor.append(monitor.networkHistory, monitor.download + monitor.upload);
                monitor.downloadHistory = monitor.append(monitor.downloadHistory, monitor.download);
                monitor.uploadHistory = monitor.append(monitor.uploadHistory, monitor.upload);
                monitor.networkTimestamps = monitor.append(monitor.networkTimestamps, Date.now());
                monitor.cpuTimestamps = monitor.append(monitor.cpuTimestamps, Date.now());
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (statsProcess.running)
                return;
            statsProcess.running = true;
        }
    }

    onMetricsOpenChanged: {
        if (!monitor.metricsOpen || statsProcess.running)
            return;
        statsProcess.running = true;
    }

    Component.onCompleted: {
        monitor.readCpuName();
        gpuNameProc.running = true;
    }
}
