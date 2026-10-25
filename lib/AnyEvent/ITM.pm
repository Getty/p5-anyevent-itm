package AnyEvent::ITM;
# ABSTRACT: Debug ITM/SWD stream deserializer for AnyEvent

our $VERSION = '0.002';

use strict;
use warnings;
use bytes;

use AnyEvent;
use AnyEvent::Handle;
use Carp qw( croak );
use ITM;
use Fcntl qw(O_RDONLY O_RDWR O_NONBLOCK O_NOCTTY);
use AnyEvent::Util qw(portable_pipe);

AnyEvent::Handle::register_read_type(itm => sub {
  my ( $self, $cb ) = @_;
  sub {
    if (defined $_[0]{rbuf} && length $_[0]{rbuf}) {
      my $header = itm_header(substr($_[0]{rbuf},0,1));
      my $size = $header->{size} ? $header->{size} : 0;
      my $payload = substr($_[0]{rbuf},1,$size);
      if (defined $payload && length($payload) == $size) {
        my $itm = itm_parse($header,$size ? ($payload) : ());
        $_[0]{rbuf} = substr($_[0]{rbuf},$size + 1);
        $cb->( $_[0], $itm );
        return 1;
      }
    }
    return 0;
  };
});

sub _ts {
  my @t = localtime;
  return sprintf "%04d-%02d-%02d %02d:%02d:%02d",
    $t[5]+1900, $t[4]+1, $t[3], $t[2], $t[1], $t[0];
}

sub print_ts {
  my ( $label, $line ) = @_;
  chomp $line;
  if ($label eq '2>') {
    print STDERR _ts()." $label $line\n";
  } else {
    print STDOUT _ts()." $label $line\n";
  }
};

=method print_ts

  AnyEvent::ITM::print_ts('>', $line);

Prints C<$line> prefixed with the local time (C<YYYY-MM-DD HH:MM:SS>) and
C<$label>, one line per call (a trailing newline of C<$line> is removed). The
label C<2E<gt>> prints to STDERR, every other label to STDOUT. This is a plain
function, not a method.

=cut

sub handle {
  my ( $class, $file, $payload_sub, $cv ) = @_;

  my $has_cv = defined $cv ? 1 : 0;

  $cv = AE::cv unless $has_cv;

  # Choose flags so open won't block
  my $flags;
  if (-p $file) {
    $flags = O_RDWR | O_NONBLOCK;
  } else {
    $flags = O_RDONLY | O_NONBLOCK;
    $flags |= O_NOCTTY if -c $file;
  }

  sysopen(my $fh, $file, $flags) or croak "sysopen $file: $!";
  binmode($fh, ':raw');

  my $handle = AnyEvent::Handle->new(
    fh => $fh,
    on_error => sub {
      my ( $handle, $fatal, $message ) = @_;
      $handle->destroy;
      $cv->send("$fatal: $message");
    },
    on_eof => sub {
      my ( $handle ) = @_;
      $handle->destroy;
      $cv->send("EOF");
    },
    on_read => sub {
      my $handle = shift;
      $handle->push_read( itm => $payload_sub );
    },
  );

  $cv->recv unless $has_cv;

  return $handle;
}

=method handle

  my $handle = AnyEvent::ITM->handle($file, sub { my ( $handle, $itm ) = @_; ... }, $cv);

Opens C<$file> non-blocking and calls the callback with C<($handle, $itm)>
for every packet read from it. A pipe is opened read-write, so it stays open
when the writer goes away; a character device is opened without a
controlling terminal; anything else is opened read-only. Croaks when the file
cannot be opened.

The optional C<$cv> receives C<EOF> at the end of the file and
C<"$fatal: $message"> on a read error; the handle is destroyed in both
cases. Without C<$cv> the method waits for one of them before it returns.

=cut

sub run_cmd {
  my ($class, @cmd) = @_;
  croak "run_cmd: no command" unless @cmd;

  my ($out_r, $out_w) = portable_pipe;
  my ($err_r, $err_w) = portable_pipe;

  my $proc = AnyEvent::Util::run_cmd \@cmd, '>' => $out_w, '2>' => $err_w, close_all => 1;

  close $out_w;
  close $err_w;

  my %cmd = (
    cv   => AE::cv,
    proc => $proc,
  );

  $cmd{hout} = AnyEvent::Handle->new(
    fh      => $out_r,
    on_read => sub {
      my ($h) = @_;
      $h->push_read(line => sub {
        my ($h, $line) = @_;
        print_ts('>', $line);
      });
    },
    on_eof   => sub { shift->destroy },
    on_error => sub { shift->destroy },
  );

  $cmd{herr} = AnyEvent::Handle->new(
    fh      => $err_r,
    on_read => sub {
      my ($h) = @_;
      $h->push_read(line => sub {
        my ($h, $line) = @_;
        print_ts('2>', $line);
      });
    },
    on_eof   => sub { shift->destroy },
    on_error => sub { shift->destroy },
  );

  $proc->cb(sub {
    my $raw = shift->recv;                 # like $?
    my $code = ($raw >> 8) & 0xff;
    my $sig  = $raw & 0x7f;
    $cmd{exit_code} = $code;
    $cmd{signal}    = $sig if $sig;
    $cmd{cv}->send($code);
  });

  return \%cmd;  # keep this in scope; wait via $obj->{cv}->recv
}

=method run_cmd

  my $cmd = AnyEvent::ITM->run_cmd(@command);
  my $exit_code = $cmd->{cv}->recv;

Starts C<@command> and prints each line of its output through C<print_ts>,
with the label C<E<gt>> for stdout and C<2E<gt>> for stderr. Croaks without a
command.

Returns a hashref with C<cv> (sent the exit code when the command ended),
C<proc>, C<hout> and C<herr> (the process and the two pipe handles). Once the
command ended it also holds C<exit_code> and, if a signal ended it, C<signal>.

The caller must keep the returned hashref alive, for example in a lexical
variable that stays in scope while the event loop runs: the process and the
pipe handles live in it, and the command dies with the hashref.

=cut

1;

=head1 SYNOPSIS

  my $cv = AE::cv;
  my $handle = AnyEvent::ITM->handle($file, sub {
    my ( $handle, $itm ) = @_;
    if (ref $itm eq 'ITM::Instrumentation') {
      printf("[%u]%s", $itm->source, $itm->payload);
    }
  }, $cv);
  $cv->recv;

or without $cv, it will start its own and does $cv->recv on its own.

  AnyEvent::ITM->handle($file, sub { ... });

=head1 DESCRIPTION

Process ITM/SWO Debugging data.
