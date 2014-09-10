package weather;

use utf8;
use strict;
use warnings;

# https://rt.cpan.org/Public/Bug/Display.html?id=54790
#use YAML::Tiny qw(LoadFile DumpFile);
use YAML qw(LoadFile DumpFile);

use DateTime::TimeZone;
use Geo::Coder::Google;
use Weather::YR;

my $myprofile;
my $mytrigger;

my $cfg;
my $changed;
my %userlocations;

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

sub loadcfg {
   printf("[%s] === modules::%s: Loading config: %s\n", scalar localtime, __PACKAGE__, $cfg);
   %userlocations = LoadFile($cfg);
}

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $myprofile = $self->{myprofile};
   $mytrigger = $self->{mytrigger};

   $cfg = sprintf($cfgname, __PACKAGE__, $$myprofile);

   loadcfg() if (-e $cfg);

   return $self;
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

      #$target = $nick unless ($ischan);
      return unless ($ischan);

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
               main::msg($target, q{last location for %s is unknown, please specify one (%sw <location>) and I'll remember it.}, $nick, $$mytrigger);
               return;
            }
         }
         else {
            my $geo = Geo::Coder::Google->new(apiver => 3, language => 'en');

            my $input;
            eval { $input = $geo->geocode(location => "@args") };

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

         my $fcloc;
         eval { $fcloc = Weather::YR->new(lat => $lat, lon => $lon, tz => DateTime::TimeZone->new(name => 'Europe/Berlin'), lang => 'en'); };

         unless ($fcloc) {
            main::msg($target, 'error fetching weather data, try again later');
            return;
         }

         my $fc = $fcloc->location_forecast->now;
            
         my $celsius    = $fc->temperature->celsius;
         my $fahrenheit = $fc->temperature->fahrenheit;
         my $symbol     = $fc->precipitation->symbol->text;
         my $precip     = $fc->precipitation->symbol->number;
         my $humidity   = $fc->humidity->percent;
         my $cloudiness = $fc->cloudiness->percent;
         my $beaufort   = $fc->wind_speed->beaufort;
         my $winddir    = $fc->wind_direction->name;
         my $fog        = $fc->fog->percent;

         main::msg($target, "%s :: %.1f°C / %.1f°F :: %s :: Pop: %u%% :: Cld: %u%% :: Hum: %u%% :: Fog: %u%% :: Wnd: %s from %s", $loc, $celsius, $fahrenheit, $symbol, $precip, $cloudiness, $humidity, $fog, $winddesc[$beaufort], $winddir);
      }
   }
}

sub on_unload {
   savecfg();
}

1;
