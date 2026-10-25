#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use AnyEvent;
use AnyEvent::ITM;

sub run_and_wait {
  my @cmd = @_;
  my $cmd = AnyEvent::ITM->run_cmd(@cmd);    # stays in scope while we wait
  my $guard = AE::timer 10, 0, sub { $cmd->{cv}->send('timeout') };
  my $got = $cmd->{cv}->recv;
  return ( $cmd, $got );
}

ok( AnyEvent::ITM->can('run_cmd'),  'run_cmd is public' );
ok( AnyEvent::ITM->can('print_ts'), 'print_ts is public' );

my ( $cmd, $got ) = run_and_wait( 'sh', '-c', 'exit 3' );
is( $got, 3, 'cv receives the exit code' );
is( $cmd->{exit_code}, 3, 'exit_code is set' );
ok( !exists $cmd->{signal}, 'no signal after a normal exit' );

( $cmd, $got ) = run_and_wait( 'sh', '-c', 'exit 0' );
is( $cmd->{exit_code}, 0, 'exit_code 0 for success' );
ok( !exists $cmd->{signal}, 'no signal after success' );

( $cmd, $got ) = run_and_wait( 'sh', '-c', 'kill -TERM $$' );
is( $cmd->{signal}, 15, 'signal is reported for a killed command' );
is( $cmd->{exit_code}, 0, 'exit_code is 0 when a signal ended it' );

{
  my $out = q{};
  open my $save, '>&', \*STDOUT or die "dup: $!";
  close STDOUT;
  open STDOUT, '>', \$out or die "redirect: $!";
  AnyEvent::ITM::print_ts( '>', "hello\n" );
  close STDOUT;
  open STDOUT, '>&', $save or die "restore: $!";
  like( $out, qr/\A\d{4}-\d\d-\d\d \d\d:\d\d:\d\d > hello\n\z/, 'print_ts line format' );
}

eval { AnyEvent::ITM->run_cmd() };
like( $@, qr/no command/, 'run_cmd without a command dies' );

done_testing;
