# CLAUDE.md

## Project Overview

AnyEvent::ITM reads **ITM/SWD instrumentation trace streams** inside an AnyEvent
event loop. It is a thin layer on top of the `ITM` distribution (the sibling
repository `p5-itm`), which decodes the wire format: this one frames packets out of
a byte stream and feeds them to a callback.

## Modules

- **AnyEvent::ITM** — the `itm` read type, `handle()` (open a file, pipe or device
  and read packets from it), `_run_cmd()` (run a command alongside and timestamp
  its output), `_print_ts()` and `_ts()`
- **bin/itm_read_simple** — the reader script: prints instrumentation payloads as
  timestamped lines
- **bin/itm_read_nocolor** — the same script without the color leftovers

## The contract

- the read type is named `itm`; the callback gets `($handle, $itm_object)`
- a successful read consumes exactly one packet: one header byte plus the payload
  the header announces; a partial packet is never consumed
- `handle()` opens pipes read-write, character devices without a controlling
  terminal, everything else read-only — always non-blocking
- the scripts print one timestamped line per newline, strip a trailing carriage
  return and flush the partial last line at EOF

## Testing

```bash
prove -lr t/
```

Two files: `load.t` (the module loads) and `simple.t` (nine packets through a real
pipe via the `itm` read type). There is no `xt/` — no perlcritic, no pod coverage.

## Code Style

- plain Perl, no Moo: `use strict; use warnings;` and `croak` instead of `die`
- every file under `lib/` and `bin/` carries its own `our $VERSION`
- the release bundle generates the SUPPORT section — never write it by hand

The conventions above are the short list; the binding ones live in the skills and are
force-loaded into the agents below. Do not restate them here.

## Delegation

Delegate behavior-relevant code to the right agent instead of touching it yourself —
principle and lane are in `.claude/rules/anyevent-itm-rules.md`.

| Task | Agent |
|---|---|
| Implement / refactor / debug behavior-relevant code | `anyevent-itm-worker` (default) |
| Commits, `Changes`, card → done, pre-release audit | `anyevent-itm-release-manager` |

Only the release-manager commits; a worker leaves a commit-ready tree and a report.

The agents carry their skills via `briefing.skills` (see `.claude/agents/`); the main
agent delegates rather than loading them. The shared skills under `.claude/skills/`
are **installed** from the Getty library by skilletor — they are not edited here.
`anyevent-itm-core` is the one skill this repo owns: module map, the framing rules
of the read type, the entry points and the known rough edges.

## State of the code

- The suite is green — `prove -lr t/` runs two files, 25 tests — but it covers only
  the read type; `handle()`, `_run_cmd()` and the binaries are untested.
- `bin/itm_read_simple` is a copy of `bin/itm_read_nocolor` with a dead color
  block: it imports `Term::ANSIColor` and keeps a 32-entry color list, uses
  neither, and colors nothing although its POD says otherwise.
- The binaries call private functions of the module: `_print_ts` and `_run_cmd`.
- No file carries an `our $VERSION`; the module and both scripts carry a
  hand-written SUPPORT section, and `dist.ini` has no `irc` option.
- There is no `Changes`, no `LICENSE` (so `dzil build` aborts), no `README.md`, no
  CI — Travis was removed in the last commit.
- The scripts work around a defect in the sibling distribution: they compare
  `ref($itm)` instead of asking the packet for its type.
