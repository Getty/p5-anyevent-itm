package AnyEvent::ITM;
# ABSTRACT: Debug ITM/SWD stream deserializer for AnyEvent

use strict;
use warnings;
use bytes;

use AnyEvent::Handle;
use Carp qw( croak );
use ITM;

AnyEvent::Handle::register_read_type(itm => sub {
  my ( $self, $cb ) = @_;
  sub {
    if (defined $_[0]{rbuf}) {
      my $first = substr($_[0]{rbuf},0,1);
      my $len = length($_[0]{rbuf});
      my $f = ord($first);
      my $header = itm_header($first);
      if ($header) {
        my $size = $header->{size} ? $header->{size} : 0;
        my $payload = substr($_[0]{rbuf},1,$size);
        if (defined $payload && length($payload) == $size) {
          my $itm = itm_parse($header,$size ? ($payload) : ());
          $_[0]{rbuf} = substr($_[0]{rbuf},$size + 1);
          $cb->( $_[0], $itm );
          return 1;          
        }
        return 0;
      } else {
        croak sprintf("unknown packet type");
      }
    }
    return 0;
  };
});

1;

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUPPORT

IRC

  Join #hardware on irc.perl.org. Highlight Getty for fast reaction :).

Repository

  http://github.com/Getty/p5-anyevent-itm
  Pull request and additional contributors are welcome
 
Issue Tracker

  http://github.com/Getty/p5-anyevent-itm/issues
