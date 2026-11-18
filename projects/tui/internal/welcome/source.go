// Where the screen's words come from: the pages of the kit package, whatever repository the screen runs in.
package welcome

import (
	"cmp"
	"math"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"

	"github.com/empowerite/kit/projects/tui/internal/kit"
)

// pagesDir is where the pages live, under the kit package's files.
const pagesDir = ".kit/welcome"

// packageDir is the kit package's repository files, under the release's directory.
const packageDir = "packages/kit/files/repo"

// readPages gives the steps the pages make, as kit welcome --text finds them: every *.md under the kit package's
// .kit/welcome, never a repository's, as the screen depends on no repository. They are in the order of the number each
// name starts with, as kit welcome --text puts them, so 10-ours.md comes after 9-theirs.md; a name with no number comes
// last, and a tie goes by name. A page that cannot be read gives where it was looked for. When there is no page, the
// steps are the known ones, each saying where it was looked for.
func readPages(r kit.Runner) []tab {
	packaged := ""
	if root, err := r.Root(); err == nil && root != "" {
		packaged = filepath.Join(root, packageDir, pagesDir)
	}
	if tabs := readDir(packaged); len(tabs) > 0 {
		return tabs
	}
	where := pagesDir
	if packaged != "" {
		where = packaged
	}
	tabs := slices.Clone(known)
	for i := range tabs {
		tabs[i].missing = filepath.Join(where, tabs[i].file)
	}
	return tabs
}

// readDir gives the step of each page in a directory, in order: each file whose name ends in .md and does not start
// with a dot, as the shell's *.md matches.
func readDir(dir string) []tab {
	if dir == "" {
		return nil
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var files []string
	for _, e := range entries {
		if name := e.Name(); strings.HasSuffix(name, ".md") && !strings.HasPrefix(name, ".") {
			files = append(files, name)
		}
	}
	slices.SortFunc(files, func(a, b string) int {
		return cmp.Or(cmp.Compare(order(a), order(b)), strings.Compare(a, b))
	})
	tabs := make([]tab, len(files))
	for i, f := range files {
		tabs[i] = tabOf(f)
		tabs[i].page, tabs[i].missing = readPage(filepath.Join(dir, f))
	}
	return tabs
}

// readPage gives a page's markdown, or the path when it cannot be read.
func readPage(path string) (page, missing string) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", path
	}
	return string(data), ""
}

// order gives the number a page's file name starts with, or a number past every page's when it starts with none.
func order(name string) int {
	digits := name[:len(name)-len(strings.TrimLeft(name, "0123456789"))]
	if n, err := strconv.Atoi(digits); err == nil {
		return n
	}
	return math.MaxInt
}
