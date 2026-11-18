// Watch: a stage watched loads again once it is stale, as its mark says, without waiting for Refresh All. Watch, in
// the tab's menu, is a toggle: it watches the selected stage, and reads Watching, checked, while it is watched, and
// choosing that stops it. Watch All, in the app's menu under Refresh All, is one too, over every stage that can be
// watched: blank while none is, – while some are, where choosing it watches the rest, and Watching All, checked, once
// all are, which stops them all. The keys bar's right end says watching while the selected stage is watched. Nothing
// is watched at the start. A stage that loads again keeps its rows on the screen, and its dot, until the new ones
// come; it reads the forge afresh, as the change its mark says of is newer than the snapshot the stages share. A stage
// its verb never marks, as its catalog entry's marked false says of kit people's, never goes stale, so its tab's menu
// has no Watch, and Watch All passes it by; one whose mark kit's last read gave null, as kit flow's when the forge
// cannot answer, has Watch dim until a mark comes.
package flow

import (
	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/shell"
	"github.com/empowerite/kit/projects/tui/internal/style"
)

// The watch items' names: Watch, and Watching once it is on, each checked in the menu's gutter as it stands; and the
// app's, Watch All, and Watching All once every stage that can be is watched. RefreshAll is the app's other own line.
// Unwatched is the glyph the legend gives a watched stage.
const (
	WatchIt     = "Watch"
	Watching    = "Watching"
	WatchAll    = "Watch All"
	WatchingAll = "Watching All"
	RefreshAll  = "Refresh All"
	Unwatched   = "🔭"
)

// watchItem gives the tab's menu's line for the stage at i: Watch, a toggle that is off, or Watching, checked, while it
// is watched.
func (m Model) watchItem(i int) shell.Item {
	if i < len(m.stages) && m.stages[i].src.Watch {
		return shell.Item{Name: Watching, Keys: "W", Check: shell.On}
	}
	return shell.Item{Name: WatchIt, Keys: "W", Check: shell.Off}
}

// watchable says whether the stage at i can be watched now: kittui draws it, its verb marks it, and kit's last read
// of the marks gave it one, or none yet; a null mark never moves, so Watch would wait on nothing.
func (m Model) watchable(i int) bool {
	mark, read := m.marks.Value[m.stages[i].name]
	return sourced(m.stages[i].name) && everMarked(m.stages[i].name) && (!read || mark != "")
}

// watching gives how many of the stages kittui draws are watched, and how many it can watch, as watchable says, or
// watches already.
func (m Model) watching() (watched, all int) {
	for i, s := range m.stages {
		if m.watchable(i) || s.src.Watch {
			all++
			if s.src.Watch {
				watched++
			}
		}
	}
	return watched, all
}

// ownItems gives the picture's own lines of the app's menu, Refresh All and Watch All, and the names of those that do
// nothing now: Watch All while no stage can be watched. Watch All is a toggle over every stage that can be: blank while
// none is watched, – while some are, so that choosing it watches the rest, and, once all are, Watching All, checked,
// which stops them all.
func (m Model) ownItems() (items []shell.Item, dim []string) {
	watched, all := m.watching()
	watch := shell.Item{Name: WatchAll, Check: shell.Off}
	switch {
	case all > 0 && watched == all:
		watch = shell.Item{Name: WatchingAll, Check: shell.On}
	case watched > 0:
		watch.Check = shell.Mixed
	case all == 0:
		dim = append(dim, WatchAll)
	}
	return []shell.Item{{Name: RefreshAll}, watch}, dim
}

// syncOwn gives the app's menu the picture's own lines as they stand now.
func (m *Model) syncOwn() { m.appMenu.Own, m.appMenu.Dim = m.ownItems() }

// toggleWatch watches the stage at i, or stops; a stage watched while it is stale loads again at once.
func (m *Model) toggleWatch(i int) tea.Cmd {
	s := &m.stages[i]
	s.src.Watch = !s.src.Watch
	m.syncOwn()
	if s.src.Watch && s.src.Stale && !s.src.Loading {
		return m.rewatch(s.name)
	}
	return nil
}

// watchAll watches every stage it can, as watchable says, or, with on false, stops them all; each stale stage watched
// loads again at once.
func (m *Model) watchAll(on bool) tea.Cmd {
	var cmds []tea.Cmd
	for i := range m.stages {
		s := &m.stages[i]
		if on && !m.watchable(i) || !sourced(s.name) {
			continue
		}
		if on && !s.src.Watch && s.src.Stale && !s.src.Loading {
			cmds = append(cmds, m.rewatch(s.name))
		}
		s.src.Watch = on
	}
	m.syncOwn()
	return tea.Batch(cmds...)
}

// watchedText gives what the keys bar's right end says of Watch: watching, in the accent, while the selected stage is
// watched; nothing while it is not.
func (m Model) watchedText() string {
	if len(m.stages) == 0 || !m.stages[m.stage].src.Watch {
		return ""
	}
	return style.Tint(Unwatched + " watching")
}

// rewatch loads a stale stage again, reading the forge afresh, its rows and its dot staying until the new ones come.
func (m *Model) rewatch(name string) tea.Cmd { return m.again(name, true) }
