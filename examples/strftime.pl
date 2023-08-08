#!perl
use v5.26;
use strict;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use I18N::Langinfo qw(
	langinfo

	ABDAY_1 ABDAY_2 ABDAY_3 ABDAY_4 ABDAY_5 ABDAY_6 ABDAY_7

	ABMON_1 ABMON_2 ABMON_3 ABMON_4  ABMON_5  ABMON_6
	ABMON_7 ABMON_8 ABMON_9 ABMON_10 ABMON_11 ABMON_12

	DAY_1 DAY_2 DAY_3 DAY_4 DAY_5 DAY_6 DAY_7

	MON_1 MON_2 MON_3 MON_4  MON_5  MON_6
	MON_7 MON_8 MON_9 MON_10 MON_11 MON_12

	D_FMT T_FMT

	AM_STR PM_STR
	);
use List::Util qw(max);
use POSIX qw(floor);
use String::Sprintf 1.10;

my %formats = (
	a   => \&abbreviated_day_name,
	A   => \&full_day_name,
	b   => \&abbreviated_month_name,
	B   => \&full_month_name,
	c   => \&preferred_representation,
	C   => \&century_number,
	d   => \&day_of_month_decimal_leading_zero,
	D   => \&american,
	e   => \&day_of_month_decimal_leading_space,
	F   => \&iso_8601_date,
	G   => \&iso_8601_week_based_year, # (with century)
	g   => \&iso_8601_week_based_year, # (without century)
	h   => \&abbreviated_month_name,
	H   => \&hour24_decimal_leading_zero,
	I   => \&hour12_decimal_leading_zero,
	j   => \&day_of_year_decimal,
	k   => \&hour24_decimal_leading_space,
	l   => \&hour12_decimal_leading_space,
	'm' => \&month_decimal,
	M   => \&minute_decimal,
	n   => sub { "\n" },
	p   => \&am_pm,
	P   => sub { lc &am_pm },
	r   => \&am_pm_time,
	R   => \&time_24_hour_no_seconds,
	's' => \&seconds_since_epoch,
	S   => \&seconds_decimal,
	t   => sub { "\t" },
	T   => \&time_24_hour_with_seconds,
	u   => \&day_of_week_sunday_is_seven,
	U   => \&week_number_first_sunday,
	V   => \&iso_8601_week_number,
	w   => \&day_of_week_sunday_is_zero,
	W   => \&week_number_first_monday,
	x   => \&preferred_date_without_time_representation,
	X   => \&preferred_time_without_date_representation,
	'y' => \&year_decimal_without_century,
	Y   => \&year_decimal_with_century,
	z   => \&time_zone_numeric,
	Z   => \&time_zone_name,
	'+' => \&date1_format,
	'%' => sub { '%' },
	'*' => sub { warn "Invalid specifier <$_[-1]>\n" },
	);
my $formatter = String::Sprintf->formatter( %formats );

# %a
sub abbreviated_day_name ( $f, $P, $V, $C ) {
	sprintf( '%' . $f . 's',
		(
			map { langinfo($_) }
			(ABDAY_1, ABDAY_2, ABDAY_3, ABDAY_4, ABDAY_5, ABDAY_6, ABDAY_7)
		)[ &day_of_week_sunday_is_zero ]
		);
	}

# %A
sub full_day_name ( $f, $P, $V, $C ) {
	sprintf( '%' . $f . 's',
		(
			map { langinfo($_) }
			(DAY_1, DAY_2, DAY_3, DAY_4, DAY_5, DAY_6, DAY_7)
		)[ &day_of_week_sunday_is_zero ]
		);
	}

# %b
sub abbreviated_month_name ( $f, $P, $V, $C ) {
	sprintf( '%' . $f . 's',
		(
			map { langinfo($_) }
			(
			ABMON_1, ABMON_2, ABMON_3, ABMON_4,  ABMON_5,  ABMON_6,
			ABMON_7, ABMON_8, ABMON_9, ABMON_10, ABMON_11, ABMON_12
			)
		)[ &month_decimal - 1 ]
		);
	}

