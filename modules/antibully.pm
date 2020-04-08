package antibully;

use utf8;
use strict;
use warnings;

use sigtrap 'handler', \&bullyrss, 'ALRM';

use threads;
use threads::shared;

use Net::Twitter::Lite::WithAPIv1_1;
use XML::Feed;
use WWW::Shorten 'TinyURL';

my $mychannels;
my $myprofile;
my $mytrigger;

my $file;
my $firstalarm = 0;
my %bullies;
my %captacha_keys :shared;
my %captacha_nicks :shared;
my %lastnews;

### start config

my $antibullychannel = '#stop-irc-bullying';
my $badwordregexp    = '(start[- ]?irc[- ]?bullying|\b(ass(hat|hole)|bitch|cocks|cunt|dick(head)?|fag(got)?|fa+c?k+|fgt|fuck(er|head)?|fc?u+k+|idiot|kike|moron|nigg(a|er)|pussy|retard|shithead|slag|slut)s?\b)';
my $filename         = "$ENV{'HOME'}/.bot/%s/rss_timestamp_%s"; # package name, profile name
my $timestoban       = 3;

my $nt = Net::Twitter::Lite::WithAPIv1_1->new(
  consumer_key        => '',
  consumer_secret     => '',
  access_token        => '',
  access_token_secret => '',
  legacy_lists_api    => 0,
  ssl                 => 1,
);

### end config

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mychannels = $self->{mychannels};
   $myprofile  = $self->{myprofile};
   $mytrigger  = $self->{mytrigger};

   $file = sprintf($filename, __PACKAGE__, $$myprofile);

   return $self;
}

sub bullyrss {
   my $lastdate    = 0;
   my $newlastdate = 0;

   if (-e $file) {
      unless(open my $fh, '<', $file) {
         printf("[%s] !!! modules::%s: Error reading %s\n", scalar localtime, __PACKAGE__, $file);
         return;
      }
      else {
         $lastdate = <$fh>;
         close $fh;
      }
   }

   my $feed;
   unless ($feed = XML::Feed->parse(URI->new('https://news.google.com/news/rss/search/section/q/cyberbullying/cyberbullying?hl=en&gl=US&ned=us'))) {
      print XML::Feed->errstr;
      return;
   }

   for my $entry ($feed->entries) {
      my ($stitle, $link);
      my $date   = $entry->issued->epoch;
      my $title  = $entry->title;
      $stitle    = $1 if ($title     =~ /(.+) - /);
      $link      = $1 if ($entry->id =~ /:cluster=(.+?)$/);

      next if $lastnews{$stitle};
      $lastnews{$stitle} = $date;

      if ($date > $lastdate) {
         my $short;

         $newlastdate = $date if ($date > $newlastdate);
      
         eval { $short = makeashorterlink($link) };

         if ($short && $short =~ /^http/) {
            next if $lastnews{$short};

            main::msg($antibullychannel, '%s :: %s', $title, $short);
            $lastnews{$short} = $date;
         }
         else {
            main::msg($antibullychannel, '%s :: %s', $title, $link);
         }
      }
   }

   if ($newlastdate) {
      unless(open my $fh, '>', $file) {
         printf("[%s] !!! modules::%s: Error writing %s\n", scalar localtime, __PACKAGE__, $file);
         return;
      }
      else {
         print $fh $newlastdate;
         close $fh;
      }
   }

   for (keys(%lastnews)) {
      delete $lastnews{$_} if ($lastnews{$_} < scalar time - 259200);
   }

   alarm(1800);
}

