package lab

import (
	"bufio"
	"os"
	"strings"
)

func hashMetaLines(path string, stopAt ...string) (label, folder string) {
	fh, err := os.Open(path)
	if err != nil {
		return "", ""
	}
	defer fh.Close()
	sc := bufio.NewScanner(fh)
	for i := 0; i < 80 && sc.Scan(); i++ {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		for _, s := range stopAt {
			if strings.HasPrefix(line, s) {
				return label, folder
			}
		}
		if !strings.HasPrefix(line, "#") {
			if strings.HasPrefix(line, "{") {
				break
			}
			continue
		}
		body := strings.TrimSpace(line[1:])
		key, rest, _ := strings.Cut(body, " ")
		key = strings.TrimRight(strings.ToLower(key), ":=")
		rest = strings.Trim(strings.Trim(rest, "\"'"), " ")
		if rest == "" {
			continue
		}
		if key == "name" && label == "" {
			label = trunc80(rest)
		} else if key == "folder" && folder == "" {
			folder = trunc80(rest)
		}
	}
	return label, folder
}

func confMeta(path string) (string, string) {
	return hashMetaLines(path, "[Peer", "[Interface")
}

func jsonMeta(path string) (string, string) {
	return hashMetaLines(path)
}

func trunc80(s string) string {
	if len(s) > 80 {
		return s[:80]
	}
	return s
}

func stripHashPreamble(text string) string {
	lines := strings.Split(text, "\n")
	i := 0
	for i < len(lines) {
		s := strings.TrimSpace(lines[i])
		if s == "" || strings.HasPrefix(s, "#") {
			i++
			continue
		}
		break
	}
	if i >= len(lines) {
		return ""
	}
	return strings.Join(lines[i:], "\n")
}
