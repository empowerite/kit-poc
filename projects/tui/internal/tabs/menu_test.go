package tabs

import (
	"slices"
	"testing"

	"github.com/empowerite/kit/projects/tui/internal/shell"
)

// The items every tab's menu shares: Maximize, or Restore once maximized, on M; the folds, as table.Folding names
// them, > and < on the levels; and Select All on ctrl+a, then Clear Selection.
func TestTheTabsMenusShareTheirItems(t *testing.T) {
	if got := SizeItem(false); got != (shell.Item{Name: "Maximize", Keys: "M"}) {
		t.Errorf("not maximized: %+v", got)
	}
	if got := SizeItem(true); got != (shell.Item{Name: "Restore", Keys: "M"}) {
		t.Errorf("maximized: %+v", got)
	}
	folds := FoldItems()
	want := []shell.Item{{Name: "Show More", Keys: ">"}, {Name: "Show Less", Keys: "<"},
		{Name: "Show Selected"}, {Name: "Hide Selected"}}
	if len(folds) != len(want) {
		t.Fatalf("folds %+v", folds)
	}
	for k := range want {
		if folds[k] != want[k] {
			t.Errorf("fold %d: %+v, not %+v", k, folds[k], want[k])
		}
	}
	selects := SelectItems()
	if len(selects) != 2 || selects[0] != (shell.Item{Name: "Select All", Keys: "⌃A"}) ||
		selects[1] != (shell.Item{Name: "Clear Selection"}) {
		t.Errorf("selects %+v", selects)
	}
}

// The tab's menu draws no glyph: its lines are names, and the keys that do the same at their right.
func TestTheTabsMenusItemsCarryNoGlyph(t *testing.T) {
	items := slices.Concat([]shell.Item{SizeItem(false), SizeItem(true)}, FoldItems(), SelectItems())
	for _, item := range items {
		if item.Glyph != "" {
			t.Errorf("%q carries the glyph %q", item.Name, item.Glyph)
		}
	}
}
