# Slate

A native macOS recreation of the Windows 10 Notepad UI, rebuilt the
"agentic" way: the app code is written by a fleet of LLM coding
agents driven by an external orchestrator. This repo holds the
product spec (`PRD.md`), the bug catalogue that shaped it
(`lessons-learned.md`), and the project-specific glue under
`.agent/`. **No application code yet** — it gets written into
`Slate/` once the loop starts iterating.

## Toolchain

The agent runner lives in its own repo:

- **[007-builder](https://github.com/samantha-network4all-bot/007-builder)**
  — project-agnostic Go binary that drives the `code → build →
  feature-test → quality-review` loop.

Slate ships only its PRD, its prompt templates, and a YAML config
pointing 007-builder at this repo.

## Quickstart

```
# 1. Install builder (one-time)
git clone https://github.com/samantha-network4all-bot/007-builder.git ~/src/007-builder
go -C ~/src/007-builder build -o ~/bin/builder ./cmd/builder

# 2. From this repo
cd ~/Documents/bimboware/slate
builder bootstrap     # creates samantha-network4all-bot/slate-v2 + seed commit
builder loop          # iterative build until PRD §1–§6 are covered
```

## How it works

1. **Bootstrap** creates `samantha-network4all-bot/slate-v2` on
   GitHub, writes the seed Swift project (just enough to launch a
   window and serve `GET /healthz` on a local HTTP port when
   `SLATE_TEST_API=1`), and pushes the first commit.
2. **next-issue** asks an LLM, given `PRD.md` and the list of
   closed `slice` issues, for the next smallest user-visible
   vertical slice. Opens a GitHub issue with title `Sn: …` and a
   JSON `acceptance:` list of HTTP probes that prove the slice
   works.
3. **work** picks the oldest open `slice` issue, runs the code
   agent (pi/claude shell-out) to implement it, then runs both
   checks locally. On failure it re-invokes with failure context,
   up to **10** attempts. After 10, a PR is opened with label
   `awaiting-human-review` and the loop halts.
4. **check quality** is an LLM code review (read-only tools).
   Files blocking comments on the PR if it finds anything that
   violates PRD §8 invariants.
5. **check feature** builds the app, launches it with
   `SLATE_TEST_API=1`, polls `/healthz`, then runs the issue's
   `acceptance:` probes as HTTP calls + assertions.

## Why no mouse/keyboard automation?

We tried. `osascript` keystrokes need Accessibility granted to
Terminal, and silently no-op when they aren't. The previous QA
harness thought the app worked while typing did nothing and ⌘O
crashed the app. See [`lessons-learned.md`](./lessons-learned.md).
Slate's contract: every testable behavior MUST be reachable
through the local HTTP API documented in PRD §7.

## Layout

```
.
├── PRD.md                  — locked product spec
├── lessons-learned.md      — what the old notepad/ repo taught us
├── .agent/
│   ├── config.yaml         — pointers builder reads on startup
│   └── prompts/
│       ├── PROMPT-code.tmpl
│       ├── PROMPT-quality.tmpl
│       └── PROMPT-next-issue.tmpl
└── (Slate/, Project.yml — created by `builder bootstrap`)
```
