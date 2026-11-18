// Where origin points, read from git: what the workspace menu names, and the repository a row is read in, until kit
// says the workspace. No page is built from it: a row opens the page kit printed, which the forge's provider gives.
package flow

import (
	"os/exec"
	"strings"
)

// Origin is where origin points: its host, and its owner/repo path. Both are empty when git cannot say.
type Origin struct {
	Host, Repo string
}

// ReadOrigin asks git for origin's URL in dir, which touches no network, and reads the host and the path from it.
func ReadOrigin(dir string) Origin {
	out, err := exec.Command("git", "-C", dir, "remote", "get-url", "origin").Output()
	if err != nil {
		return Origin{}
	}
	return parseRemote(strings.TrimSpace(string(out)))
}

// parseRemote reads a remote's host and owner/repo from its URL: https://host/owner/repo.git, ssh://git@host/owner/
// repo, or git@host:owner/repo. A URL with fewer than two path segments gives nothing.
func parseRemote(url string) Origin {
	host, path := "", ""
	if _, rest, ok := strings.Cut(url, "://"); ok {
		host, path, _ = strings.Cut(rest, "/")
	} else if user, rest, ok := strings.Cut(url, ":"); ok {
		host, path = user, rest
	} else {
		return Origin{}
	}
	if _, after, ok := strings.Cut(host, "@"); ok {
		host = after
	}
	path = strings.TrimSuffix(strings.Trim(path, "/"), ".git")
	segments := strings.Split(path, "/")
	if len(segments) < 2 || host == "" {
		return Origin{}
	}
	return Origin{Host: host, Repo: strings.Join(segments[len(segments)-2:], "/")}
}
