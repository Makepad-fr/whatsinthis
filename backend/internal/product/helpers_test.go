package product

import "testing"

func TestLookupCandidates(t *testing.T) {
	got := LookupCandidates("0 1234567890123")
	want := []string{"01234567890123", "1234567890123"}

	if len(got) != len(want) {
		t.Fatalf("len = %d, want %d", len(got), len(want))
	}
	for index := range want {
		if got[index] != want[index] {
			t.Fatalf("candidate[%d] = %q, want %q", index, got[index], want[index])
		}
	}
}
