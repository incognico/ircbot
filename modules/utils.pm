package utils;

use utf8;
use strict;
use warnings;

my $myadmins;
my $mychannels;
my $myprofile;
my $silent;

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $myadmins   = $self->{myadmins};
   $mychannels = $self->{mychannels};
   $myprofile  = $self->{myprofile};
   $silent     = $self->{silent};

   return $self;
}

sub ack {
   my ($self, $target) = @_;

   $self->msg($target, sprintf("done {::%s}", caller)) unless $$silent;
}

sub act {
   my ($self, $target, $msg) = @_;
   my $allow = 1;

   if (main::ischan($target)) {
      $allow = 0 unless exists $mychannels->{$$myprofile}{$target};
   }

   if ($allow) {
      for (split(/\n|(.{400})/, $msg)) {
         main::raw("PRIVMSG %s :\001ACTION %s\001", $target, $_) if $_;
      }
   }
}

sub chantrim {
   my ($self, $string) = @_;

   $string =~ s/[\s+,]/ /g;
   $string =~ s/^\s+//;
   $string =~ s/\s+$//;

   return lc($string);
}

sub err {
   my ($self, $target, $string) = @_;

   if ($string) {
      $self->msg($target, sprintf("error: %s {::%s}", $string, caller(0))) unless $$silent;
   }
   else {
      $self->msg($target, sprintf("error {::%s}", caller(0))) unless $$silent;
   }
}


sub hlp {
   my ($self, $target, $string) = @_;

   $self->msg($target, sprintf("help: %s {::%s}", $string, caller(0))) unless $$silent;
}

sub joinchan {
   my ($self, $chan, $key) = @_;

   $chan = lc($chan);

   if ($key) {
      main::raw('JOIN %s %s', $chan, $key) unless exists $mychannels->{$$myprofile}{$chan};
   }
   else {
      main::raw('JOIN %s', $chan) unless exists $mychannels->{$$myprofile}{$chan};
   }
}

sub kick {
   my ($self, $chan, $victim, $reason) = @_;
   my %uniq;

   $uniq{(split('!', $_))[0]}++ for @$myadmins;

   return if (exists $uniq{$victim});

   if ($reason) {
      main::raw('KICK %s %s :%s', $chan, $victim, $reason) if exists $mychannels->{$$myprofile}{$chan};
   }
   else {
      main::raw('KICK %s %s', $chan, $victim) if exists $mychannels->{$$myprofile}{$chan};
   }
}

sub msg {
   my ($self, $target, $msg, $act) = @_;

   for (split(/\n|(.{400})/, $msg)) {
      unless ($act) {
         main::raw('PRIVMSG %s :%s', $target, $_) if $_;
      }
      elsif ($act == 1) {
         main::raw("PRIVMSG %s :\001ACTION %s\001", $target, $_) if $_;
      }
      elsif ($act == 2) {
         main::raw('NOTICE %s :%s', $target, $_) if $_;
      }
   }
}

sub partchan {
   my ($self, $chan) = @_;

   main::raw('PART %s', $chan) if exists $mychannels->{$$myprofile}{$chan};
}

sub settopic {
   my ($self, $chan, $text) = @_;

   main::raw('TOPIC %s :%s', $chan, $text);
}

sub stripcodes {
   my ($self, $string) = @_;

   $string =~ s/[\002\017\026\037]|\003\d?\d?(?:,\d\d?)?//g;

   return $string;
}

1;
