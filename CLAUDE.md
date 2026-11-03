# CLAUDE.md

## Project Overview

AnyEvent::ITM reads **ITM/SWD instrumentation trace streams** inside an AnyEvent
event loop. It is a thin layer on top of the `ITM` distribution (the sibling
repository `p5-itm`), which decodes the wire format: this one frames packets out of
a byte stream and feeds them to a callback.

## Modules

- **AnyEvent::ITM** — the `itm` read type, `handle()` (open a file, pipe or device
  and read packets from it), `run_cmd()` (run a command alongside and timestamp
  its output), `print_ts()` and the internal `_ts()`
- **bin/itm_read_simple** — the reader script: prints instrumentation payloads as
  timestamped lines
- **bin/itm_read_nocolor** — the same reader under its second name

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

`t/` pins the read type (`load.t`, `simple.t`, `reader.t`), `handle()` (`handle.t`),
`run_cmd()` (`run_cmd.t`), both binaries (`scripts.t`), the `$VERSION` of every file
(`version.t`) and the cpanfile (`cpanfile.t`). `xt/` holds the perlcritic and POD
coverage author tests.

## Code Style

- plain Perl, no Moo: `use strict; use warnings;` and `croak` instead of `die`
- every file under `lib/` and `bin/` carries its own `our $VERSION`
- the release bundle generates the SUPPORT section (channel `#hardware` via `irc` in
  `dist.ini`) — never write it by hand

The conventions above are the short list; the binding ones live in the skills and are
force-loaded into the agents below. Do not restate them here.

## Delegation

Delegate behavior-relevant code to the right agent instead of touching it yourself —
the principle is a shared house rule (skilletor bundle `getty-cpan-dist@getty`); lanes and
the framing rules are in `.claude/rules/anyevent-itm-rules.md`.

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

- `prove -lr t/` is green. The tests cover the read type, `handle()`, `run_cmd()` and
  both binaries.
- `bin/itm_read_simple` and `bin/itm_read_nocolor` are the same reader under two
  names; neither imports `Term::ANSIColor`.
- The binaries call the public, documented `AnyEvent::ITM::print_ts` and
  `AnyEvent::ITM->run_cmd`.
- The module and both scripts carry `our $VERSION`; the release bundle rewrites it
  and generates the SUPPORT section. `Changes`, `LICENSE` and `README.md` are
  committed, CI runs through the shared `dzil-test` action of the bundle repository.
- The scripts recognise instrumentation packets by comparing `ref($itm)` with
  `ITM::Instrumentation`.