sub voice1 {
   my $nick = shift;

#   unless (exists %{$mychannels->{$$myprofile}{$antibullychannel}{$nick}}) {
#      main::ntc($nick, 'Join %s first.', $antibullychannel);
#      return;
#   }

   unless (exists $captacha_nicks{$nick}) {
      my $key;
      my @x = (48..57, 65..90, 97..122);

      $key .= chr($x[rand($#x)]) for 1..10;
      $captacha_nicks{$nick} = $key;
      $captacha_keys{$key}   = $nick;
   }

   main::ntc($nick, 'IF YOU WANT TO TALK IN HERE USE http://XXX/voice/?key=%s TO GET VOICE', $captacha_nicks{$nick});
}

sub voice2 {
   my ($self, $valid, $key) = @_;

   return unless (exists $captacha_keys{$key});

   my $nick = $captacha_keys{$key};
   
#   unless (exists %{$mychannels->{$$myprofile}{$antibullychannel}{$nick}}) {
#      main::ntc($nick, 'Join %s first.', $antibullychannel);
#      return;
#    }

   if ($valid) {
      main::raw('MODE %s +v %s', $antibullychannel, $nick);
      main::ntc($nick, 'Please be polite and enjoy the chat!');

      delete $captacha_keys{$key};
      delete $captacha_nicks{$nick};

      printf("[%s] === modules::%s: Voiced [%s] on %s\n", scalar localtime, __PACKAGE__, $nick, $antibullychannel);
   }
   else {
      main::ntc($nick, 'Wrong captcha. Please try again: http://XXX/voice/?key=%s', $captacha_nicks{$nick});
   }
}

### hooks

sub on_connected {
   alarm(300) unless $firstalarm;
   $firstalarm = 1;
}

sub on_join {
      my ($self, undef, $nick, undef, undef, undef) = @_;

      voice1($nick);
}

sub on_ping {
   delete $bullies{external};
}

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, $user, $host, $who) = @_;

#   if (uc($msg) eq 'VOICE') {
#      voice1($nick);
#      return;
#   }

   return unless ($ischan);
   return if ($nick eq 'YouTube');

   my ($kick, $ban, $mask);

   (my $cleanmsg = $msg) =~ y/a-zA-Z0-9  //cd;

   if ($cleanmsg =~ /$badwordregexp/i) {
      if ($target ne $antibullychannel) {
         if (exists $bullies{external}{$nick}) {
            return if ($bullies{external}{$nick} > 3);
         }
         else {
            main::msg($target, '%s: I feel offended by your recent action(s). Please read http://XXX/stop', $nick);
            $bullies{external}{$nick}++;
            return;
         }
      }
      else {
         $kick = 1;
      }
   }

   if ($kick) {
      $mask = $user . '@' . $host;
      $bullies{$mask}++;

      if ($bullies{$mask} >= $timestoban) {
         $ban = 1;
      }

      main::kick($target, $nick, 'Bully detected.');
      printf("[%s] === modules::%s: Kicked bully [%s] from %s\n", scalar localtime, __PACKAGE__, $nick, $target);
   }

   if ($ban) {
      main::raw('MODE %s +b *!%s', $target, $mask);
      delete $bullies{$mask};
      printf("[%s] === modules::%s: Banned bully [%s] from %s\n", scalar localtime, __PACKAGE__, $nick, $target);
   }

   return unless ($target eq $antibullychannel);

   # cmds
   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      my %cmds = (
         ABOUT    => 'About the Stop IRC Bullying Foundation: http://XXX/about',
         ALIAS    => 'Anti-Bully-Alias: http://XXX/fighting-bullying/anti-bully-alias',
         BEST     => 'Best practice to stop being bullied on IRC: http://XXX/fighting-bullying/best-practice',
         EMAIL    => 'E-mail us anytime at stop-irc-bullying@XXX',
         FACEBOOK => 'Our Facebook page: https://www.facebook.com/',
         HELP     => "Commands: ${$mytrigger}about, ${$mytrigger}alias, ${$mytrigger}best (or ${$mytrigger}now), ${$mytrigger}email, ${$mytrigger}facebook (or ${$mytrigger}fb), ${$mytrigger}stop, ${$mytrigger}tips, ${$mytrigger}twitter, ${$mytrigger}what, ${$mytrigger}help",
         STOP     => 'Bully-Landing-Page: http://XXX/stop',
         TIPS     => 'Helpful tips: http://XXX/fighting-bullying/helpful-tips',
         TWITTER  => 'Our twitter: https://twitter.com/',
         WHAT     => 'What is bullying on IRC: http://XXX/what-is-bullying',
      );

      $cmds{FB}  = $cmds{FACEBOOK};
      $cmds{NOW} = $cmds{BEST};

      main::msg($target, $cmds{$cmd}) if (exists $cmds{$cmd});

      # admin cmds
      return unless main::isadmin($who);

      if ($cmd eq 'TOPIC' && $args[0]) {
         main::settopic($target, "@args");
         printf("[%s] === modules::%s: %s changed topic on %s to [%s]\n", scalar localtime, __PACKAGE__, $nick, $target, "@args");
      }
      elsif ($cmd eq 'TWEET' && $args[0]) {
         if (length("@args") > 140) {
            main::msg($target, 'p tl;dt');
         }
         else {
            eval { $nt->update("@args") };
            
            unless ($@) {
               main::msg($target, 'done');
               printf("[%s] === modules::%s: %s tweeted [%s] on %s\n", scalar localtime, __PACKAGE__, $nick, "@args", $target);
            }
            else {
               main::msg($target, "$@");
            }
         }
      }
      elsif ($cmd eq 'DLTWEET') {
         eval {
            my $last = $nt->user_timeline({screen_name => 'StopIRCbullying', count => 1});

            for (@$last) {
               my $result = $nt->destroy_status($_->{id});

               if ($result) {
                  main::msg($target, 'done');
                  printf("[%s] === modules::%s: %s deleted tweet [%s] on %s\n", scalar localtime, __PACKAGE__, $nick, $_->{id}, $target);
               }
               else {
                  main::msg($target, "$@");
               }
            }
         }
      }
   }
}

1;
