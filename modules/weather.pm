package weather;

use utf8;
use strict;
use warnings;

# https://rt.cpan.org/Public/Bug/Display.html?id=54790
#use YAML::Tiny qw(LoadFile DumpFile);
use YAML qw(LoadFile DumpFile);

use Geo::Coder::Google;
use Weather::YR;
use Weather::YR::Locationforecast;

my $myprofile;
my $mytrigger;

my $cfg;
my $changed;
my %userlocations;

my %symbols = (
   SUN                 => 'Sunny',
   LIGHTCLOUD          => 'Light clouds',
   PARTLYCLOUD         => 'Partly cloudy',
   CLOUD               => 'Cloudy',
   LIGHTRAINSUN        => 'Light rain, sunny',
   LIGHTRAINTHUNDERSUN => 'Light rain, thunder, sunny',
   SLEETSUN            => 'Sleet, sunny',
   SNOWSUN             => 'Snow, sunny',
   LIGHTRAIN           => 'Light rain',
   RAIN                => 'Rain',
   RAINTHUNDER         => 'Rain, thunder',
   SLEET               => 'Sleet',
   SNOW                => 'Snow',
   SNOWTHUNDER         => 'Snow, thunder',
   FOG                 => 'Foggy',
   SLEETSUNTHUNDER     => 'Sleet, sunny, thunder',
   SNOWSUNTHUNDER      => 'Snow, sunny, thunder',
   LIGHTRAINTHUNDER    => 'Light rain, thunder',
   SLEETTHUNDER        => 'Sleet, thunder'
);

my @winddesc = (
   'Calm',
   'Light air',
   'Light breeze',
   'Gentle breeze',
   'Moderate breeze',
   'Fresh breeze',
   'Strong breeze',
   'High wind',
   'Gale',
   'Strong gale',
   'Storm',
   'Violent storm',
   'Hurricane'
);

### start config

my $cfgname = "$ENV{HOME}/.bot/%s/%s.yml"; # package name, profile name

### end config

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $myprofile = $self->{myprofile};
   $mytrigger = $self->{mytrigger};

   $cfg = sprintf($cfgname, __PACKAGE__, $$myprofile);

   loadcfg() if -e $cfg;

   return $self;
}

sub loadcfg {
   printf("[%s] === modules::%s: Loading config: %s\n", scalar localtime, __PACKAGE__, $cfg);
   %userlocations = LoadFile($cfg);
}

sub savecfg {
   if ($changed) {
      printf("[%s] === modules::%s: Saving config: %s\n", scalar localtime, __PACKAGE__, $cfg);
      DumpFile($cfg, %userlocations);
      $changed = 0;
   }
}

### hooks

sub on_ownquit {
   savecfg();
}

sub on_ping {
   savecfg();
}

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      $target = $nick unless $ischan;

      # cmds 
      if ($cmd eq 'WEATHER' || $cmd eq 'W') {
         my ($loc, $lat, $lon);

         unless ($args[0]) {
            if (exists $userlocations{$nick}) {
               $loc = $userlocations{$nick}{loc};
               $lat = $userlocations{$nick}{lat};
               $lon = $userlocations{$nick}{lon};
            }
            else {
               main::msg($target, 'last location for %s is unknown, please specify one and I\'ll remember it.', $nick);
               return;
            }
         }
         else {
            my $geo   = Geo::Coder::Google->new(apiver => 3);
            my $input = $geo->geocode(location => "@args");

            unless ($input) {
               main::msg($target, 'no match');
               return;
            }

            $loc = $input->{formatted_address};
            $lat = $input->{geometry}{location}{lat};
            $lon = $input->{geometry}{location}{lng};
         
            $userlocations{$nick}{loc} = $loc;
            $userlocations{$nick}{lat} = $lat;
            $userlocations{$nick}{lon} = $lon;

            $changed = 1;
         }

         printf("[%s] === modules::%s: Weather [%s] on %s by %s\n", scalar localtime, __PACKAGE__, $loc, $target, $nick);

         my $fcloc = Weather::YR::Locationforecast->new({latitude => $lat, longitude => $lon});
         my $fc    = $fcloc->forecast;

         my $celcius   = $fc->[0]->{temperature}->{value};
         my $farenheit = $celcius * (9/5) + 32;
         my $symbol    = $fc->[1]->{name};
         my $humidity  = $fc->[0]->{humidity}{value};
         my $beaufort  = $fc->[0]->{windspeed}{beaufort};
         my $windspeed = $fc->[0]->{windspeed}{mps};
         my $winddir   = $fc->[0]->{winddirection}->{name};
         my $fog       = $fc->[0]->{fog}{percent};

         main::msg($target, "%s :: %.1f°C / %.1f°F :: %s :: Hum: %u%% :: Wind: %s (%u m/s) from %s :: Fog: %u%%", $loc, $celcius, $farenheit, $symbols{$symbol}, $humidity, $winddesc[$beaufort], $windspeed, $winddir, $fog);
      }
   }
}

sub on_unload {
   savecfg();
}

1;
