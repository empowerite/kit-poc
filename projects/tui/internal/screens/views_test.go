// The views are kept in the kit cache, a file for each workspace, and a screen made over a workspace is given what was
// kept.
package screens

import (
	"os"
	"path/filepath"
	"testing"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/flow"
	"github.com/empowerite/kit/projects/tui/internal/kit"
	"github.com/empowerite/kit/projects/tui/internal/shell"
)

// kept gives the file the views of the workspace the root shows are kept in.
func kept(t *testing.T, m Model) string {
	t.Helper()
	path := viewsPath(m.workspace)
	if path == "" {
		t.Fatalf("no file for %+v", m.workspace)
	}
	return path
}

// placed leaves the picture's cursor on the row of the stage.
func placed(m Model, stage string, row int) Model {
	m.made[shell.Issues] = m.made[shell.Issues].(flow.Model).Restored(flow.ViewState{Stage: stage,
		Stages: map[string]flow.StageState{stage: {Cursor: row}}})
	return m
}

// cursorOf gives where the cursor is in the stage of the picture the root has made, as the picture says it was left.
func cursorOf(m Model, stage string) int {
	return m.made[shell.Issues].(flow.Model).State().Stages[stage].Cursor
}

func TestAWorkspaceLeftIsKeptInTheCacheAndGivenBackToAScreenMadeAgain(t *testing.T) {
	m, _ := movers(t)
	stage := m.made[shell.Issues].(flow.Model).State().Stage
	m = placed(m, stage, 4)
	path := kept(t, m)
	m = drive(m, shell.PickMsg{Workspace: "github.com/o/b"})
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("what the workspace left was not kept: %v", err)
	}
	// a screen made over a again, as after a restart or a workspace closed to free memory, is given what was kept
	m.workspace = kit.Workspace{}
	m.workspace = m.parked[0].ws
	again, err := m.open(shell.Issues)
	if err != nil {
		t.Fatal(err)
	}
	if got := again.(flow.Model).State().Stages[stage].Cursor; got != 4 {
		t.Errorf("the cursor: %d, want 4", got)
	}
}

func TestTheShownWorkspaceIsKeptWhenKittuiEnds(t *testing.T) {
	m, _ := movers(t)
	path := kept(t, m)
	_ = os.Remove(path)
	m.Close()
	if _, err := os.Stat(path); err != nil {
		t.Errorf("not kept at the end: %v", err)
	}
}

func TestTheScreensMadeBeforeKitSaidTheWorkspaceAreGivenWhereTheyWereLeft(t *testing.T) {
	m, _ := movers(t)
	stage := m.made[shell.Issues].(flow.Model).State().Stage
	m = placed(m, stage, 3)
	m.Close()
	// kittui starts again in the same repository: the picture is made before kit says where it is
	first, _ := m.open(shell.Issues)
	root := New(m.runner, shell.Issues, first)
	next, _ := root.Update(workspaceMsg{ws: m.workspace})
	if got := cursorOf(next.(Model), stage); got != 3 {
		t.Errorf("the cursor after the restart: %d, want 3", got)
	}
}

func TestViewsThatCannotBeReadOrKeptAreLeftAlone(t *testing.T) {
	m, _ := movers(t)
	ws := m.workspace
	path := kept(t, m)
	screen := m.made[shell.Issues]
	// nothing kept, a file that is not JSON, one of another version, and one that names no such screen
	for name, text := range map[string]string{"none": "", "junk": "{", "version": `{"version":9}`,
		"other": `{"version":1,"screens":{"changes":{}}}`} {
		_ = os.Remove(path)
		if text != "" {
			if err := os.WriteFile(path, []byte(text), 0o644); err != nil {
				t.Fatal(err)
			}
		}
		if got := restoreViews(ws, shell.Issues, screen); got.(flow.Model).State().Stage != screen.(flow.Model).State().Stage {
			t.Errorf("%s: the screen changed", name)
		}
	}
	// a screen that keeps no place, a workspace kit never said, and a cache that is not known
	if got := restoreViews(ws, shell.Welcome, struct{ tea.Model }{}); got == nil {
		t.Error("a screen of no place was lost")
	}
	if restoreViews(kit.Workspace{}, shell.Issues, screen) == nil || viewsPath(kit.Workspace{}) != "" {
		t.Error("a workspace kit never said")
	}
	saveViews(kit.Workspace{}, m.made)
	saveViews(ws, map[shell.Screen]tea.Model{shell.Welcome: struct{ tea.Model }{}})
	t.Setenv("XDG_CACHE_HOME", "")
	t.Setenv("HOME", "")
	if viewsDir() != "" || viewsPath(ws) != "" {
		t.Error("the cache is not known, yet there is a folder")
	}
	t.Setenv("HOME", t.TempDir())
	if dir := viewsDir(); dir != filepath.Join(os.Getenv("HOME"), ".cache", "kit", "kittui", "views") {
		t.Errorf("under HOME: %s", dir)
	}
	// a cache that cannot be written costs only the next opening's place: its folder is a file, then a folder is
	blocked := filepath.Join(t.TempDir(), "file")
	if err := os.WriteFile(blocked, nil, 0o644); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_CACHE_HOME", blocked)
	saveViews(ws, m.made)
	cache := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", cache)
	if err := os.MkdirAll(viewsPath(ws)+".tmp", 0o755); err != nil {
		t.Fatal(err)
	}
	saveViews(ws, m.made)
	if info, err := os.Stat(viewsPath(ws)); err == nil && info.IsDir() {
		t.Error("a directory was written over")
	}
}
