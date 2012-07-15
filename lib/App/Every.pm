# ABSTRACT: Create and queue a cronjob
package App::Every;
use strict;
use warnings;
use feature qw( switch say );
use Cwd;
use Digest::MD5 qw( md5_hex );

sub help {
    warn "Form: $0 [--help] [-n|--dry-run] [-l] ([num] unit)... [--] program\n";
    warn "--help - Show the manpage for this command.\n";
    warn "-n     - Don't actually install the crontab\n";
    warn "num    - Number of the unit, defaults to 1\n";
    warn "unit   - min(ute)(s), hour(s), day(s), week(s), month(s)\n";
    warn "         or the name of a day of week, eg tue(sday)\n";
    warn "-l     - Add locking so that more then one copy can't run at once.\n";
    warn "--dry-run\n";
    exit(1);
}

=for future todo

Update grammar to replace optional '--' with required 'do' to separate the
program.

Later: Without 'do', behave like 'at' and read an ad-hoc script from stdin.
Also: Small wrapper for 'at' that adds support for a 'do' argument, with a
set of rc files to alias at with its replacement.  Since 'do' would be invalid
in an at timespec, it won't interfere with traditional use.

This would ultimately allow for a much more sophisticated grammar
(eg, Marpa).

If running as root, default to installing in, in order of preference:
    /etc/cron.<period> if available and appropriate
    /etc/cron.d if available
    /etc/crontab

With --user option to install via the crontab command instead.
Likewise, --system option to try to install in the system crontab even if
we're not root(?) (with sudo?)

    every day at 3pm do program...

    every minute on Feb 03 at 3pm do program...

    every day in march do program...

    at <time>

Where time is HH(:MM)? (24hour time) HH(:MM(am|pm))? (12hour time)
Or noon or midnight.  Perhaps later, sunrise and sunset.

    on <month> <day>

Where month is a full month name or an unambiguous abbreviation and day is
a number optionally followed by a noise suffix (eg th, nd, etc)

    in <month>

Where month is a month as in on.

=cut



my %monmap = (
    mon   =>1, tue    =>2, wed      =>3, thu     =>4, fri   =>5, sat     =>6, sun   =>7,
    monday=>1, tuesday=>2, wednesday=>3, thursday=>4, friday=>5, saturday=>6, sunday=>7
    );

my %schedule = (
   minute => "*",
   hour   => "*",
   day    => "*",
   month  => "*",
   dow    => "*" );


=classmethod sub main( @args )

Takes the same arguments as every commandline. Currently this isn't very
useful, but it was a first step in pushing the implementation into a module.

=cut

sub main {
    my $class = shift;
    my ($min,$hour,$day,$mon,$year,$dow) = (localtime())[1..6];
    my $lock    = 0;
    my $dry_run = 0;

    my %cronenv;
    my @program;
    while (@_) {
        my $amount = 1;
        given (shift) {
            when ('--') {
                @program = @_;
                last;
            }
            when ('-l') {
                $lock = 1;
            }
            when ([qw( -n --dry-run )]) {
                $dry_run = 1;
            }
            when (/^--help/) {
                exec("perldoc $0");
            }
            when (/^-/) {
                help();
            }
            when (/^\d+$/) {
                ($amount,$_) = ($_,shift);
                continue;
            }
            when ([qw( min mins minute minutes )]) {
                @schedule{qw( minute )}          = ("*/$amount");
            }
            when ([qw( hour hours              )]) {
                @schedule{qw( minute hour)}      = ($min, "*/$amount");
            }
            when (/^[@]hour(ly)?$/) {
                @schedule{qw( minute hour day month dow )} = (q{@hourly}, q{}, q{}, q{}, q{});
            }
            when ([qw( midnight )]) {
                @schedule{qw( minute hour day)}  = ("0", "0", "*/$amount");
            }
            when ([qw( day days                )]) {
                @schedule{qw( minute hour day )} = ($min,$hour,"*/$amount");
            }
            when (/^( [@]day | [@]daily | [@]midnight )$/x) {
                @schedule{qw( minute hour day month dow )} = (q{@daily}, q{}, q{}, q{}, q{});
            }
            when ([qw( week weeks )]) {
                die "Don't know how to iterate less then once a week but more then once a month.\n" if $amount > 1;
                @schedule{qw( minute hour dow )} = ($min,$hour,$dow);
            }
            when (/^[@]week(ly)?$/) {
                die "Can't set an amount for a weekly entry\n" if $amount > 1;
                @schedule{qw( minute hour day month dow )} = (q{@weekly}, q{}, q{}, q{}, q{});
            }
            when (\%monmap) {
                @schedule{qw( minute hour dow )} = ($min,$hour,$monmap{$_});
            }
            when ([qw( month months )]) {
                @schedule{qw( minute hour day month )} = ($min,$hour,$day,"*/$amount");
            }
            when ([qw( year )]) {
                @schedule{qw( minte hour day month )} = ($min,$hour,$day,$mon);
            }
            when (/^[@]year(ly)?$/) {
                @schedule{qw( minute hour day month dow )} = (q{@yearly}, q{}, q{}, q{}, q{});
            }
            when (/^[@]?reboot$/) {
                @schedule{qw( minute hour day month dow )} = (q{@reboot}, q{}, q{}, q{}, q{});
            }
            default {
                @program = ($_,@_);
                last;
            }
        }
    }
    unless (@program) {
        help();
    }

    unshift @program, q{cd "}.getcwd().q{"; };

    @cronenv{qw( PATH SHELL )} = @ENV{qw( PATH SHELL )};

    if ($lock) {
        my $lockfile = "/tmp/every_lock_" .
           md5_hex(join ' ',@schedule{sort keys %schedule}, @program);
        $cronenv{'LOCKFILE'} = $lockfile;
        @program = ('[ ! -f $LOCKFILE -o ! -d /proc/`[ -f $LOCKFILE ] && cat $LOCKFILE` ] && ( echo $$ > $LOCKFILE ;', @program, ' ; rm $LOCKFILE )');
    }

    my $crontab = join ' ',  @schedule{qw( minute hour day month dow )}, @program;
    say "$_=$cronenv{$_}" for keys %cronenv;
    say $crontab;

    unless ($dry_run) {
        open my $cron, "|-", "crontab";
        print $cron qx{crontab -l 2> /dev/null};
        say $cron "$_=$cronenv{$_}" for keys %cronenv;
        say $cron $crontab;
        close $cron;
    }
}
1;

=head1 SYNOPSIS

    use App::Every;

    App::Every->main( @ARGV );

=head1 DESCRIPTION

Creates and queues a cronjob, see L<every> for details.

=head1 GETTING

You can fetch a current release as a standalone script with:

    curl -O https://raw.github.com/iarna/App-Every/master/packed/every
