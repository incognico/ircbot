package maps;

use utf8;
use strict;
use warnings;

use Geo::Coder::Google;

my $mytrigger;

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mytrigger = $self->{mytrigger};

   return $self;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      $target = $nick unless $ischan;

      # cmds 
      if ($cmd eq 'MAPS') {
         if ($args[0]) {
            my $geo = Geo::Coder::Google->new(apiver => 3);
            my $loc = $geo->geocode(location => "@args");

            if ($loc) {
               printf("[%s] === modules::%s: Maps [%s] on %s by %s\n", scalar localtime, __PACKAGE__, $loc->{formatted_address}, $target, $nick);
               main::msg($target, '%s: https://maps.google.com/maps?q=%s,%s&t=h&z=14', $loc->{formatted_address}, $loc->{geometry}{location}{lat}, $loc->{geometry}{location}{lng});
            }
            else {
               main::msg($target, 'no match');
            }
         }
         else {
            main::err($target, 'syntax: MAPS <location>');
         }
      }
   }
}

1;
