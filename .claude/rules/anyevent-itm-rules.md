# AnyEvent-ITM House Rules

The shared house rules come from skilletor — bundle `getty-cpan-dist@getty`: engineering
discipline, the delegation lock, the publish gate, karr coordination, CPAN release. They
load as `.claude/rules/.local.*.md`; if they are missing, run `skilletor sync` and publish
nothing until they load. This file adds what is true only here, and wins where it differs.

## What this repo is

Debug ITM/SWD stream deserializer for AnyEvent — the bridge between a byte stream and an
event loop. The documented behaviour is the contract; no fallbacks for features that do not
exist. Module map and entry points: skill `anyevent-itm-core`.

## Agent team

| Task | Agent |
|---|---|
| Implement / refactor / debug behavior-relevant code | `anyevent-itm-worker` (default) |
| Commits, `Changes`, card → done, pre-release audit | `anyevent-itm-release-manager` |
| Read-only research, audit, gap analysis | `anyevent-itm-worker` ("read-only, change nothing") |

Behavior-relevant = `lib/`, the binaries, the reader. README and `Changes` wording are not.

## The framing rules are the product — don't regress them silently

The name `itm` of the read type, the callback signature `($handle, $itm_object)`, the rule
that a successful read consumes exactly one packet, the rule that a partial packet is never
consumed, the non-blocking file modes of `handle()`, and the line output of the two shipped
binaries (`print_ts` and `run_cmd` are public, documented functions they use). A change to any of them needs a `Changes` entry and a test.

The wire format itself is **not** decoded here — that is the `ITM` distribution, the
sibling repository `p5-itm`. A defect in the decoding goes on that repository's board. Full
contract table: skill `anyevent-itm-core`.

## Perl specifics — reference, don't restate

Perl conventions live in the force-loaded skills; the module map, the framing rules and the
entry points live in skill `anyevent-itm-core`.
