// Parking: the screens of a workspace that kittui moves off are kept, as they were left, and shown again when it comes
// back, so switching from one repository to another and back loads nothing from the start. What a screen started goes
// on while it is parked: its answers reach it, by the epoch it was made under, which no other screen has had. A screen
// parked longer than parkedFresh is told to read again as it is shown, over what it kept, so the rows are there at
// once and the forge's answer replaces them. Only parkedMost workspaces are kept, the one left longest ago closed
// first, since each screen holds its rows.
package screens

import (
	"slices"
	"time"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/kit"
	"github.com/empowerite/kit/projects/tui/internal/shell"
)

// parkedMost is how many workspaces, beside the one shown, keep their screens.
const parkedMost = 3

// parkedFresh is how long a workspace's screens may be parked and shown again as they are, with no read.
const parkedFresh = time.Minute

// now is the clock the screens read; the tests set it.
var now = time.Now

// parked is the screens of a workspace left: the workspace as kit said it, when it was left, each screen and its epoch.
type parked struct {
	ws     kit.Workspace
	at     time.Time
	made   map[shell.Screen]tea.Model
	epochs map[shell.Screen]int
}

// refreshing is a screen that reads again what it draws, as its menu's Refresh All does.
type refreshing interface {
	Refreshed() (tea.Model, tea.Cmd)
}

// closeAll ends what each screen started.
func closeAll(made map[shell.Screen]tea.Model) {
	for _, s := range made {
		if c, ok := s.(interface{ Close() }); ok {
			c.Close()
		}
	}
}

// same says whether a workspace is the place another was: its kind, name, and checkout, and the members of a group.
func same(a, b kit.Workspace) bool {
	return a.Kind == b.Kind && a.Name == b.Name && a.Checkout == b.Checkout && slices.Equal(a.Members, b.Members)
}

// park keeps the screens made that read the workspace left, all but those kept says stay, each with a new epoch for
// the screen made there next. A workspace kit never said is not kept, nor are screens when none was left; the ones
// kept longest ago are closed past parkedMost.
func (m Model) park(left kit.Workspace, stays func(shell.Screen) bool) Model {
	p := &parked{ws: left, at: now(), made: map[shell.Screen]tea.Model{}, epochs: map[shell.Screen]int{}}
	for to, s := range m.made {
		if stays(to) {
			continue
		}
		delete(m.made, to)
		if left.Kind == "" {
			closeAll(map[shell.Screen]tea.Model{to: s})
		} else {
			p.made[to], p.epochs[to] = s, m.epochs[to]
		}
		m.seq++
		m.epochs[to] = m.seq
	}
	if len(p.made) == 0 {
		return m
	}
	m.parked = append([]*parked{p}, m.parked...)
	if len(m.parked) > parkedMost {
		for _, o := range m.parked[parkedMost:] {
			closeAll(o.made)
		}
		m.parked = m.parked[:parkedMost]
	}
	return m
}

// unpark brings back the screens kept of the workspace, under the epochs they were made with, and gives what asks
// those parked longer than parkedFresh to read again.
func (m Model) unpark(ws kit.Workspace) (Model, tea.Cmd) {
	// a group whose members changed since is not the place left: what was kept of it is closed
	m.parked = slices.DeleteFunc(slices.Clone(m.parked), func(p *parked) bool {
		stale := p.ws.Kind == ws.Kind && p.ws.Name == ws.Name && p.ws.Checkout == ws.Checkout && !same(p.ws, ws)
		if stale {
			closeAll(p.made)
		}
		return stale
	})
	at := slices.IndexFunc(m.parked, func(p *parked) bool { return same(p.ws, ws) })
	if at < 0 {
		return m, nil
	}
	p := m.parked[at]
	m.parked = slices.Delete(slices.Clone(m.parked), at, at+1)
	var cmds []tea.Cmd
	for to, s := range p.made {
		m.made[to], m.epochs[to] = s, p.epochs[to]
		if r, ok := s.(refreshing); ok && now().Sub(p.at) > parkedFresh {
			next, cmd := r.Refreshed()
			m.made[to] = next
			cmds = append(cmds, m.tag(to, cmd))
		}
	}
	return m, tea.Batch(cmds...)
}

// deliverParked gives an answer to the screen of a workspace kept that started it, by the epoch it was made under, and
// tags what the screen then starts the same; it is dropped when no screen kept has that epoch.
func (m Model) deliverParked(msg tagged) (tea.Model, tea.Cmd) {
	for _, p := range m.parked {
		if s, ok := p.made[msg.to]; ok && p.epochs[msg.to] == msg.epoch {
			next, cmd := s.Update(msg.msg)
			p.made[msg.to] = next
			return m, tag(msg.to, msg.epoch, cmd)
		}
	}
	return m, nil
}
