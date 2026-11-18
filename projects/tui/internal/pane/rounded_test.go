package pane

import (
	"os"
	"testing"

	"github.com/empowerite/kit/projects/tui/internal/style"
)

// The tests of this package draw a label with its rounded ends, as a Nerd Font draws them; kittui draws them plain
// until its settings ask for them, which style's own tests and the root's hold.
func TestMain(m *testing.M) {
	style.Rounded(true)
	os.Exit(m.Run())
}
