package lab

import (
	"os"
	"time"

	"aurora/internal/execx"
)

func run(timeout time.Duration, name string, args ...string) (code int, stdout, stderr string) {
	return execx.RunFull(timeout, name, args...)
}

func emit(out, err string) {
	if out != "" {
		_, _ = os.Stdout.WriteString(out)
	}
	if err != "" {
		_, _ = os.Stderr.WriteString(err)
	}
}
