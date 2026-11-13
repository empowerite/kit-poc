// The contract of kit's stage documents: a stage refuses a document that states another than the catalog reads, and
// reads one that states the catalog's, or none.
package flow

import (
	"fmt"
	"testing"
)

func TestAStageRefusesADocumentOfAnotherContractAndReadsOneThatStatesNone(t *testing.T) {
	if contract < 1 {
		t.Fatalf("fields.json states contract %d", contract)
	}
	refusal := func(stated string) string {
		return fmt.Sprintf("%s printed contract %s of the stage documents, and this kittui reads contract %d; run kit "+
			"and kittui from one release", command("workspace/tags"), stated, contract)
	}
	// another number, and anything that is no number, is another contract; the refusal comes before the shape's, and
	// leaves the stage as it was
	later := fmt.Sprint(contract + 1)
	for doc, want := range map[string]string{
		`{"contract": ` + later + `, "rows": [{"key": "a"}], "errors": []}`: refusal(later),
		`{"contract": 0, "rows": [{"key": "a"}], "errors": []}`:             refusal("0"),
		fmt.Sprintf(`{"contract": "%d", "rows": [{"key": "a"}]}`, contract): refusal(fmt.Sprintf(`"%d"`, contract)),
		`{"contract": ` + later + `, "tags": [{"key": "a"}]}`:               refusal(later),
	} {
		s := stage{name: "workspace/tags"}
		if err := s.decode([]byte(doc), false); err == nil || err.Error() != want || s.rows != nil {
			t.Errorf("%s: %v, %d rows", doc, err, len(s.rows))
		}
	}
	// the catalog's contract, none, and null are read, in one repository and over a group
	for _, doc := range []string{
		fmt.Sprintf(`{"contract": %d, "rows": [{"key": "a"}], "errors": []}`, contract),
		`{"rows": [{"key": "a"}], "errors": []}`,
		`{"contract": null, "rows": [{"key": "a"}], "errors": []}`,
	} {
		for _, over := range []bool{false, true} {
			s := stage{name: "workspace/tags"}
			if err := s.decode([]byte(doc), over); err != nil || len(s.rows) != 1 {
				t.Errorf("%s, over a group %v: %v, %d rows", doc, over, err, len(s.rows))
			}
		}
	}
	// an array holds no place for a contract, and states none
	s := stage{name: "issues"}
	if err := s.decode([]byte(`[{"number": 1}]`), false); err != nil || len(s.rows) != 1 {
		t.Errorf("an array: %v, %d rows", err, len(s.rows))
	}
	if stated, ok := contractOf([]byte(`[{"contract": 2}]`)); ok || stated != "" {
		t.Errorf("an array states contract %q", stated)
	}
}
