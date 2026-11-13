package flow

// OnBar says whether the stages' bar has the keyboard: it is the last control on the path to the keyboard, which the
// keys bar is drawn from, so no menu, dialog, or popover is open, and the keyboard is not in the search, on the
// control line, or in the rows. kittui's root takes q there as ⌃Q, which quits.
func (m Model) OnBar() bool { return len(m.keys()) == 2 }
