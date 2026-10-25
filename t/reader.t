#!/usr/bin/env perl
use strict;
use warnings;
use Cwd qw( getcwd );
use File::Temp qw( tempdir );
use Test::More;
use AnyEvent;
use AnyEvent::ITM;

# The reader, called the way AnyEvent::Handle calls it: with the handle (only
# its rbuf matters here) and the user callback.
sub reader_for {
  my ( $rbuf, $got ) = @_;
  my $handle = { rbuf => $rbuf };
  my $reader = $AnyEvent::Handle::RH{itm}->( $handle, sub { push @{$got}, $_[1] } );
  return ( $handle, $reader );
}

my @warnings;
local $SIG{__WARN__} = sub { push @warnings, @_ };

# an empty buffer means "nothing there yet"
{
  my @got;
  my ( $handle, $reader ) = reader_for( '', \@got );
  my $ret = $reader->($handle);
  is( $ret, 0, 'empty buffer: reader returns 0' );
  is( scalar @got, 0, 'empty buffer: no packet reported' );
  is( $handle->{rbuf}, '', 'empty buffer: stays empty' );
  is( scalar @warnings, 0, 'empty buffer: no warning' )
    or diag explain \@warnings;
  @warnings = ();
}

# a partial packet is never consumed
{
  my @got;
  my ( $handle, $reader ) = reader_for( "\x03ab", \@got );   # needs 4 payload bytes
  is( $reader->($handle), 0, 'partial packet: reader returns 0' );
  is( $handle->{rbuf}, "\x03ab", 'partial packet: buffer untouched' );
  is( scalar @got, 0, 'partial packet: no callback' );
}

# exactly one packet per call: one header byte plus the payload
{
  my @got;
  my ( $handle, $reader ) = reader_for( "\x02ab\x01c", \@got );
  is( $reader->($handle), 1, 'complete packet: reader returns 1' );
  is( scalar @got, 1, 'complete packet: exactly one callback' );
  is( $got[0]->payload, 'ab', 'complete packet: payload' );
  is( $handle->{rbuf}, "\x01c", 'complete packet: buffer advanced by header plus payload' );
}

# croak reports the caller, not the module
{
  my $line;
  eval { $line = __LINE__; AnyEvent::ITM->handle( '/nonexistent/itm.stream', sub {} ) };
  like( $@, qr{\Asysopen /nonexistent/itm\.stream: No such file}, 'handle: names the file' );
  like( $@, qr{ at \Q$0\E line $line\b}, 'handle: error points at the caller' );

  eval { $line = __LINE__; AnyEvent::ITM->run_cmd() };
  like( $@, qr{\Arun_cmd: no command}, 'run_cmd: says what is missing' );
  like( $@, qr{ at \Q$0\E line $line\b}, 'run_cmd: error points at the caller' );
}

# a file named 0 is a file
{
  my $dir = tempdir( CLEANUP => 1 );
  my $cwd = getcwd;
  chdir $dir or die "chdir $dir: $!";
  open my $fh, '>:raw', '0' or die "write 0: $!";
  print $fh "\x01A";
  close $fh;
  my @got;
  my $cv = AE::cv;
  my $guard = AE::timer 10, 0, sub { $cv->send('timeout') };
  my $handle = AnyEvent::ITM->handle( '0', sub { push @got, $_[1] }, $cv );
  is( $cv->recv, 'EOF', 'file named 0: opened and read to EOF' );
  is( scalar @got, 1, 'file named 0: packet delivered' );
  chdir $cwd or die "chdir $cwd: $!";
}

done_testing;
