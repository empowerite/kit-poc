package welcome

import (
	"os"
	"testing"

	"github.com/empowerite/kit/projects/tui/internal/style"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// TestMain runs the tests with a home of their own, as testkit.Main gives them, so none reads what the person keeps,
// and with labels drawn with their rounded ends, as a Nerd Font draws them; kittui draws them plain until its
// settings ask for them, which style's own tests and the root's hold.
func TestMain(m *testing.M) {
	style.Rounded(true)
	os.Exit(testkit.Main(m))
}
