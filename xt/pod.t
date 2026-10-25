#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use B ();

# POD coverage is checked by hand, not with Test::Pod::Coverage, and the POD
# syntax is not checked with Test::Pod: the =method shortcut belongs to the
# [@Author::GETTY] bundle, which turns it into =head2 at build time. The
# standard tools do not know it (podchecker: "Unknown directive: =method"),
# so they would reject or ignore the very commands that document the module.
# Instead every public sub (own, not imported, no leading underscore, no imported constant) of
# AnyEvent::ITM must have a "=method NAME" (or "=head2 NAME") entry.

use AnyEvent::ITM;

my $pm = $INC{'AnyEvent/ITM.pm'};
open my $fh, '<', $pm or die "read $pm: $!";
my $src = do { local $/; <$fh> };
close $fh;

my %documented = map { $_ => 1 } $src =~ /^=(?:method|head2)\s+(\w+)/mg;

my @public;
{
  no strict 'refs';
  for my $name ( sort keys %{'AnyEvent::ITM::'} ) {
    next if $name =~ /\A_/ or $name =~ /\A(?:BEGIN|END|import|ISA|VERSION)\z/;
    my $code = *{ 'AnyEvent::ITM::'.$name }{CODE} or next;
    my $cv = B::svref_2object($code);
    next unless $cv->GV->STASH->NAME eq q{AnyEvent::ITM} and $cv->FILE eq $pm;   # skip imports and Fcntl constants
    push @public, $name;
  }
}

cmp_ok( scalar @public, '>=', 3, 'found the public subs' );
for my $name (@public) {
  ok( $documented{$name}, 'AnyEvent::ITM::'.$name.' is documented' );
}

done_testing;
