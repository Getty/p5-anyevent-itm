---
name: anyevent-itm-core
description: "Load before editing AnyEvent-ITM — the AnyEvent-based reader for ITM/SWD trace streams: module map, the custom 'itm' read type and its framing rules, the handle() and _run_cmd() entry points, the two shipped binaries, and the rough edges of this repository."
---

# AnyEvent::ITM — core

AnyEvent::ITM is a **thin AnyEvent layer on top of the ITM distribution**. The
decoding of the wire format — the 8-bit header byte, the type constants, the payload
rules — lives in `ITM` (the sibling repository `p5-itm`). This distribution adds
exactly two things: a custom AnyEvent read type that frames packets out of a byte
stream, and the plumbing to read that stream from a file, a pipe or a character
device, optionally alongside a running command whose output is timestamped.

One module, two scripts, two test files. No Moo, no object hierarchy.

| File | Role |
|---|---|
| `lib/AnyEvent/ITM.pm` | the module: the `itm` read type, `handle`, `_run_cmd`, `_print_ts`, `_ts` |
| `bin/itm_read_simple` | the reader script — prints instrumentation payloads as timestamped lines |
| `bin/itm_read_nocolor` | the same script without the color leftovers |
| `t/load.t` | the module loads |
| `t/simple.t` | nine packets through a real pipe, via the `itm` read type |
| `bundle.bat` | a Windows bundling script (PAR::Packer) |

## The `itm` read type

Loading the module registers a read type with `AnyEvent::Handle`:

```perl
$handle->push_read( itm => $callback );
```

The callback is called with `( $handle, $itm_object )`. The reader is registered
once per process at module load — it exists in every `AnyEvent::Handle` of the
process, whether or not this module is used for reading.

**The framing rules.** The reader looks at the handle's internal buffer (`rbuf`):

1. It takes the first byte as the header and decodes it with `itm_header` from the
   `ITM` distribution.
2. The header announces the payload size (0, 1, 2 or 4 bytes). The reader takes
   that many bytes after the header byte.
3. If the payload is not yet complete in the buffer, the reader returns `0` — AnyEvent
   keeps the buffer and calls again when more data arrives. Nothing is consumed.
4. Otherwise it parses the packet with `itm_parse($header, $payload)`, removes
   `1 + size` bytes from the buffer and calls the callback with the packet object.
5. It returns `1` — more packets may follow.

So the reader consumes exactly one packet per successful call and never consumes a
partial one.

## `handle($file, $callback, $cv)`

Opens `$file` and reads packets from it.

- a **pipe** (`-p $file`) is opened `O_RDWR | O_NONBLOCK` — read-write, so the other
  end stays open,
- a **character device** (`-c $file`, e.g. a serial line) gets `O_NOCTTY` on top of
  `O_RDONLY | O_NONBLOCK`,
- everything else is opened `O_RDONLY | O_NONBLOCK`.

The handle is created with three callbacks: `on_read` pushes the `itm` read type
again, `on_error` destroys the handle and sends `"$fatal: $message"` to the
condition variable, `on_eof` destroys the handle and sends `"EOF"`.

`$cv` is optional. Without it the method creates its own condition variable and
blocks on `recv` before returning the handle — the caller then only receives
packets through the callback. With a `$cv` the method returns immediately and the
caller waits itself.

## `_run_cmd(@cmd)`

Starts a command and reads its output. It opens two portable pipes, one for stdout
and one for stderr, and starts the command with `AnyEvent::Util::run_cmd`. Each
line that arrives is printed through `_print_ts` with the prefix `>` for stdout and
`2>` for stderr. The returned hashref holds the condition variable (`cv`), the
process handle (`proc`), the two pipe handles (`hout`, `herr`) and — once the
process ended — `exit_code` and, if the process was killed by a signal, `signal`.

The hashref must stay in scope: the process and the pipe handles live in it.

## `_print_ts($label, $line)` and `_ts()`

`_ts` returns the local time as `YYYY-MM-DD HH:MM:SS`. `_print_ts` prefixes a line
with that timestamp and the label, and prints to STDERR for the label `2>`, to STDOUT
for everything else.

## The binaries

Both scripts do the same thing: open the file with `AnyEvent::ITM->handle`, collect
the payloads of the instrumentation packets, and print them line by line — a
timestamped line per newline, with a trailing `\r` stripped, and the remaining
partial line flushed at EOF. They differ only in the color leftovers described
below.

The scripts compare the class of the packet with `ref($itm) eq 'ITM::Instrumentation'`
rather than asking the packet for its type. That is a workaround: the `type` method
of the `ITM` distribution currently dies on every packet class.

## Vocabulary

**Read type** — a named parser registered with `AnyEvent::Handle`; `itm` is this
distribution's.
**Push read** — arm a handle with a read type and a callback.
**rbuf** — the handle's internal read buffer; a read type consumes from it.
**Portable pipe** — `AnyEvent::Util::portable_pipe`, a pipe that works on Windows.
**Condition variable** — `AE::cv`, the rendezvous between the reader and the caller.
**Instrumentation packet** — a software `printf` from the target: payload plus
source port.
**Source port** — the 5-bit number that says which source produced the packet.

## Rough edges

Real, in the tree, and not fixed:

1. **`bin/itm_read_simple` is a copy of `bin/itm_read_nocolor` with dead color code.**
   It imports `Term::ANSIColor` and declares a 32-entry `our @colors` list — neither
   is ever used. The script colors nothing although its POD says "in colored form",
   and the `Term::ANSIColor` import breaks the script at compile time on a machine
   that does not have the module. It is not in the cpanfile.
2. **The binaries reach into private functions of another module:**
   `AnyEvent::ITM::_print_ts` and `AnyEvent::ITM::_run_cmd`. Two shipped programs
   depend on internals that are free to change.
3. **No `our $VERSION`** — not in `lib/AnyEvent/ITM.pm`, not in the two scripts.
   The distribution ships versionless.
4. **Hand-written SUPPORT sections** in the module and in both binaries. The release
   bundle generates that section itself, and `dist.ini` has no `irc` option, so the
   channel `#hardware` would be lost with the manual block.
5. **Dead code in the reader:** `$len` and `$f` are computed and never used, and
   `croak sprintf("unknown packet type")` is unreachable — `itm_header` never
   returns `undef`.
6. **`die` instead of `croak`** in `handle` (`sysopen $file: $!`) and in `_run_cmd`
   (`run_cmd: no command`).
7. **The cpanfile pins `'0'`** for `AnyEvent` and `ITM`, declares neither `Carp` nor
   `Fcntl`, and does not declare `Term::ANSIColor` although a shipped script imports
   it.
8. **`bundle.bat` calls `pp`** (PAR::Packer) — declared nowhere: not in the cpanfile,
   not in `dist.ini`.
9. **No `Changes`, no `LICENSE`, no `README.md`** — `dzil build` aborts on the
   missing `LICENSE`.
10. **No CI and no `xt/`** — Travis was removed in the last commit; the author tests
    only run locally.
11. **An empty buffer is read as an overflow packet.** `substr($rbuf, 0, 1)` on an
    empty buffer yields the empty string, `itm_header('')` warns about uninitialized
    values and falls through to the overflow branch.
12. **`my $file = shift or die`** refuses a file literally named `0`.

## Tests

`t/` holds two files: `t/load.t` (the module loads) and `t/simple.t` (nine packets
written into a pipe and read back through the `itm` read type — the real integration
path). `prove -lr t/` runs the suite: 25 tests.

Nothing tests `handle()` on a file, `_run_cmd`, `_print_ts` or either binary. A fix
for any of the rough edges needs a test that fails before it.
