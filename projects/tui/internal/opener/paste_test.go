package opener

import "testing"

// A paste is typed after what is typed, as a key is: kit's line goes, and the highlight is back on what is typed. A
// paste of nothing changes nothing.
func TestOpenTypesAPasteAfterWhatIsTyped(t *testing.T) {
	d := typedIn(newOpen("/", "/home"), "srv")
	d.Refusal, d.At = "kit refused", 1
	if d = d.Paste("-a/code"); d.Typed != "/srv-a/code" || d.Refusal != "" || d.At != 0 {
		t.Errorf("a paste after /srv: %q, refusal %q, at %d", d.Typed, d.Refusal, d.At)
	}
	d.Refusal = "kit refused"
	if d = d.Paste(""); d.Typed != "/srv-a/code" || d.Refusal != "kit refused" {
		t.Errorf("a paste of nothing: %q, refusal %q", d.Typed, d.Refusal)
	}
}

// A paste that starts with / or ~ is a whole path, which can mean nothing after what is typed, so it takes its place:
// the dialog opens on ~/, and a pasted /srv/code is /srv/code there, never ~//srv/code. A / or a ~ further on in a
// paste is typed as it is.
func TestOpenTakesAPastedWholePathInPlaceOfWhatIsTyped(t *testing.T) {
	for pasted, want := range map[string]string{
		"/srv/code":   "/srv/code",
		"~/Code/kit":  "~/Code/kit",
		"~":           "~",
		"Code/kit":    "~/Code/kit",
		"Code/~/kit/": "~/Code/~/kit/",
	} {
		d := newOpen("", "/home")
		d.Refusal, d.At = "kit refused", 1
		if d = d.Paste(pasted); d.Typed != want || d.Refusal != "" || d.At != 0 {
			t.Errorf("a paste of %q after ~/: %q, refusal %q, at %d", pasted, d.Typed, d.Refusal, d.At)
		}
	}
	if d := typedIn(newOpen("/", "/home"), "srv").Paste("/code"); d.Typed != "/code" {
		t.Errorf("a paste of /code after /srv: %q", d.Typed)
	}
}

// Over the clones, a paste goes back to the folders and is typed, as a key the table does not take is; a name typed
// for a preset on the clones' table takes it, and the groups' dropdown lets none through.
func TestOverTheClonesAPasteIsTypedWhereAKeyWouldBe(t *testing.T) {
	dir := cloneTree(t)
	d := found(t, dir, group(dir))
	typed := d.Typed
	if back := d.Paste("a"); back.found != nil || back.table != nil || back.Typed != typed+"a" {
		t.Errorf("a paste over the clones: %q, the clones kept %v", back.Typed, back.found != nil)
	}
	dropped, _ := d.Key(key("+"))
	if !dropped.adding.Open {
		t.Fatal("+ drops no groups down")
	}
	if under := dropped.Paste("a"); under.found == nil || under.Typed != typed || !under.adding.Open {
		t.Errorf("a paste under the groups: %q, the clones kept %v", under.Typed, under.found != nil)
	}
	d.table.Focus()
	d.table.Table().SavingAs = true
	if named := d.Paste("mine"); named.found == nil || named.Typed != typed || named.table.Table().Naming != "mine" {
		t.Errorf("a paste in a preset's name: %q, typed %q", named.table.Table().Naming, named.Typed)
	}
}
