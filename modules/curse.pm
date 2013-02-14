package curse;

use utf8;
use strict;
use warnings;

my $mytrigger;

my @curses;

### start config

my $file = sprintf("$ENV{HOME}/.bot/%s/%ss.txt", __PACKAGE__, __PACKAGE__);

### end config

unless(open my $fh, '<', $file) {
   return;
}
else {
   while(my $line = <$fh>) {
      chomp $line;
      push @curses, $line;
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
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      $target = $nick unless ($ischan);

      # cmds
      if ($cmd eq 'CURSE') {
         my $text;

         $text .= $curses[int(rand(@curses))] . ' ' for (1..3);
         main::msg($target, $text);
      }
   }
}

1;
