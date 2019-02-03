package urlcatch;

use utf8;
use strict;
use warnings;

use DBI;

my $mychannels;
my $myprofile;
my $mytrigger;

my $dbh;

### start config

my $logtodb    = 0;
my $imgonly    = 1;
my $posttochan = 1;
my $targetchan = '#example';

my %sql = (
   host  => 'localhost',
   db    => '',
   table => 'urls',
   user  => '',
   pass  => '',
);

### end config

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   #$logtodb    = $self->{logtodb};
   $mychannels = $self->{mychannels};
   $myprofile  = $self->{myprofile};
   $mytrigger  = $self->{mytrigger};

   return $self;
}

sub mysql_connect {
   unless ($dbh = DBI->connect("DBI:mysql:$sql{db}:$sql{host}", $sql{user}, $sql{pass}, {mysql_auto_reconnect => 1, mysql_enable_utf8 => 1})) {
      printf("[%s] !!! modules::%s: %s\n", scalar localtime, __PACKAGE__, $DBI::errstr);
      return 1;
   }
   else {
      return 0;
   }
}

sub mysql_disconnect {
   $dbh->disconnect;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, $user, $host, $who) = @_;

   if ($ischan) {
      if (main::stripcodes($msg) =~ m!\b((?:[a-zA-Z]+://|[wW][wW][wW]\.)[^\s'")]+)!) {
         my $url = $1;

         if ($posttochan && $target ne $targetchan && not exists $mychannels->{$$myprofile}{$targetchan}{$nick}) {
            if ($imgonly) {
               main::msg($targetchan, 'URL: %s on %s by %s', $url, $target, $nick) if ($url =~ /\.(jpe?g|png|gif|bmp|webm|gifv)$/i);
            }
            else {
               main::msg($targetchan, 'URL: %s on %s by %s', $url, $target, $nick);
            }
         }

         if ($logtodb) {
               return 1 unless (mysql_connect() == 0);

               $dbh->do("INSERT INTO $sql{table} (timestamp, count, url, network, channel, nickname, user, host) VALUES (now(), 1, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE count=count+1", undef, $url, $$myprofile, $target, $nick, $user, $host);

               mysql_disconnect();
         }
      }
   }
      
   # admin cmds
   return unless (main::isadmin($who));

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my @cargs = map { uc } @args;
      my $cmd = substr(shift(@cargs), 1);
      shift(@args);

      $target = $nick unless ($ischan);

      # cmds
      if ($cmd eq 'SET') {
         my $syntax = 'syntax: SET IMGONLY|URLSHOW [ON|OFF]';

         if ($args[0]) {
            if ($cargs[0] eq 'IMGONLY') {
               if ($args[1]) {
                  if ($cargs[1] eq 'ON') {
                     $imgonly = 1;
                     main::ack($target);
                  }
                  elsif ($cargs[1] eq 'OFF') {
                     $imgonly = 0;
                     main::ack($target);
                  }
               }
               elsif (!$args[1]) {
                  main::msg($target, 'IMGONLY: %s', $imgonly ? 'ON' : 'OFF');
               }
               else {
                  main::hlp($target, 'syntax: SET IMGONLY [ON|OFF]');
               }
            }
            elsif ($cargs[0] eq 'URLSHOW') {
               if ($args[1]) {
                  if ($cargs[1] eq 'ON') {
                     $posttochan = 1;
                     main::ack($target);
                  }
                  elsif ($cargs[1] eq 'OFF') {
                     $posttochan = 0;
                     main::ack($target);
                  }
               }
               elsif (!$args[1]) {
                  main::msg($target, 'URLSHOW: %s', $posttochan ? 'ON' : 'OFF');
               }
               else {
                  main::hlp($target, 'syntax: SET URLSHOW [ON|OFF]');
               }
            }
            elsif ($cargs[0] eq 'HELP') {
               main::hlp($target, $syntax);
            }
         }
         elsif (!$args[0]) {
            main::hlp($target, $syntax);
         }
      }
   }
}

1;
