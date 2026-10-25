requires 'AnyEvent', '7.17';
requires 'Carp';
requires 'Fcntl';
requires 'ITM', '0.002';

on test => sub {
  requires 'Test::More', '0.96';
};

on develop => sub {
  requires 'PAR::Packer';
};
