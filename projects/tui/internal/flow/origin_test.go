// Origin is read from git's remote URL in each of its shapes.
package flow

import (
	"os/exec"
	"testing"
)

func TestParseRemote(t *testing.T) {
	for url, want := range map[string]Origin{
		"https://github.com/empowerite/kit.git":   {Host: "github.com", Repo: "empowerite/kit"},
		"https://github.com/empowerite/kit":       {Host: "github.com", Repo: "empowerite/kit"},
		"ssh://git@github.com/empowerite/kit.git": {Host: "github.com", Repo: "empowerite/kit"},
		"git@gitlab.com:group/sub/kit.git":        {Host: "gitlab.com", Repo: "sub/kit"},
		"https://user@gitlab.example.com/a/b/c/":  {Host: "gitlab.example.com", Repo: "b/c"},
		"/home/someone/kit":                       {},
		"file:///home/someone/kit":                {Host: "", Repo: ""},
		"https://github.com/kit":                  {},
		"":                                        {},
	} {
		if got := parseRemote(url); got != want {
			t.Errorf("parseRemote(%q) = %+v, want %+v", url, got, want)
		}
	}
}

func TestReadOriginAsksGit(t *testing.T) {
	dir := t.TempDir()
	if got := ReadOrigin(dir); got != (Origin{}) {
		t.Errorf("no repository: %+v", got)
	}
	for _, args := range [][]string{{"init", "-q"}, {"remote", "add", "origin", "git@github.com:empowerite/kit.git"}} {
		if out, err := exec.Command("git", append([]string{"-C", dir}, args...)...).CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v\n%s", args, err, out)
		}
	}
	if got := ReadOrigin(dir); got != (Origin{Host: "github.com", Repo: "empowerite/kit"}) {
		t.Errorf("ReadOrigin: %+v", got)
	}
}
