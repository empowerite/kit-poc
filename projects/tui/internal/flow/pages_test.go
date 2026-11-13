// A row of issues or changes opens the page kit printed for it, its forge's provider's own, and kittui builds none: a
// row kit gave no page leads nowhere, whatever origin is.
package flow

import (
	"slices"
	"testing"

	tea "charm.land/bubbletea/v2"
)

// elsewhereHosted is kit's issues on a forge whose pages origin's last two path segments do not give: an issue in the
// backlog of a GitLab subgroup's project, one underway there, its merge request's page beside it, and one kit gave
// no page.
const elsewhereHosted = `[
  {"number": 7, "ref": "#7", "title": "seven", "status": "backlog", "source": "gitlab",
   "url": "https://gitlab.com/group/sub/kit/-/issues/7"},
  {"number": 8, "ref": "#8", "title": "eight", "status": "underway", "source": "gitlab",
   "url": "https://gitlab.com/group/sub/kit/-/issues/8",
   "pr": {"number": 3, "source": "gitlab", "state": "ready", "author": "ada",
          "url": "https://gitlab.com/group/sub/kit/-/merge_requests/3"}},
  {"number": 9, "ref": "#9", "title": "nine", "status": "underway", "source": "gitlab",
   "pr": {"number": 4, "source": "gitlab", "state": "ready", "author": "ada"}}]`

func TestAnIssuesRowOpensThePageKitPrinted(t *testing.T) {
	// origin is known, and is another place than the pages kit printed: no page is built from it
	o := options()
	o.Stages = []string{"issues"}
	m := drive(New(runner(t), o), tea.WindowSizeMsg{Width: 120, Height: 40}, answer("issues", elsewhereHosted))
	got := map[string][2]string{}
	for _, r := range m.records(m.stages[0]) {
		got[r.Key] = [2]string{r.values["title"].Link, r.values["state"].Link}
	}
	const page = "https://gitlab.com/group/sub/kit/-/"
	want := map[string][2]string{
		"#7":    {page + "issues/7", ""},
		"#8 #3": {page + "issues/8", page + "merge_requests/3"},
		"#9 #4": {"", ""},
	}
	for key, w := range want {
		if got[key] != w {
			t.Errorf("%s leads to %q, want %q", key, got[key], w)
		}
	}
}

func TestAChangesRowOpensThePageKitPrinted(t *testing.T) {
	o := options()
	o.Stages = []string{"changes"}
	m := drive(New(runner(t), o), tea.WindowSizeMsg{Width: 120, Height: 40}, answer("changes", `[
	  {"number": 7, "ref": "!7", "title": "seven", "state": "ready", "source": "ado",
	   "url": "https://dev.azure.com/acme/Claims/_git/policy/pullrequest/7"},
	  {"number": 8, "ref": "!8", "title": "eight", "state": "ready", "source": "ado"}]`))
	var got [][2]string
	for _, r := range m.records(m.stages[0]) {
		got = append(got, [2]string{r.values["change"].Link, r.values["state"].Link})
	}
	const page = "https://dev.azure.com/acme/Claims/_git/policy/pullrequest/7"
	if want := [][2]string{{page, page}, {"", ""}}; !slices.Equal(got, want) {
		t.Errorf("the changes lead to %q, want %q", got, want)
	}
}

// Copy Links copies each selected issue's own page, as kit printed it: for an issue underway, never the page of the
// pull request that closes it, which its row's cells hold before the title's.
func TestCopyLinksCopiesAnIssueUnderwaysOwnPage(t *testing.T) {
	o := options()
	o.Stages = []string{"issues"}
	m := drive(New(runner(t), o), tea.WindowSizeMsg{Width: 120, Height: 40}, answer("issues", elsewhereHosted))
	m.stages[0].Picked = map[string]bool{"#8 #3": true, "#9 #4": true}
	want := "- [#8 eight](https://gitlab.com/group/sub/kit/-/issues/8)\n- #9 nine"
	if got := m.links(); got != want {
		t.Errorf("the links copied: %q, want %q", got, want)
	}
}
