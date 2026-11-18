// The tab's menu every screen with tabs drops down from the selected tab's :, the items each screen's menu shares: the
// tab maximized and restored, its source read again, the outline of a tab drawn as a table shown a level more and
// less, and its rows selected, every one and none.
package tabs

import (
	"github.com/empowerite/kit/projects/tui/internal/shell"
)

// SizeItem gives the tab's menu's item that maximizes the tab, or, maximized, restores it: M, either way.
func SizeItem(maximized bool) shell.Item {
	if maximized {
		return shell.Item{Name: "Restore", Keys: "M"}
	}
	return shell.Item{Name: "Maximize", Keys: "M"}
}

// FoldItems gives the tab's menu's items that show and hide a table's outline, as table.Folding names them: a level
// more of the whole table and a level less, as > and < do, and the selected rows shown, every heading over them too,
// and hidden.
func FoldItems() []shell.Item {
	return []shell.Item{{Name: "Show More", Keys: ">"}, {Name: "Show Less", Keys: "<"},
		{Name: "Show Selected"}, {Name: "Hide Selected"}}
}

// SelectItems gives the tab's menu's items that select a table's rows: every one, as ctrl+a does, and none.
func SelectItems() []shell.Item {
	return []shell.Item{{Name: "Select All", Keys: "⌃A"}, {Name: "Clear Selection"}}
}
