#!/usr/bin/env perl
use strict;
use warnings;
use Fcntl qw( F_GETFL O_ACCMODE O_RDONLY O_RDWR O_WRONLY O_NONBLOCK );
use File::Temp qw( tempdir );
use POSIX ();
use Test::More;
use AnyEvent;
use AnyEvent::ITM;

# These are characterization tests: they pin what handle() does today (file
# modes, the "EOF" signal, the error signal); none of them is new behaviour.

my $dir = tempdir( CLEANUP => 1 );

# 0x02 = instrumentation, source 0, 1 payload byte; 0x01 = instrumentation, 1 byte
my $stream = "\x02ab\x01c";

sub open_handle {
  my ( $file, $cv ) = @_;
  my @packets;
  my $handle = AnyEvent::ITM->handle( $file, sub { push @packets, $_[1] }, $cv );
  my $flags = fcntl( $handle->{fh}, F_GETFL, 0 );
  return ( $handle, \@packets, $flags );
}

# wait for the cv, or give up after $secs and report 'idle'
sub wait_for {
  my ( $cv, $secs ) = @_;
  my $guard = AE::timer $secs, 0, sub { $cv->send('idle') };
  return $cv->recv;
}

# regular file: read-only, non-blocking, packets, then EOF
{
  my $file = "$dir/stream.itm";
  open my $fh, '>:raw', $file or die "write $file: $!";
  print $fh $stream;
  close $fh;

  my $cv = AE::cv;
  my ( $handle, $packets, $flags ) = open_handle( $file, $cv );
  is( $flags & O_ACCMODE, O_RDONLY, 'regular file: opened read-only' );
  ok( $flags & O_NONBLOCK, 'regular file: opened non-blocking' );
  is( wait_for( $cv, 10 ), 'EOF', 'regular file: the cv receives EOF' );
  is( scalar @{$packets}, 2, 'regular file: both packets reached the callback' );
  is( $packets->[0]->payload, 'ab', 'regular file: first payload' );
  is( $packets->[1]->payload, 'c',  'regular file: second payload' );
}

# FIFO: read-write, so the reader stays open when the writer goes away
{
  my $fifo = "$dir/stream.fifo";
  POSIX::mkfifo( $fifo, 0600 ) or die "mkfifo $fifo: $!";

  my $cv = AE::cv;
  my ( $handle, $packets, $flags ) = open_handle( $fifo, $cv );
  is( $flags & O_ACCMODE, O_RDWR, 'pipe: opened read-write' );
  ok( $flags & O_NONBLOCK, 'pipe: opened non-blocking' );

  sysopen( my $w, $fifo, O_WRONLY | O_NONBLOCK ) or die "open writer: $!";
  syswrite( $w, $stream ) == length $stream or die "write: $!";
  close $w;

  is( wait_for( $cv, 1 ), 'idle', 'pipe: no EOF after the writer closed' );
  is( scalar @{$packets}, 2, 'pipe: both packets reached the callback' );
  $handle->destroy;
}

# character device: read-only, non-blocking, EOF at once
{
  my $cv = AE::cv;
  my ( $handle, $packets, $flags ) = open_handle( '/dev/null', $cv );
  is( $flags & O_ACCMODE, O_RDONLY, 'character device: opened read-only' );
  ok( $flags & O_NONBLOCK, 'character device: opened non-blocking' );
  is( wait_for( $cv, 10 ), 'EOF', 'character device: the cv receives EOF' );
  is( scalar @{$packets}, 0, 'character device: no packet' );
}

# a read error is sent as "$fatal: $message"; reading a directory fails
{
  my $cv = AE::cv;
  my ( $handle ) = open_handle( $dir, $cv );
  like( wait_for( $cv, 10 ), qr/\A1: Is a directory\z/, 'error: the cv receives "$fatal: $message"' );
}

# a file that cannot be opened croaks at the caller's line
{
  eval { AnyEvent::ITM->handle( "$dir/missing", sub { } ) };
  like( $@, qr/\Asysopen \Q$dir\E\/missing: No such file or directory at \Q$0\E line \d+/,
    'missing file: croaks with the caller location' );
}

done_testing;
