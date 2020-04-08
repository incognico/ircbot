package steamstore;

use utf8;
use strict;
use warnings;

use LWP::Simple;

my $myprofile;

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $myprofile = $self->{myprofile};

   return $self;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, $user, $host, $who) = @_;

   if ($ischan) {
      if (main::stripcodes($msg) =~ m!\b((?:https?://|[wW][wW][wW]\.)store\.steampowered\.com/app/[0-9]+/?[^\s'")]+)!) {
         my $html = get ($1) || return;

         $html =~ m{<TITLE>(.*?)</TITLE>}gism;
         my $title = $1;

         main::msg($target, 'Store :: %s', $title) unless ($1 eq 'Welcome to Steam');
      }
   }
}

1;
