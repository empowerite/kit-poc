// A dropdown is a menu that drops down from what it hangs from, as each of kittui's menus does. It holds whether it is
// open and the line under the keyboard; its lines, and which of them act, are its owner's, given to each call, since
// they follow what the screen shows. While it is open it has the keyboard: up and down move to the next line that acts,
// a line's shortcut chooses it, as it does with the menu closed, any other letter moves to the next line that starts
// with it, enter and space choose the line under the keyboard, and esc, or a key its
// owner names, closes it. A click on a line that acts chooses it, one on a line that does not does nothing, and one off
// the box closes it. A line that cannot act stays, dim, and the keyboard passes it by.
package shell

import (
	"slices"

	tea "charm.land/bubbletea/v2"
)

// Dropdown is a dropdown's own state: whether it is open, and the line under the keyboard, -1 for none. Path is the
// lines that opened the submenus now open, the root's first, none while only the root is; At is then a line of the
// deepest submenu.
type Dropdown struct {
	Open bool
	At   int
	Path []int
}

// Subs gives the lines of the submenu the path names, and which of them act: the line chosen at each level, from the
// root, that opened it. Its owner holds them, as it does the root's.
type Subs func(path []int) (items []Item, enabled func(int) bool)

// level gives the lines of the deepest open menu, and which of them act.
func (d Dropdown) level(items []Item, enabled func(int) bool, subs Subs) ([]Item, func(int) bool) {
	if len(d.Path) == 0 || subs == nil {
		return items, enabled
	}
	return subs(d.Path)
}

// opens gives the dropdown with the submenu of the line under the keyboard open, its first line that acts under the
// keyboard, when that line opens one and acts; else the dropdown as it was, and false.
func (d Dropdown) opens(items []Item, enabled func(int) bool, subs Subs) (Dropdown, bool) {
	here, on := d.level(items, enabled, subs)
	if subs == nil || d.At < 0 || d.At >= len(here) || !here[d.At].Opens || !on(d.At) {
		return d, false
	}
	d.Path = append(slices.Clone(d.Path), d.At)
	sub, subOn := subs(d.Path)
	d.At = Move(sub, subOn, -1, 1)
	return d, true
}

// closed gives the dropdown with its deepest submenu closed, the line that opened it under the keyboard, or, with none
// open, the dropdown closed.
func (d Dropdown) closed() Dropdown {
	if len(d.Path) == 0 {
		d.Open = false
		return d
	}
	d.At, d.Path = d.Path[len(d.Path)-1], slices.Clone(d.Path[:len(d.Path)-1])
	return d
}

// Opened gives the dropdown open, its first line that acts under the keyboard.
func (d Dropdown) Opened(items []Item, enabled func(int) bool) Dropdown {
	d.Open, d.At, d.Path = true, Move(items, enabled, -1, 1), nil
	return d
}

// Key takes a key while the dropdown is open, as the header says, and gives the dropdown and the line chosen, -1 for
// none. Choosing a line closes it, as esc and each of closes do.
func (d Dropdown) Key(k tea.KeyPressMsg, items []Item, enabled func(int) bool, closes ...string) (Dropdown, int) {
	d, path := d.KeyIn(k, items, enabled, nil, closes...)
	if path == nil {
		return d, -1
	}
	return d, path[0]
}

