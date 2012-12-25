package tlds;
require modules::utils;

use utf8;
use strict;
use warnings;

use Carp;

my $mytrigger;

my %tlds;

### start config

# https://github.com/nwohlgem/list-of-top-level-domains/raw/master/tlds.csv
my $csv = sprintf("$ENV{HOME}/.bot/%s/%s.csv", __PACKAGE__, __PACKAGE__);

### end config ###

if (-e $csv) {
   open my $fh, '<:encoding(UTF-8)', $csv || croak $!;
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

   $mytrigger     = $self->{mytrigger};

   return $self;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, $who) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      $target = $nick unless $ischan;

      # cmds
      if ($cmd eq 'TLD') {
         if ($args[0]) {
            my $tld = lc((substr($args[0], 0, 1) eq '.') ? substr($args[0], 1) : $args[0]);

            if (exists $tlds{$tld}) {
               utils->msg($target, '.%s: %s', $tld, $tlds{$tld});
            }
            else {
               utils->err($target, 'not found');
            }
         }
         else {
            utils->err($target, 'syntax: TLD <[.]tld>');
         }
      }
   }
}

1;
