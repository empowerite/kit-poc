package main

import (
	"os"
	"testing"

	"github.com/empowerite/kit/projects/tui/internal/source"
	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// TestMain runs the tests with a home of their own, as testkit.Main gives them, so none reads what the person keeps.
func TestMain(m *testing.M) {
	// a screen with no clock of its own has the test's, so no wait it sets blocks a command the test drives
	source.Waits = &testkit.Clock{}
	os.Exit(testkit.Main(m))
}
