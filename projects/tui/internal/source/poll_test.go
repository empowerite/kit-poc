// A poll keeps its answer and asks again a while after each; a failure keeps the last answer, and one before any
// answered is asked again after a wait that grows until it is reset; a while that passed asks again only when it is
// the latest; and the program's clock is a tea.Tick.
package source

import (
	"context"
	"errors"
	"testing"
	"time"

	tea "charm.land/bubbletea/v2"

	"github.com/empowerite/kit/projects/tui/internal/testkit"
)

// reads gives a poll's read that answers each of answers in turn, an empty one failing, and counts its reads.
func reads(answers ...string) (func(context.Context) (string, error), *int) {
	n := 0
	return func(context.Context) (string, error) {
		a := answers[min(n, len(answers)-1)]
		n++
		if a == "" {
			return "", errors.New("no")
		}
		return a, nil
	}, &n
}

func TestAPollKeepsItsAnswerAndAsksAgainAWhileAfter(t *testing.T) {
	clock := &testkit.Clock{}
	env := Env{Ctx: context.Background(), Limit: time.Second, Clock: clock}
	read, n := reads("one", "", "two")
	p := NewPoll("p", time.Minute, read)
	ask := p.Ask(env)
	if ask == nil || !p.Asking() || p.Ask(env) != nil {
		t.Fatalf("the first ask: %v, asking %v", ask != nil, p.Asking())
	}
	if cmd, took := p.Take(env, ask()); cmd != nil || took != Answered || p.Value != "one" || !p.Got || p.Asking() {
		t.Fatalf("the answer: %v %v %+v", cmd != nil, took, p)
	}
	timers := clock.Timers()
	if len(timers) != 1 || timers[0].After != time.Minute {
		t.Fatalf("the wait: %+v", timers)
	}
	// the while passes: the poll asks again, and a failure keeps the answer and waits again
	again, took := p.Take(env, clock.Fire()[0])
	if again == nil || took != Ticked {
		t.Fatalf("the while: %v %v", again != nil, took)
	}
	if _, took := p.Take(env, again()); took != Failed || p.Value != "one" || len(clock.Timers()) != 1 {
		t.Errorf("a failure after an answer: %v %+v, %d timers", took, p, len(clock.Timers()))
	}
	stale := clock.Fire()[0]
	if _, took := p.Take(env, p.Ask(env)()); took != Answered || p.Value != "two" || *n != 3 {
		t.Errorf("the third read: %v %+v", took, p)
	}
	// a while waited from an earlier answer asks nothing
	if cmd, took := p.Take(env, stale); cmd != nil || took != Ticked {
		t.Errorf("an earlier while: %v %v", cmd != nil, took)
	}
	// another poll's messages, and others, are not this one's
	other := NewPoll("q", time.Minute, read)
	for _, msg := range []tea.Msg{other.Ask(env)(), tick{"q", 1}, "nothing"} {
		if cmd, took := p.Take(env, msg); cmd != nil || took != NotMine {
			t.Errorf("%#v: %v %v", msg, cmd != nil, took)
		}
	}
}

// A poll whose first read fails waits and asks again, each wait twice the one before up to eight times the while, and
// is back to its while after an answer or a reset.
func TestAPollWhoseFirstReadFailsAsksAgainAfterAGrowingWait(t *testing.T) {
	clock := &testkit.Clock{}
	env := Env{Ctx: context.Background(), Limit: time.Second, Clock: clock}
	read, _ := reads("", "", "", "", "", "", "", "one", "")
	p := NewPoll("p", time.Minute, read)
	ask := p.Ask(env)
	for _, want := range []time.Duration{1, 2, 4, 8, 8} {
		_, took := p.Take(env, ask())
		timers := clock.Timers()
		if took != Failed || p.Got || len(timers) != 1 || timers[0].After != want*time.Minute {
			t.Fatalf("a failure: %v %+v, waits %+v", took, p, timers)
		}
		var ticked Took
		if ask, ticked = p.Take(env, clock.Fire()[0]); ask == nil || ticked != Ticked {
			t.Fatalf("the while: %v %v", ask != nil, ticked)
		}
	}
	p.Take(env, ask())
	clock.Fire()
	p.Reset()
	if _, took := p.Take(env, p.Ask(env)()); took != Failed || clock.Timers()[0].After != time.Minute {
		t.Errorf("after a reset: %v %+v", took, clock.Timers())
	}
	if p.Ask(env) != nil {
		t.Error("a screen asked a poll that waits to try again")
	}
	ask, _ = p.Take(env, clock.Fire()[0])
	if _, took := p.Take(env, ask()); took != Answered || p.Value != "one" || !p.Got {
		t.Errorf("an answer: %v %+v", took, p)
	}
	if _, took := p.Take(env, p.Ask(env)()); took != Failed || clock.Timers()[0].After != time.Minute {
		t.Errorf("a failure after an answer: %v %+v", took, clock.Timers())
	}
}

// A read is cut off at the env's limit, as its context ends; with none, it runs as long as the env's context.
func TestAReadEndsAtTheLimit(t *testing.T) {
	p := NewPoll("p", time.Minute, func(ctx context.Context) (string, error) {
		<-ctx.Done()
		return "", ctx.Err()
	})
	msg := p.Ask(Env{Ctx: context.Background(), Limit: time.Millisecond})()
	if a := msg.(answer[string]); !errors.Is(a.err, context.DeadlineExceeded) {
		t.Errorf("the read: %+v", a)
	}
}

// Without a clock, a wait is the program's, a tea.Tick, which brings its message once it has passed.
func TestTheProgramsClockTicks(t *testing.T) {
	if msg := (Env{}).after(time.Millisecond, "done")(); msg != "done" {
		t.Errorf("the tick brought %v", msg)
	}
	if msg := (Ticks{}).After(time.Millisecond, "done")(); msg != "done" {
		t.Errorf("Ticks brought %v", msg)
	}
}

func TestAReadWithNoLimitRunsAsLongAsTheContext(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	p := NewPoll("p", time.Minute, func(ctx context.Context) (string, error) {
		if _, ok := ctx.Deadline(); ok {
			return "", errors.New("a deadline")
		}
		cancel()
		<-ctx.Done()
		return "ended", nil
	})
	if a := p.Ask(Env{Ctx: ctx})().(answer[string]); a.value != "ended" || a.err != nil {
		t.Errorf("the read: %+v", a)
	}
}
