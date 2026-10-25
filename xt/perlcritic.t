#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
  eval { require Perl::Critic; require Test::Perl::Critic; 1 }
    or plan skip_all => 'SKIPPED, not passed: Perl::Critic and Test::Perl::Critic are required for this test';
}

# Severity 5 (gentle) over lib/ and bin/. The only policy left out is
# RequireUseStrict: it does not see the "use strict" below the per-file
# "our $VERSION" line that the house style puts first (and the release bundle
# rewrites), although strict is on for the whole file. Stricter levels flag
# the style of the existing code (postfix controls, reused names, magic
# numbers) and would need code to be rebuilt, which is not what this test is for.
Test::Perl::Critic->import(
  -severity => 5,
  -exclude  => ['TestingAndDebugging::RequireUseStrict'],
  -verbose  => '%f:%l %m (%p)\n',
);

all_critic_ok( 'lib', 'bin' );
