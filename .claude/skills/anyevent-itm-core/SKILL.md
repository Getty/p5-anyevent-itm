---
name: anyevent-itm-core
description: "Load before editing AnyEvent-ITM — the AnyEvent-based reader for ITM/SWD trace streams: module map, the custom 'itm' read type and its framing rules, the handle() and run_cmd() entry points, the two shipped binaries, and the rough edges of this repository."
---

# AnyEvent::ITM — core

AnyEvent::ITM is a **thin AnyEvent layer on top of the ITM distribution**. The
decoding of the wire format — the 8-bit header byte, the type constants, the payload
rules — lives in `ITM` (the sibling repository `p5-itm`). This distribution adds
exactly two things: a custom AnyEvent read type that frames packets out of a byte
stream, and the plumbing to read that stream from a file, a pipe or a character
device, optionally alongside a running command whose output is timestamped.

One module, two scripts. No Moo, no object hierarchy.

| File | Role |
|---|---|
| `lib/AnyEvent/ITM.pm` | the module: the `itm` read type, `handle`, `run_cmd`, `print_ts`, `_ts` |
| `bin/itm_read_simple` | the reader script — prints instrumentation payloads as timestamped lines |
| `bin/itm_read_nocolor` | the same reader under its second name |
| `t/` | `load.t`, `simple.t`, `reader.t` (read type), `handle.t`, `run_cmd.t`, `scripts.t` (binaries), `version.t`, `cpanfile.t` |
| `xt/` | `perlcritic.t`, `pod.t` (author tests) |
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

## `run_cmd(@cmd)`

Starts a command and reads its output. It opens two portable pipes, one for stdout
and one for stderr, and starts the command with `AnyEvent::Util::run_cmd`. Each
line that arrives is printed through `print_ts` with the prefix `>` for stdout and
`2>` for stderr. The returned hashref holds the condition variable (`cv`), the
process handle (`proc`), the two pipe handles (`hout`, `herr`) and — once the
process ended — `exit_code` and, if the process was killed by a signal, `signal`.

The hashref must stay in scope: the process and the pipe handles live in it.

## `print_ts($label, $line)` and `_ts()`

`_ts` (internal) returns the local time as `YYYY-MM-DD HH:MM:SS`. `print_ts` (public, a plain function) prefixes a line
with that timestamp and the label, and prints to STDERR for the label `2>`, to STDOUT
for everything else.

## The binaries

Both scripts do the same thing: open the file with `AnyEvent::ITM->handle`, collect
the payloads of the instrumentation packets, and print them line by line — a
timestamped line per newline, with a trailing `\r` stripped, and the remaining
partial line flushed at EOF. They differ only in name and POD.

The scripts recognise instrumentation packets by comparing `ref($itm)` with
`'ITM::Instrumentation'`. They use `AnyEvent::ITM::print_ts` and
`AnyEvent::ITM->run_cmd`.

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

1. **`bundle.bat` calls `pp`** (PAR::Packer), declared under `on develop` in the
   cpanfile.
2. **The binaries check their file argument with `defined`**, so a file named `0`
   is accepted; `t/reader.t` pins it.

## Tests

`prove -lr t/` runs the suite: `load.t`, `simple.t` and `reader.t` pin the read type
(nine packets through a real pipe, empty buffer, partial packet, one packet per read),
`handle.t` the file modes and the `EOF` / `"$fatal: $message"` signals, `run_cmd.t` the
exit code and signal, `scripts.t` both binaries, `version.t` the `$VERSION` of every
file under `lib/` and `bin/`, `cpanfile.t` the declared dependencies. `xt/` holds the
perlcritic and POD coverage tests. A fix leaves a test that fails before it.
