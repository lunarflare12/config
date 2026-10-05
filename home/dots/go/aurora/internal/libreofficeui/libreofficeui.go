package libreofficeui

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"aurora/internal/execx"
)

const emptyXCU = `<?xml version="1.0" encoding="UTF-8"?>
<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"></oor:items>
`

const gtkINI = `[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=WhiteSur-Dark
gtk-icon-theme-name=WhiteSur-dark
`

var appPath = "/org.openoffice.Office.UI.ToolbarMode/Applications/org.openoffice.Office.UI.ToolbarMode:Application"

var settings = []struct{ path, name, value string }{
	{"/org.openoffice.Office.UI.ToolbarMode", "ActiveWriter", "notebookbar.ui"},
	{"/org.openoffice.Office.UI.ToolbarMode", "ActiveCalc", "notebookbar.ui"},
	{"/org.openoffice.Office.UI.ToolbarMode", "ActiveImpress", "notebookbar.ui"},
	{"/org.openoffice.Office.UI.ToolbarMode", "ActiveDraw", "notebookbar.ui"},
	{appPath + "['Writer']", "Active", "notebookbar.ui"},
	{appPath + "['Calc']", "Active", "notebookbar.ui"},
	{appPath + "['Impress']", "Active", "notebookbar.ui"},
	{appPath + "['Draw']", "Active", "notebookbar.ui"},
	{"/org.openoffice.Office.Common/Misc", "SymbolStyle", "colibre_dark"},
	{"/org.openoffice.Office.Common/Misc", "ShowTipOfTheDay", "false"},
	{"/org.openoffice.Office.Common/Appearance", "ApplicationAppearance", "2"},
	{"/org.openoffice.Office.Common/Appearance", "LibreOfficeTheme", "0"},
	{"/org.openoffice.Office.Common/Appearance", "UseOnlyWhiteDocBackground", "false"},
}

func itemXML(path, name, value string) string {
	return fmt.Sprintf(`<item oor:path="%s"><prop oor:name="%s" oor:op="fuse"><value>%s</value></prop></item>`, path, name, value)
}

func upsert(xml, path, name, value string) (string, error) {
	new := itemXML(path, name, value)
	escPath := regexp.QuoteMeta(path)
	escName := regexp.QuoteMeta(name)
	pat := regexp.MustCompile(`(?s)<item oor:path="` + escPath + `">\s*<prop oor:name="` + escName + `"[^>]*>\s*<value>[^<]*</value>\s*</prop>\s*</item>`)
	if pat.MatchString(xml) {
		return pat.ReplaceAllString(xml, new), nil
	}
	if !strings.Contains(xml, "</oor:items>") {
		return "", fmt.Errorf("xcu missing </oor:items>")
	}
	return strings.Replace(xml, "</oor:items>", new+"</oor:items>", 1), nil
}

func pinGTK(home string) {
	for _, rel := range []string{".config/gtk-3.0/settings.ini", ".config/gtk-4.0/settings.ini"} {
		p := filepath.Join(home, rel)
		_ = os.MkdirAll(filepath.Dir(p), 0o755)
		_ = os.WriteFile(p, []byte(gtkINI), 0o644)
	}
}

func Main(args []string) int {
	home := execx.Home()
	if h := os.Getenv("HOME"); h != "" {
		home = h
	}
	xcu := filepath.Join(home, ".config/libreoffice/4/user/registrymodifications.xcu")
	lock := filepath.Join(home, ".config/libreoffice/4/.lock")
	if _, err := os.Stat(lock); err == nil && os.Getenv("LIBREOFFICE_UI_FORCE") != "1" {
		fmt.Fprintln(os.Stderr, "libreoffice is running; skip (set LIBREOFFICE_UI_FORCE=1 to write anyway)")
		return 2
	}
	pinGTK(home)
	_ = os.MkdirAll(filepath.Dir(xcu), 0o755)
	xml := emptyXCU
	if b, err := os.ReadFile(xcu); err == nil {
		xml = string(b)
	}
	if !strings.Contains(xml, "oor:items") {
		fmt.Fprintf(os.Stderr, "unexpected xcu contents in %s\n", xcu)
		return 1
	}
	var err error
	for _, s := range settings {
		xml, err = upsert(xml, s.path, s.name, s.value)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
	}
	if err := os.WriteFile(xcu, []byte(xml), 0o644); err != nil {
		return 1
	}
	fmt.Printf("wrote %s\n", xcu)
	return 0
}
