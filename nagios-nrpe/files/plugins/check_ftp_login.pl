#!/usr/bin/perl

use Net::FTP;
use strict;
use warnings;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../perl/lib";
# needs libmonitoring-plugin-perl package on Debian
use Monitoring::Plugin;
use File::Basename;

# Vars
my ($code,$message);
my ($SERVER,$USER,$PASSWORD,$FILE,$PATH);
my ($ftp);

my $exit_code = 0;
my (@line, @msg);

my $t_out = 15;
my $VERSION = 1;
my $PROGNAME = basename($0);

# Teststring ./test.pl -H ksl-vw2k530.gsdnet.ch -u ew.luks054.ksl -p ERcd45.e

my $p = Monitoring::Plugin->new(
        usage => "Usage: %s -H <hostname> -u <ftpuser> -p <ftppassword>",
        version => $VERSION,
        blurb => "Checks FTP Server with login/password",
        extra => "
            Options:
        -H
          Host name or IP Address
        -u
          FTP Username
        -p
          FTP Password
        -t
          Timeout (Default: $t_out seconds)
        ",
        );

$p->add_arg(
    spec => 'H|hostname=s',
    help =>
        qq{-H, --hostname=STRING
                Hostname},
);

$p->add_arg(
    spec => 'u|ftpuser=s',
    help =>
        qq{-u, --ftpuser=STRING
                FTP User},
);

$p->add_arg(
    spec => 'p|ftppassword=s',
    help =>
        qq{-p, --ftppassword=STRING
                FTP Password},
);

$p->add_arg(
    spec => 't|timeout=i',
    help =>
        qq{-t, --timeout=STRING
                Timeout},
);

# Parse arguments and process standard ones (e.g. usage, help, version)
$p->getopts;

# perform sanity checking on command line options
if (defined $p->opts->t) {
    $t_out = $p->opts->timeout;
}

# Main
$ftp = Net::FTP->new($p->opts->H, Debug => 0, Timeout => $t_out)
        or die "Cannot connect to $SERVER: $@";

$ftp->login($p->opts->u,$p->opts->p)
        or die "Cannot login ", $ftp->message;

$ftp->quit;

# Output
($code, $message) = $p->check_messages();
$p->plugin_exit( $code, $message );