# %B
sub full_month_name ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/O/) {
		warn "O modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	sprintf( '%' . $f . 's',
		(
			map { langinfo($_) }
			(
			MON_1, MON_2, MON_3, MON_4,  MON_5,  MON_6,
			MON_7, MON_8, MON_9, MON_10, MON_11, MON_12
			)
		)[ &month_decimal - 1 ]
		);
	}

# %c  Thu Jan  2 17:01:17 2020
sub preferred_representation ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/E/) {
		warn "E modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	# eventually make this localized
	my $this_f = $f;
	$f = '';
	sprintf( '%' . $this_f . 's',
		# "%a %b %e %H:%M:%S %Y"
		sprintf( '%s %s %s %s:%s:%s %s',
			abbreviated_day_name($f, $P, $V, $C),
			abbreviated_month_name($f, $P, $V, $C),
			day_of_month_decimal_leading_space($f, $P, $V, $C),
			hour24_decimal_leading_zero($f, $P, $V, $C),
			minute_decimal($f, $P, $V, $C),
			seconds_decimal($f, $P, $V, $C),
			year_decimal_with_century($f, $P, $V, $C)
			)
		);
	}

# %C
sub century_number ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/E/) {
		warn "E modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	my $format;
	if ($f eq '') {
		$format = '%02d';
		}
        elsif (defined $C->{flags} && $C->{flags} =~ m/\+/) {
		if (defined $C->{width}) {
			if ($C->{width} > 2) {
				$format = '%+0' . $C->{width} . 'd';
				}
			else {
				$format = '%0' . $C->{width} . 'd';
				}
			}
		else {
			$format = '%02d';
			}
		}
	else {
		$format = '%' . $f . 'd';
		}
	sprintf $format, floor($V->[0]->year / 100);
	}

# %d
sub day_of_month_decimal_leading_zero ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/O/) {
		warn "O modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	if ($f eq '') {
		$f = '02';
		}
	sprintf '%' . $f . 'd', $V->[0]->day_of_month;
	}

# %D
sub american ( $f, $P, $V, $C ) {
	my $this_f = $f;
	$f = '';
	sprintf( '%' . $this_f . 's',
		join( '/',
			&month_decimal($f, $P, $V, $C),
			&day_of_month_decimal_leading_zero($f, $P, $V, $C),
			&year_decimal_without_century($f, $P, $V, $C)
			)
		);
	}

# %e
sub day_of_month_decimal_leading_space ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/O/) {
		warn "O modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	if ($f eq '') {
		$f = '2';
		}
	sprintf '%' . $f . 'd', $V->[0]->day_of_month;
	}

# %F
sub iso_8601_date ( $f, $P, $V, $C ) {
	my $format;
	if (!defined $C->{flags} && !defined $C->{width}) {
		$format = ($V->[0]->year > 9999)
		 ? '%+04d-%02d-%02d' : '%04d-%02d-%02d';
		}
	elsif (defined $C->{width}) {
		my $year_flags = $C->{flags} // '';
		my $year_width = max($C->{width}, 6) - 6;
		if ($year_flags =~ m/\+/ && $year_width > 4) {
			$format = '%+0' . $year_width . 'd-%02d-%02d';
			}
		else {
			$format = '%' . $year_flags . $year_width
			 . 'd-%02d-%02d';
			}
		}
	else { # defined $C->{flags}
		# This circumstance is undefined in IEEE Std 1003.1-2017,
		# so this is my interpretation of what should happen.
		$format = '%' . $C->{flags} . '4d-%02d-%02d';
		}
	sprintf $format, map { $V->[0]->$_() } qw(year month day_of_month);
	}

# %G (with century)
# %g (without century)
sub iso_8601_week_based_year ( $f, $P, $V, $C ) {
	my $year = $V->[0]->year;
	my $week_number = floor(($V->[0]->day_of_year + 10 - $V->[0]->day_of_week) / 7);
	if ($week_number == 0) {
		--$year;
		}
	my $format;
	if ($f eq '') {
		$format = '%' . (($C->{specifier} eq 'g') ? '02' : '04') . 'd';
		}
        elsif ($C->{specifier} eq 'G' && defined $C->{flags} && $C->{flags} =~ m/\+/) {
		if (defined $C->{width}) {
			if ($C->{width} > 4) {
				$format = '%+0' . $C->{width} . 'd';
				}
			else {
				$format = '%0' . $C->{width} . 'd';
				}
			}
		else {
			$format = '%04d';
			}
		}
	else {
		$format = '%' . $f . 'd';
		}
	sprintf $format, ($C->{specifier} eq 'g') ? $year % 100 : $year;
	}

