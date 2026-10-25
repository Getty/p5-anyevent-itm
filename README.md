# AnyEvent::ITM

Reads ITM/SWD instrumentation trace streams inside an AnyEvent event loop. It
is a thin layer on top of the `ITM` distribution, which decodes the wire
format: this one frames packets out of a byte stream and hands them to a
callback.

```perl
use AnyEvent;
use AnyEvent::ITM;

my $cv = AE::cv;
AnyEvent::ITM->handle( '/dev/ttyACM0', sub {
  my ( $handle, $itm ) = @_;
  print $itm->payload if ref($itm) eq 'ITM::Instrumentation';
}, $cv );
warn $cv->recv;
```

Loading the module registers the `itm` read type with `AnyEvent::Handle`;
`$handle->push_read( itm => $callback )` consumes exactly one packet per call
and never a partial one.

## Scripts

- `itm_read_simple` - prints the instrumentation payloads of a file, pipe or
  device as timestamped lines
- `itm_read_nocolor` - the same reader

Both take the file as first argument and an optional command to run
alongside, whose output is timestamped too.

## Documentation

The POD of `AnyEvent::ITM` and of both scripts is the reference:
`perldoc AnyEvent::ITM`.

## Installation

    cpanm --installdeps .
    prove -lr t/

## Support

IRC: `#hardware` on irc.perl.org.

## License

This software is copyright (c) 2015 by Torsten Raudssus. It is free software;
you can redistribute it and/or modify it under the same terms as the Perl 5
programming language system itself.
