// A poll is a read that the screen asks for when it likes, and that asks again by itself a while after each answer.
// Its answer stands until the next. A read that fails keeps the last answer and goes on asking, each wait twice the one
// before while reads go on failing, up to eight times the while, and the first to fail before any answered does so too,
// so a forge that was slow at the start is read again; the screen resets the waits, as Refresh All does.
package source

import (
	"context"
	"time"

	tea "charm.land/bubbletea/v2"
)

// Poll is a read asked again a while after each answer: its last answer, and whether it has had one.
type Poll[T any] struct {
	Value  T
	Got    bool
	name   string
	every  time.Duration
	read   func(context.Context) (T, error)
	asking bool
	failed int // the reads that failed one after another
	serial int
}

// Took says what a message did to a poll.
type Took int

const (
	// NotMine is a message of another source, or none.
	NotMine Took = iota
	// Answered is a read's answer, which the poll now holds.
	Answered
	// Failed is a read that failed, the answer before it kept.
	Failed
	// Ticked is the poll's while passed, the read asked again when the wait was the latest.
	Ticked
)

// answer is what a poll's read brought: the poll's name, the answer, and why there is none.
type answer[T any] struct {
	name  string
	value T
	err   error
}

// tick says a poll's while has passed since the answer serial names.
type tick struct {
	name   string
	serial int
}

// NewPoll gives the poll named name, which no other source of its screen has, that read answers, asked again every
// while after each answer.
func NewPoll[T any](name string, every time.Duration, read func(context.Context) (T, error)) Poll[T] {
	return Poll[T]{name: name, every: every, read: read}
}

// Asking says whether a read is under way.
func (p Poll[T]) Asking() bool { return p.asking }

// Reset has a poll that failed wait its while again, not the longer one.
func (p *Poll[T]) Reset() { p.failed = 0 }

// wait gives how long the poll waits after an answer: its while, doubled for each read that failed before it, up to
// eight times.
func (p Poll[T]) wait() time.Duration { return p.every << min(max(p.failed-1, 0), 3) }

// Ask gives the read, unless one is under way, or the first read failed and the poll waits to try again, until it is
// reset; nil then.
func (p *Poll[T]) Ask(env Env) tea.Cmd {
	if p.failed > 0 && !p.Got {
		return nil
	}
	return p.ask(env)
}

// ask gives the read, unless one is under way; nil then.
func (p *Poll[T]) ask(env Env) tea.Cmd {
	if p.asking {
		return nil
	}
	p.asking = true
	name, read := p.name, p.read
	return func() tea.Msg {
		ctx, cancel := env.within(env.Ctx)
		defer cancel()
		value, err := read(ctx)
		return answer[T]{name, value, err}
	}
}

// Take takes a message that may be the poll's, and says what it did: an answer is kept, or, failed, the one before
// it, and the poll waits to ask again, a failed read as before any answered; a while that passed asks again, unless
// an answer came since the one it waited from.
func (p *Poll[T]) Take(env Env, msg tea.Msg) (tea.Cmd, Took) {
	switch msg := msg.(type) {
	case answer[T]:
		if msg.name != p.name {
			return nil, NotMine
		}
		p.asking = false
		took := Answered
		if msg.err == nil {
			p.Value, p.Got, p.failed = msg.value, true, 0
		} else {
			p.failed++
			took = Failed
		}
		p.serial++
		return env.after(p.wait(), tick{p.name, p.serial}), took
	case tick:
		if msg.name != p.name {
			return nil, NotMine
		}
		if msg.serial != p.serial {
			return nil, Ticked
		}
		return p.ask(env), Ticked
	}
	return nil, NotMine
}
