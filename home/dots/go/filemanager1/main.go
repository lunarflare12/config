package main

import (
	"os"
	"path/filepath"

	"github.com/godbus/dbus/v5"
)

type fm struct{}

func writeURIs(uris []string) *dbus.Error {
	if len(uris) == 0 {
		return nil
	}
	home := os.Getenv("HOME")
	if home == "" {
		home = "/home/app"
	}
	dir := filepath.Join(home, "ipc")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return dbus.MakeFailedError(err)
	}
	dest := filepath.Join(dir, "open.path")
	tmp, err := os.CreateTemp(dir, "open.path.*")
	if err != nil {
		return dbus.MakeFailedError(err)
	}
	tmpName := tmp.Name()
	if _, err := tmp.WriteString(uris[0] + "\n"); err != nil {
		tmp.Close()
		os.Remove(tmpName)
		return dbus.MakeFailedError(err)
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpName)
		return dbus.MakeFailedError(err)
	}
	if err := os.Rename(tmpName, dest); err != nil {
		os.Remove(tmpName)
		return dbus.MakeFailedError(err)
	}
	return nil
}

func (f *fm) ShowItems(uris []string, startupId string) *dbus.Error {
	return writeURIs(uris)
}

func (f *fm) ShowFolders(uris []string, startupId string) *dbus.Error {
	return writeURIs(uris)
}

func (f *fm) ShowItemProperties(uris []string, startupId string) *dbus.Error {
	return writeURIs(uris)
}

func main() {
	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		os.Stderr.WriteString(err.Error() + "\n")
		os.Exit(1)
	}
	defer conn.Close()

	if err := conn.Export(&fm{}, "/org/freedesktop/FileManager1", "org.freedesktop.FileManager1"); err != nil {
		os.Stderr.WriteString(err.Error() + "\n")
		os.Exit(1)
	}

	reply, err := conn.RequestName("org.freedesktop.FileManager1", dbus.NameFlagReplaceExisting|dbus.NameFlagDoNotQueue)
	if err != nil {
		os.Stderr.WriteString(err.Error() + "\n")
		os.Exit(1)
	}
	if reply != dbus.RequestNameReplyPrimaryOwner && reply != dbus.RequestNameReplyAlreadyOwner {
		os.Stderr.WriteString("FileManager1 name not available\n")
		os.Exit(1)
	}

	select {}
}