# %H
sub hour24_decimal_leading_zero ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/O/) {
		warn "O modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	if ($f eq '') {
		$f = '02';
		}
	sprintf '%' . $f . 'd', $V->[0]->hour;
	}

# %I
sub hour12_decimal_leading_zero ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/O/) {
		warn "O modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	my $h = $V->[0]->hour;
	$h %= 12 if $h > 12;
	if ($f eq '') {
		$f = '02';
		}
	sprintf '%' . $f . 'd', $h;
	}

# %j
sub day_of_year_decimal ( $f, $P, $V, $C ) {
	if ($f eq '') {
		$f = '03';
		}
	sprintf '%' . $f . 'd', $V->[0]->day_of_year;
	}

# %k
sub hour24_decimal_leading_space ( $f, $P, $V, $C ) {
	if ($f eq '') {
		$f = '2';
		}
	sprintf '%' . $f . 's', $V->[0]->hour;
	}

# %l
sub hour12_decimal_leading_space ( $f, $P, $V, $C ) {
	my $h = $V->[0]->hour;
	$h %= 12 if $h > 12;
	if ($f eq '') {
		$f = '2';
		}
	sprintf '%' . $f . 's', $h;
	}

# %m
sub month_decimal ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/O/) {
		warn "O modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	if ($f eq '') {
		$f = '02';
		}
	sprintf '%' . $f . 'd', $V->[0]->month;
	}

# %M
sub minute_decimal ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/O/) {
		warn "O modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	if ($f eq '') {
		$f = '02';
		}
	sprintf '%' . $f . 'd', $V->[0]->minute;
	}

# %p
sub am_pm ( $f, $P, $V, $C ) {
	sprintf( '%' . $f . 's',
		($V->[0]->hour > 11) ? langinfo( PM_STR ) : langinfo( AM_STR )
		);
	}

# %r
sub am_pm_time ( $f, $P, $V, $C ) {
	my $this_f = $f;
	$f = '';
	sprintf( '%' . $this_f . 's',
		join( ':',
			hour12_decimal_leading_zero($f, $P, $V, $C),
			minute_decimal($f, $P, $V, $C),
			seconds_decimal($f, $P, $V, $C)
			) . ' ' . am_pm($f, $P, $V, $C)
		);
	}

# %R
sub time_24_hour_no_seconds ( $f, $P, $V, $C ) {
	sprintf( '%' . $f . 's',
		sprintf '%02d:%02d', map { $V->[0]->$_() } qw(hour minute)
		);
	}

# %s
sub seconds_since_epoch ( $f, $P, $V, $C ) {
	if ($f eq '') {
		$f = 'l';
		}
	sprintf '%' . $f . 'd', $V->[0]->epoch;
	}

# %S
sub seconds_decimal ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/O/) {
		warn "O modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	if ($f eq '') {
		$f = '02';
		}
	sprintf '%' . $f . 'd', $V->[0]->second;
	}

# %T
sub time_24_hour_with_seconds ( $f, $P, $V, $C ) {
	sprintf( '%' . $f . 's',
		sprintf '%02d:%02d:%02d', map { $V->[0]->$_() } qw(hour minute second)
		);
	}

# %u
sub day_of_week_sunday_is_seven ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/O/) {
		warn "O modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	sprintf '%' . $f . 'd', $V->[0]->day_of_week;
	}

# %U
sub week_number_first_sunday ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/O/) {
		warn "O modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	if ($f eq '') {
		$f = '02';
		}
	my $day_of_week = $V->[0]->day_of_week % 7;
	my $week_number = floor(($V->[0]->day_of_year
	 + 6 - $day_of_week) / 7);
	sprintf '%' . $f . 'd', $week_number;
	}

