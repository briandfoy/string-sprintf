# -*- perl -*-

# t/005_results.t - test the end result after formatting

use Test::More tests => 11;
use String::Sprintf 1.10;

my $formatter = String::Sprintf->formatter(
  F => sub {
    my($trimmed_format, $parameters, $values, $format_components) = @_;
    my $s = sprintf "%${trimmed_format}f", $parameters->[-1];
    $s =~ s/\.?0*$//;
    return $s;
  },
  W => sub {
    my($trimmed_format, $parameters, $values, $format_components) = @_;
    my($format, $arguments);
    my $modifier = $format_components->{modifier};
    if (defined $format_components->{parameter_index}) {
      $format = '%' . String::Sprintf->trimmed_format($format_components)
       . 'u';
      $arguments = $values;
    } elsif (defined $modifier && $modifier =~ m/Q/) {
      $modifier =~ tr/Q//d;
      $format = '"%'
       . String::Sprintf->trimmed_format($format_components,
        { modifier => $modifier }) . 'u"';
      $arguments = $parameters;
    } else {
      $format = '%' . $trimmed_format . 'u';
      $arguments = $parameters;
    }
    sprintf $format, @{ $arguments };
  }
);

isa_ok ($formatter, 'String::Sprintf');

is($formatter->sprintf('(%0.3f)', 12.25), '(12.250)', 'fallback 1');
is($formatter->sprintf('(%0.3f)', 12.4999), '(12.500)', 'fallback 2');
is($formatter->sprintf('(%0.3F)', 12.4999), '(12.5)', 'custom 1');
is($formatter->sprintf('(%0.3F)', 9.9999), '(10)', 'custom 2');
is($formatter->sprintf('(%0.3f, %0.3F)', 11.9999, 11.9999), '(12.000, 12)',
 'mixed');

my ($year, $month, $day) = (2022, 12, 2);
my ($year_width, $month_width, $day_width) = (4, 2, 2);
my $format_BR = '%2$0*5$W/%3$0*4$W/%1$0*6$W';
my $format_DE = '%2$0*5$W.%3$0*4$W.%1$0*6$W';
my $format_JP = '%1$0*6$W-%3$0*4$W-%2$0*5$W';
my $format_US = '%3$0*4$W/%2$0*5$W/%1$0*6$W';
is($formatter->sprintf('%*QW %QW %QW',
 $year_width, $year, $day, $month),
 '"2022" "2" "12"', 'width as argument');
is($formatter->sprintf($format_BR,
 $year, $day, $month, $month_width, $day_width, $year_width),
 '02/12/2022', 'numbered arguments and widths 1');
is($formatter->sprintf($format_DE,
 $year, $day, $month, $month_width, $day_width, $year_width),
 '02.12.2022', 'numbered arguments and widths 2');
is($formatter->sprintf($format_JP,
 $year, $day, $month, $month_width, $day_width, $year_width),
 '2022-12-02', 'numbered arguments and widths 3');
is($formatter->sprintf($format_US,
 $year, $day, $month, $month_width, $day_width, $year_width),
 '12/02/2022', 'numbered arguments and widths 4');
