package style

import "testing"

func TestTabNumbersAreCircledUntilToldOtherwise(t *testing.T) {
	if !IsCircled() {
		t.Fatal("tab numbers start plain")
	}
	t.Cleanup(func() { Circled(true) })
	Circled(false)
	if IsCircled() {
		t.Error("told plain, they are still circled")
	}
	Circled(true)
	if !IsCircled() {
		t.Error("told circled, they are still plain")
	}
}