# %V
sub iso_8601_week_number ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/O/) {
		warn "O modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	if ($f eq '') {
		$f = '02';
		}
	my $week_number = $V->[0]->week;
	my $month = $V->[0]->month;
	if (($week_number == 52 && $month == 1)
	 || ($week_number == 1 && $month == 12)) {
		$week_number = 53;
		}
	sprintf '%' . $f . 'd', $week_number;
	}

# %w
sub day_of_week_sunday_is_zero ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/O/) {
		warn "O modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	sprintf '%' . $f . 'd', $V->[0]->day_of_week % 7;
	}

# %W
sub week_number_first_monday ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/O/) {
		warn "O modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	if ($f eq '') {
		$f = '02';
		}
	my $day_of_week = $V->[0]->day_of_week;
	my $week_number = floor(($V->[0]->day_of_year
	 + 7 - $day_of_week) / 7);
	sprintf '%' . $f . 'd', $week_number;
	}

# %x
sub preferred_date_without_time_representation ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/E/) {
		warn "E modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	sprintf( '%' . $f . 's',
		$formatter->sprintf( langinfo( D_FMT ), $V->[0] )
		);
	}

# %X
sub preferred_time_without_date_representation ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/E/) {
		warn "E modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	sprintf( '%' . $f . 's',
		$formatter->sprintf( langinfo( T_FMT ), $V->[0] )
		);
	}

# %y
sub year_decimal_without_century ( $f, $P, $V, $C ) {
	if (defined $C->{modifier}) {
		if ($C->{modifier} =~ m/E/) {
			warn "E modifier is not yet implemented in %$C->{specifier}\n";
			return;
			}
		if ($C->{modifier} =~ m/O/) {
			warn "O modifier is not yet implemented in %$C->{specifier}\n";
			return;
			}
		}
	if ($f eq '') {
		$f = '02';
		}
	sprintf '%' . $f . 'd', $V->[0]->year % 100;
	}

# %Y
sub year_decimal_with_century ( $f, $P, $V, $C ) {
	if (defined $C->{modifier} && $C->{modifier} =~ m/E/) {
		warn "E modifier is not yet implemented in %$C->{specifier}\n";
		return;
		}
	my $format;
	if ($f eq '') {
		$format = '%04d';
		}
	elsif (defined $C->{flags} && $C->{flags} =~ m/\+/) {
		if (defined $C->{width}) {
			if ($C->{width} > 4) {
				$format = '%+0' . $C->{width} . 'd';
				}
			else {
				$format = '%0' . $C->{width} . 'd';
				}
			}
		else {
			$format = '%04d';
			}
		}
	else {
		$format = '%' . $f . 'd';
		}
	sprintf $format, $V->[0]->year;
	}

# %z
# https://stackoverflow.com/a/47428274/2766176
sub time_zone_numeric ( $f, $P, $V, $C ) {
	my @local = localtime;
	my @gmtime = gmtime;

	my $hour_diff = $local[2] - $gmtime[2];
	my $min_diff  = $local[1] - $gmtime[1];

	my $total_diff = $hour_diff * 60 + $min_diff;
	my $hour = floor($total_diff / 60);
	my $min = abs($total_diff - $hour * 60);

	# Adjust for a localtime that is east of Greenwich
	# if the local day of month, month. or year is greater than
	# the UTC day of month, month, or year respectively.
	$hour += 24 if ($local[3] > $gmtime[3] || $local[4] > $gmtime[4]
	 || $local[5] > $gmtime[5]);

	# Adjust for a localtime that is west of Greenwich
	# if the local day of month, month. or year is less than
	# the UTC day of month, month, or year respectively.
	$hour -= 24 if ($local[3] < $gmtime[3] || $local[4] < $gmtime[4]
	 || $local[5] < $gmtime[5]);

	sprintf( '%' . $f . 's',
		sprintf('%+03d%02d', $hour, $min)
		);
	}

# %Z
sub time_zone_name ( $f, $P, $V, $C ) {
	sprintf( '%' . $f . 's',
		( POSIX::tzname() )[ (localtime)[8] ]
		);
	}

