// The views: where the person left each screen of a workspace, kept in the kit cache, under kittui/views in
// XDG_CACHE_HOME, else ~/.cache, a file for each workspace, named by what the workspace is. A workspace's screens are
// saved when it is left, and every screen made over it when kittui ends; a screen made over a workspace is given what
// was kept, so it opens as it was left, after a restart, or after the memory it held was taken back. A file that cannot
// be read, is of another version, or names what the screen no longer draws, is passed by: the screen opens as it
// would.
package screens

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/flow"
	"github.com/empowerite/kit/projects/tui/internal/kit"
	"github.com/empowerite/kit/projects/tui/internal/shell"
)

// viewsVersion is the version of the file's form; a file of another is not read.
const viewsVersion = 1

// viewsFile is what the cache keeps of a workspace: its version and, by screen, where each was left.
type viewsFile struct {
	Version int                       `json:"version"`
	Kind    string                    `json:"kind"`
	Name    string                    `json:"name"`
	Screens map[string]flow.ViewState `json:"screens"`
}

// viewsDir gives the folder the views are kept in, or nothing where the cache is not known.
func viewsDir() string {
	dir := os.Getenv("XDG_CACHE_HOME")
	if dir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return ""
		}
		dir = filepath.Join(home, ".cache")
	}
	return filepath.Join(dir, "kit", "kittui", "views")
}

// viewsPath gives the file a workspace's views are kept in: named by its kind, name, and checkout, which tell a
// repository from a group of the same name, and one worktree's repository from another's. It is nothing for a
// workspace kit never said, or where the cache is not known.
func viewsPath(ws kit.Workspace) string {
	dir := viewsDir()
	if ws.Kind == "" || dir == "" {
		return ""
	}
	sum := sha256.Sum256([]byte(ws.Kind + "\x00" + ws.Name + "\x00" + ws.Checkout))
	return filepath.Join(dir, hex.EncodeToString(sum[:8])+".json")
}

// stated is a screen that says where it was left, and is given it again.
type stated interface {
	State() flow.ViewState
	Restored(flow.ViewState) flow.Model
}

// saveViews keeps where each of the screens was left, for the workspace. A cache that cannot be written costs only
// the next opening's place, so it is never a failure.
func saveViews(ws kit.Workspace, made map[shell.Screen]tea.Model) {
	path := viewsPath(ws)
	if path == "" {
		return
	}
	file := viewsFile{Version: viewsVersion, Kind: ws.Kind, Name: ws.Name, Screens: map[string]flow.ViewState{}}
	for to, s := range made {
		if st, ok := s.(stated); ok {
			file.Screens[string(to)] = st.State()
		}
	}
	if len(file.Screens) == 0 {
		return
	}
	text, _ := json.Marshal(file)
	if os.MkdirAll(filepath.Dir(path), 0o755) != nil {
		return
	}
	tmp := path + ".tmp"
	if os.WriteFile(tmp, text, 0o644) == nil {
		_ = os.Rename(tmp, path)
	}
}

// restoreViews gives a screen just made over the workspace where it was left, as the cache keeps it.
func restoreViews(ws kit.Workspace, to shell.Screen, s tea.Model) tea.Model {
	st, ok := s.(stated)
	path := viewsPath(ws)
	if !ok || path == "" {
		return s
	}
	text, err := os.ReadFile(path)
	if err != nil {
		return s
	}
	var file viewsFile
	if json.Unmarshal(text, &file) != nil || file.Version != viewsVersion {
		return s
	}
	v, kept := file.Screens[string(to)]
	if !kept {
		return s
	}
	return st.Restored(v)
}
