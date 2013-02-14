package tlds;

use utf8;
use strict;
use warnings;

my $mytrigger;

my %tlds;

### start config

# https://github.com/nwohlgem/list-of-top-level-domains/raw/master/tlds.csv
my $csv = sprintf("$ENV{HOME}/.bot/%s/%s.csv", __PACKAGE__, __PACKAGE__);

### end config

unless (open my $fh, '<', $csv) {
   return;
}
else {
   while (my $line = <$fh>) {
      chomp $line;
      my @data = split(',', $line);
      $tlds{$data[0]} = $data[1];
   }
   close $fh;
}

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mytrigger = $self->{mytrigger};

   return $self;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, $who) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      $target = $nick unless ($ischan);

      # cmds
      if ($cmd eq 'TLD') {
         if ($args[0]) {
            my $tld = lc((substr($args[0], 0, 1) eq '.') ? substr($args[0], 1) : $args[0]);

            if (exists $tlds{$tld}) {
               main::msg($target, '.%s: %s', $tld, $tlds{$tld});
            }
            else {
               main::msg($target, 'not found');
            }
         }
         else {
            main::hlp($target, 'syntax: TLD <[.]tld>');
         }
      }
   }
}

1;
