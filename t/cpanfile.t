#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Spec;

# ANYEVENT_ITM_ROOT points the test at another tree (it defaults to the
# distribution being tested); it exists to check the test against old trees.
my $root = $ENV{ANYEVENT_ITM_ROOT} || '.';
my $file = File::Spec->catfile($root, 'cpanfile');

open my $fh, '<', $file or die "open $file: $!";
my $src = do { local $/; <$fh> };
close $fh;

my %phase;
my $current = 'runtime';
for my $line (split /\n/, $src) {
  $current = $1 if $line =~ /^on\s+(\w+)\s*=>/;
  $current = 'runtime' if $line =~ /^\};/;
  $phase{$current}{$1} = $2 if $line =~ /^\s*requires\s+'([^']+)'(?:\s*,\s*'([^']*)')?/;
}

for my $module (qw( AnyEvent Carp Fcntl ITM )) {
  ok(exists $phase{runtime}{$module}, $module.' is declared as runtime dependency');
}
ok(exists $phase{test}{'Test::More'}, 'Test::More is declared for test');
ok(exists $phase{develop}{'PAR::Packer'}, 'PAR::Packer (bundle.bat) is declared for develop');

for my $p (sort keys %phase) {
  for my $module (sort keys %{$phase{$p}}) {
    my $v = $phase{$p}{$module};
    isnt(defined $v ? $v : '', '0', $module.' ('.$p.') is not pinned to 0');
  }
}

ok(!exists $phase{runtime}{'Term::ANSIColor'}, 'Term::ANSIColor is not declared');

done_testing;