# %+  Thu Jan  2 17:01:17 EST 2020
sub date1_format ( $f, $P, $V, $C ) {
	my $this_f = $f;
	$f = '';
	sprintf( '%' . $this_f . 's',
		# "%a %b %e %H:%M:%S %Z %Y"
		sprintf( '%s %s %s %s:%s:%s %s %s',
			abbreviated_day_name($f, $P, $V, $C),
			abbreviated_month_name($f, $P, $V, $C),
			day_of_month_decimal_leading_space($f, $P, $V, $C),
			hour24_decimal_leading_zero($f, $P, $V, $C),
			minute_decimal($f, $P, $V, $C),
			seconds_decimal($f, $P, $V, $C),
			time_zone_name($f, $P, $V, $C),
			year_decimal_with_century($f, $P, $V, $C)
			)
		);
	}

use Cwd qw(realpath);
use File::Spec;
use Getopt::Std qw(getopts);
use POSIX qw(EXIT_SUCCESS EXIT_FAILURE);
use Time::Moment;

my $this_script = (File::Spec->splitpath(realpath($0)))[2];

my $default_when = Time::Moment->now;

my $option_string = '?hw:';
my %option;

getopts($option_string, \%option)
 or die 'Usage: ', $this_script, " [-? | -h] | [-w when] format ...\n";

my $argument_count = scalar @ARGV;
if (exists $option{'?'} || exists $option{h}) {
	print STDERR 'Usage: ', $this_script, " [-? | -h] | [-w when] format ...\n";
	print STDERR " -?:         print usage string\n";
	print STDERR " -h:         print usage string\n";
	print STDERR " -w when:    specify an ISO 8601 date/time to use (default is now)\n";
	print STDERR " format ...: one or more strftime() formats\n";

	exit(($argument_count == 0) ? EXIT_SUCCESS : EXIT_FAILURE);
	}

my $when;
eval {
	$when = (defined $option{w})
	 ? Time::Moment->from_string($option{w}, lenient => 0)
	 : $default_when;
	};
