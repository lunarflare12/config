//@ pragma UseQApplication

import Quickshell
import Quickshell.Wayland

import "components"
import "modules"

Scope {
    id: root
    Bar {}
    NetworkPopup {}
    CpuPopup {}
    MemoryPopup {}
    AudioPopup {}
    CalendarPopup {}
    NotificationPopup {}
    Notifications {}
}