// KeyIn takes a key as Key does, for a menu with submenus, which subs gives: → and . and enter on a line that opens
// one and acts open it, ← closes the deepest, and esc does, or, with none open, closes the menu; up, down, a line's
// shortcut, and a letter act in the deepest open menu. It gives the dropdown and the path of the line chosen, the line
// at each level from the root, nil for none. → and . on a line that opens nothing do nothing.
func (d Dropdown) KeyIn(k tea.KeyPressMsg, items []Item, enabled func(int) bool, subs Subs, closes ...string) (Dropdown,
	[]int) {
	here, on := d.level(items, enabled, subs)
	switch key := k.String(); {
	case key == "up":
		d.At = Move(here, on, d.At, -1)
	case key == "down":
		d.At = Move(here, on, d.At, 1)
	case key == "right" || key == ".":
		d, _ = d.opens(items, enabled, subs)
	case key == "enter" || key == "space":
		if opened, ok := d.opens(items, enabled, subs); ok {
			return opened, nil
		}
		return d.chosen(d.At, here, on)
	case key == "left":
		if len(d.Path) > 0 {
			d = d.closed()
		}
	case key == "esc":
		d = d.closed()
	case slices.Contains(closes, key):
		d.Open, d.Path = false, nil
	case Shortcut(here, on, key) >= 0:
		return d.chosen(Shortcut(here, on, key), here, on)
	default:
		d.At = NextItem(here, on, d.At, k.Text)
	}
	return d, nil
}

// chosen gives the dropdown closed and the path of the line k of the deepest open menu, when it acts; a line that
// opens a submenu never acts itself; else the dropdown as it was, and none.
func (d Dropdown) chosen(k int, here []Item, on func(int) bool) (Dropdown, []int) {
	if k < 0 || k >= len(here) || !on(k) || here[k].Opens {
		return d, nil
	}
	path := append(slices.Clone(d.Path), k)
	d.Open, d.Path = false, nil
	return d, path
}

// Level is an open menu's lines, which of them act, where its box stands, and the first of its lines the box shows.
type Level struct {
	Items   []Item
	Enabled func(int) bool
	Box     Placed
	First   int
}

// ClickAt takes a left click while the dropdown is open, on the boxes of the levels open, the root's first: the
// deepest box the click falls on takes it. A line that acts and opens a submenu opens it, and closes those deeper than
// its level; one that acts is chosen, and gives its path; one that does not, or an edge, does nothing; and a click off
// every box closes the dropdown. It gives the dropdown and the path chosen, nil for none.
func (d Dropdown) ClickAt(x, y int, levels []Level, subs Subs) (Dropdown, []int) {
	for i := len(levels) - 1; i >= 0; i-- {
		l := levels[i]
		line, on := l.Box.Hit(x, y)
		if !on {
			continue
		}
		k := l.First + line
		if line < 0 || k >= len(l.Items) || !l.Enabled(k) {
			return d, nil
		}
		d.Path = slices.Clone(d.Path[:min(i, len(d.Path))])
		d.At = k
		if opened, ok := d.opens(levels[0].Items, levels[0].Enabled, subs); ok {
			return opened, nil
		}
		return d.chosen(k, l.Items, l.Enabled)
	}
	d.Open, d.Path = false, nil
	return d, nil
}

// Click takes a left click while the dropdown is open, drawn as a box so many cells wide, its top edge on the screen
// line top and its left edge in the column left, each line under the edge: on a line that acts, it chooses it; on
// another line of the box, it does nothing; off the box, it closes the dropdown. It gives the dropdown and the line
// chosen, -1 for none.
func (d Dropdown) Click(x, y, top, left, width int, items []Item, enabled func(int) bool) (Dropdown, int) {
	return d.ClickIn(x, y, top, left, width, 0, len(items), items, enabled)
}

// ClickIn takes a click as Click does, on a box that scrolls: its lines between the edges show so many of the lines,
// from first on.
func (d Dropdown) ClickIn(x, y, top, left, width, first, shown int, items []Item, enabled func(int) bool) (Dropdown,
	int) {
	k := y - top - 1
	if x > left && x < left+width-1 && k >= 0 && k < shown {
		return d.choose(first+k, items, enabled)
	}
	d.Open, d.Path = false, nil
	return d, -1
}

// choose gives the dropdown closed and the line k, when it acts; else the dropdown as it was, and -1.
func (d Dropdown) choose(k int, items []Item, enabled func(int) bool) (Dropdown, int) {
	if k < 0 || k >= len(items) || !enabled(k) || items[k].Opens {
		return d, -1
	}
	d.Open = false
	return d, k
}