if ($@) {
	die $this_script, qq{: ERROR: Couldn't parse the "when" parameter as an ISO 8601 date/time.\n};
	}

foreach my $argument (@ARGV) {
	say $formatter->sprintf( $argument, $when );
	}

=encoding utf8

=head1 NAME

strftime - format a time value

=head1 SYNOPSIS

	% strftime [-? | -h] | [-w when] format ...

	% strftime %H:%M

=head1 DESCRIPTION

This is basically the C<date> command, but implemented with L<String::Sprintf>
as a demonstration. If the C<-w when> option is provided, it uses the given
date/time in ISO 8601 date/time format as its basis; if no C<-w when> option
is provided, it uses the current date/time. One output line will be generated
for each C<format> given on the command line.

Rather than work with a list of arguments, this script
knows how to use a single value to fill in many specifiers. Each subroutine
gets a list of all the arguments to C<sprintf> and each merely uses the
first value.

=head2 The strftime specifiers

From the I<strftime(3)> manpage:

   %a     The abbreviated name of the day of the week according to the
		  current locale.  (Calculated from tm_wday.)

   %A     The full name of the day of the week according to the current
		  locale.  (Calculated from tm_wday.)

   %b     The abbreviated month name according to the current locale.
		  (Calculated from tm_mon.)

   %B     The full month name according to the current locale.
		  (Calculated from tm_mon.)

   %c     The preferred date and time representation for the current
		  locale.

   %C     The century number (year/100) as a 2-digit integer. (SU)
		  (Calculated from tm_year.)

   %d     The day of the month as a decimal number (range 01 to 31).
		  (Calculated from tm_mday.)

   %D     Equivalent to %m/%d/%y.  (Yecch—for Americans only.  Americans
		  should note that in other countries %d/%m/%y is rather common.
		  This means that in an international context, this format is
		  ambiguous and should not be used.) (SU)

   %e     Like %d, the day of the month as a decimal number, but a
		  leading zero is replaced by a space. (SU) (Calculated from
		  tm_mday.)

   %F     Equivalent to %Y-%m-%d (the ISO 8601 date format). (C99)

   %G     The ISO 8601 week-based year with century as a
		  decimal number.  The 4-digit year corresponding to the ISO
		  week number (see %V).  This has the same format and value as
		  %Y, except that if the ISO week number belongs to the previous
		  or next year, that year is used instead. (TZ) (Calculated from
		  tm_year, tm_yday, and tm_wday.)

   %g     Like %G, but without century, that is, with a 2-digit year
		  (00–99). (TZ) (Calculated from tm_year, tm_yday, and tm_wday.)

   %h     Equivalent to %b.  (SU)

   %H     The hour as a decimal number using a 24-hour clock (range 00
		  to 23).  (Calculated from tm_hour.)

   %I     The hour as a decimal number using a 12-hour clock (range 01
		  to 12).  (Calculated from tm_hour.)

   %j     The day of the year as a decimal number (range 001 to 366).
		  (Calculated from tm_yday.)

   %k     The hour (24-hour clock) as a decimal number (range 0 to 23);
		  single digits are preceded by a space.  (See also %H.)
		  (Calculated from tm_hour.)  (TZ)

   %l     The hour (12-hour clock) as a decimal number (range 1 to 12);
		  single digits are preceded by a space.  (See also %I.)
		  (Calculated from tm_hour.)  (TZ)

   %m     The month as a decimal number (range 01 to 12).  (Calculated
		  from tm_mon.)

   %M     The minute as a decimal number (range 00 to 59).  (Calculated
		  from tm_min.)

   %n     A newline character. (SU)

   %p     Either "AM" or "PM" according to the given time value, or the
		  corresponding strings for the current locale.  Noon is treated
		  as "PM" and midnight as "AM".  (Calculated from tm_hour.)

   %P     Like %p but in lowercase: "am" or "pm" or a corresponding
		  string for the current locale.  (Calculated from tm_hour.)
		  (GNU)

   %r     The time in a.m. or p.m. notation.  In the POSIX locale this
		  is equivalent to %I:%M:%S %p.  (SU)

   %R     The time in 24-hour notation (%H:%M).  (SU) For a version
		  including the seconds, see %T below.

   %s     The number of seconds since the Epoch, 1970-01-01 00:00:00
		  +0000 (UTC). (TZ) (Calculated from mktime(tm).)

   %S     The second as a decimal number (range 00 to 60).  (The range
		  is up to 60 to allow for occasional leap seconds.)
		  (Calculated from tm_sec.)

   %t     A tab character. (SU)

   %T     The time in 24-hour notation (%H:%M:%S).  (SU)

   %u     The day of the week as a decimal, range 1 to 7, Monday being
		  1.  See also %w.  (Calculated from tm_wday.)  (SU)

   %U     The week number of the current year as a decimal number, range
		  00 to 53, starting with the first Sunday as the first day of
		  week 01.  See also %V and %W.  (Calculated from tm_yday and
		  tm_wday.)

   %V     The ISO 8601 week number (see NOTES) of the current year as a
		  decimal number, range 01 to 53, where week 1 is the first week
		  that has at least 4 days in the new year.  See also %U and %W.
		  (Calculated from tm_year, tm_yday, and tm_wday.)  (SU)

   %w     The day of the week as a decimal, range 0 to 6, Sunday being
		  0.  See also %u.  (Calculated from tm_wday.)

   %W     The week number of the current year as a decimal number, range
		  00 to 53, starting with the first Monday as the first day of
		  week 01.  (Calculated from tm_yday and tm_wday.)

   %x     The preferred date representation for the current locale
		  without the time.

   %X     The preferred time representation for the current locale
		  without the date.

   %y     The year as a decimal number without a century (range 00 to
		  99).  (Calculated from tm_year)

   %Y     The year as a decimal number including the century.
		  (Calculated from tm_year)

   %z     The +hhmm or -hhmm numeric timezone (that is, the hour and
		  minute offset from UTC). (SU)

   %Z     The timezone name or abbreviation.

   %+     The date and time in date(1) format. (TZ) (Not supported in
		  glibc2.)

   %%     A literal '%' character.

=head1 COPYRIGHT

Copyright E<copy> 2020, brian d foy, all rights reserved.

=head1 LICENSE

You can use this code under the terms of the Artistic License 2.

=cut

