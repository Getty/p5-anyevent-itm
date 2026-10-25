#!/usr/bin/env perl
use strict;
use warnings;
use File::Temp qw( tempdir );
use Test::More;

my $dir = tempdir( CLEANUP => 1 );

# Tests may point at another copy of a script (e.g. the pre-fix one).
my %script = (
  itm_read_simple  => $ENV{ITM_TEST_READ_SIMPLE}  || 'bin/itm_read_simple',
  itm_read_nocolor => $ENV{ITM_TEST_READ_NOCOLOR} || 'bin/itm_read_nocolor',
);

# 0x0N headers: instrumentation, source 0, payload size 1 (0x01), 2 (0x02), 4 (0x03)
my $stream = join q{},
  "\x02ab",         # "ab"
  "\x02c\r",        # "c\r"
  "\x01\n",         # "\n"   -> line "abc" (CR stripped)
  "\x00",           # sync, ignored
  "\x15X",          # hardware source, ignored
  "\x01\n",         # empty line
  "\x03tail",       # partial last line, flushed at EOF
  ;

my $file = "$dir/stream.itm";
open my $fh, '>:raw', $file or die "write $file: $!";
print $fh $stream;
close $fh;

# An @INC hook that makes Term::ANSIColor impossible to load.
my $hook = "$dir/NoANSIColor.pm";
open my $hh, '>', $hook or die "write $hook: $!";
print $hh <<'HOOK';
package NoANSIColor;
unshift @INC, sub { die "Term::ANSIColor must not be loaded\n" if $_[1] eq 'Term/ANSIColor.pm'; return };
1;
HOOK
close $hh;

my $ts = qr/\d{4}-\d\d-\d\d \d\d:\d\d:\d\d/;

for my $name ( sort keys %script ) {
  my $out = "$dir/$name.out";
  my $err = "$dir/$name.err";
  my $cmd = join ' ', map { "'$_'" } $^X, '-Ilib', "-I$dir", '-MNoANSIColor', $script{$name}, $file;
  my $rc = system "$cmd >'$out' 2>'$err'";
  is( $rc, 0, $name.' exits cleanly without Term::ANSIColor' );
  my @lines = do { open my $o, '<', $out or die $!; <$o> };
  is( scalar @lines, 3, $name.': one line per newline plus the flushed partial' );
  like( $lines[0], qr/\A$ts > abc\n\z/, $name.': timestamped line, CR stripped' );
  like( $lines[1], qr/\A$ts > \n\z/,    $name.': empty line kept' );
  like( $lines[2], qr/\A$ts > tail\n\z/, $name.': partial last line flushed at EOF' );
  my $stderr = do { open my $e, '<', $err or die $!; local $/; <$e> };
  like( $stderr, qr/EOF/, $name.': EOF reported' );
  unlike( $stderr, qr/Term::ANSIColor|Can't locate/, $name.': no load failure' );
}

done_testing;
