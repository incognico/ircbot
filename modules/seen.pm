package seen;

use utf8;
use strict;
use warnings;

my $mychannels;
my $myprofile;
my $mytrigger;

my %people;

### functions

sub duration {
   my @gmt = gmtime(shift);
   $gmt[5] -= 70;
   return   ($gmt[5] ?                                                        $gmt[5].' year'  .($gmt[5] > 1 ? 's' : '') : '').
            ($gmt[7] ? ($gmt[5]                                  ? ', ' : '').$gmt[7].' day'   .($gmt[7] > 1 ? 's' : '') : '').
            ($gmt[2] ? ($gmt[5] || $gmt[7]                       ? ', ' : '').$gmt[2].' hour'  .($gmt[2] > 1 ? 's' : '') : '').
            ($gmt[1] ? ($gmt[5] || $gmt[7] || $gmt[2]            ? ', ' : '').$gmt[1].' minute'.($gmt[1] > 1 ? 's' : '') : '').
            ($gmt[0] ? ($gmt[5] || $gmt[7] || $gmt[2] || $gmt[1] ? ', ' : '').$gmt[0].' second'.($gmt[0] > 1 ? 's' : '') : '');
}

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mychannels = $self->{mychannels};
   $myprofile  = $self->{myprofile};
   $mytrigger  = $self->{mytrigger};

   return $self;
}

### hooks

sub on_nick {
   my ($self, $nick, $newnick, $user, $host, undef) = @_;
   
   my $lcnick = lc($nick);
   
   $people{$lcnick}{type}    = 'nick';
   $people{$lcnick}{ts}      = time;
   $people{$lcnick}{nick}    = $nick;
   $people{$lcnick}{user}    = $user;
   $people{$lcnick}{host}    = $host;
   $people{$lcnick}{newnick} = $newnick;
}

sub on_part {
   my ($self, $chan, $nick, $user, $host, undef, $msg) = @_;
   
   my $lcnick = lc($nick);

   delete $people{$lcnick}{reason} if ($people{$lcnick});

   $people{$lcnick}{type}   = 'part';
   $people{$lcnick}{ts}     = time;
   $people{$lcnick}{nick}   = $nick;
   $people{$lcnick}{user}   = $user;
   $people{$lcnick}{host}   = $host;
   $people{$lcnick}{chan}   = $chan;
   $people{$lcnick}{reason} = $msg if ($msg);
}

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      return unless ($ischan);

      # cmds 
      if ($cmd eq 'SEEN') {
         if ($args[0]) {
            my $online;

            LOL: { 
               for my $chans (keys(%{$mychannels->{$$myprofile}})) {
                  for (keys(%{$mychannels->{$$myprofile}{$chans}})) {
                     if (lc($_) eq $args[0]) {
                        $online = $_;
                        last LOL;
                     }
                  }
               }
            }

            if ($online) {
               main::msg($target, '%s is online right now', $online);
            }
            else {
               my $lcnick = lc($args[0]);
               if ($people{$lcnick}) {
                  if ($people{$lcnick}{type} eq 'nick') {
                     main::msg($target, '%s (%s@%s) was last seen %s ago, changing nicks to %s', $people{$lcnick}{nick}, $people{$lcnick}{user}, $people{$lcnick}{host}, duration(time - $people{$lcnick}{ts}), $people{$lcnick}{newnick});
                  }
                  elsif ($people{$lcnick}{type} eq 'part') {
                      main::msg($target, '%s (%s@%s) was last seen %s ago, parting %s', $people{$lcnick}{nick}, $people{$lcnick}{user}, $people{$lcnick}{host}, duration(time - $people{$lcnick}{ts}), $people{$lcnick}{reason} ? "$people{$lcnick}{chan} with reason: $people{$lcnick}{reason}" : $people{$lcnick}{chan});
                  }
                  elsif ($people{$lcnick}{type} eq 'quit') {
                      main::msg($target, '%s (%s@%s) was last seen %s ago, quitting with %s', $people{$lcnick}{nick}, $people{$lcnick}{user}, $people{$lcnick}{host}, duration(time - $people{$lcnick}{ts}), $people{$lcnick}{reason} ? "reason: $people{$lcnick}{reason}" : 'no reason');
                  }
               }
               else {
                  main::msg($target, 'I have not seen %s yet', $args[0]);
               }
            }
         }
         else {
            main::msg($target, 'seen who?');
         }
      }
   }
}

sub on_quit {
   my ($self, $nick, $user, $host, undef, $msg) = @_;

   my $lcnick = lc($nick);
   
   delete $people{$lcnick}{reason} if ($people{$lcnick});

   $people{$lcnick}{type}   = 'quit';
   $people{$lcnick}{ts}     = time;
   $people{$lcnick}{nick}   = $nick;
   $people{$lcnick}{user}   = $user;
   $people{$lcnick}{host}   = $host;
   $people{$lcnick}{reason} = $msg if ($msg);
}

1;
