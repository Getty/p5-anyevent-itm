#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Find ();
use File::Spec;

# ANYEVENT_ITM_ROOT points the test at another tree (it defaults to the
# distribution being tested); it exists to check the test against old trees.
my $root = $ENV{ANYEVENT_ITM_ROOT} || '.';

# Checks the source as written; the built dist carries generated POD.
plan skip_all => 'source tree only'
  unless $ENV{ANYEVENT_ITM_ROOT} || -e File::Spec->catfile($root, '.git');

my @files;
for my $dir (qw( lib bin )) {
  my $path = File::Spec->catdir($root, $dir);
  next unless -d $path;
  File::Find::find({
    no_chdir => 1,
    wanted   => sub { push @files, $_ if -f $_ && !/\.swp$/ },
  }, $path);
}
@files = sort @files;
ok(scalar @files >= 3, 'found the files under lib/ and bin/')
  or diag('looked in '.$root);

my %version;
for my $file (@files) {
  open my $fh, '<', $file or die "open $file: $!";
  my $src = do { local $/; <$fh> };
  close $fh;

  if ($src =~ /^our\s+\$VERSION\s*=\s*'([^']+)'\s*;/m) {
    $version{$file} = $1;
    pass($file.' declares its own $VERSION');
  } else {
    fail($file.' declares its own $VERSION');
  }

  unlike($src, qr/^=head\d\s+SUPPORT\b/mi,
    $file.' has no hand-written SUPPORT section');
}

my %distinct = map { $_ => 1 } values %version;
is(scalar keys %distinct, 1, 'all files carry the same $VERSION')
  or diag(join '', map { "  $_ => $version{$_}\n" } sort keys %version);

done_testing;
