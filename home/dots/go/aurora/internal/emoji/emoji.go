package emoji

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"strings"
)

var fqLine = regexp.MustCompile(`^([0-9A-F ]+);\s+fully-qualified\s+#\s+(\S+)\s+(.+)$`)

type item struct {
	Emoji    string `json:"emoji"`
	Name     string `json:"name"`
	Group    string `json:"group"`
	Subgroup string `json:"subgroup"`
}

// BuildTestTxt parses Unicode emoji-test.txt into emoji.json.
func BuildTestTxt(sourcePath, outPath string) error {
	in, err := os.Open(sourcePath)
	if err != nil {
		return err
	}
	defer in.Close()

	group := ""
	subgroup := ""
	var items []item

	sc := bufio.NewScanner(in)
	for sc.Scan() {
		line := strings.TrimRight(sc.Text(), "\r")
		if strings.HasPrefix(line, "# group:") {
			group = strings.TrimSpace(strings.TrimPrefix(line, "# group:"))
			continue
		}
		if strings.HasPrefix(line, "# subgroup:") {
			subgroup = strings.TrimSpace(strings.TrimPrefix(line, "# subgroup:"))
			continue
		}
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		m := fqLine.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		var runes strings.Builder
		for _, cp := range strings.Fields(m[1]) {
			var v rune
			if _, err := fmt.Sscanf(cp, "%X", &v); err != nil {
				continue
			}
			runes.WriteRune(v)
		}
		items = append(items, item{
			Emoji:    runes.String(),
			Name:     strings.ToLower(strings.TrimSpace(m[3])),
			Group:    strings.ToLower(group),
			Subgroup: strings.ToLower(subgroup),
		})
	}
	if err := sc.Err(); err != nil {
		return err
	}

	out, err := os.Create(outPath)
	if err != nil {
		return err
	}
	defer out.Close()
	enc := json.NewEncoder(out)
	enc.SetEscapeHTML(false)
	return enc.Encode(items)
}

func Main(args []string) int {
	if len(args) >= 1 && args[0] == "build" && len(args) >= 3 {
		if err := BuildTestTxt(args[1], args[2]); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
		return 0
	}
	return 2
}
