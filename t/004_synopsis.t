# -*- perl -*-

# t/004_sysopsis.t - test syntax and result for the synopsis

use Test::More tests => 2;
use String::Sprintf 1.10;

sub commify {
    my $n = shift;
    $n =~ s/(\.\d+)|(?<=\d)(?=(?:\d{3})+\b)/$1 || ','/ge;
    return $n;
}
my $f = String::Sprintf->formatter(
  N => sub {
    my($trimmed_format, $parameters, $values, $format_components) = @_;
    return commify(sprintf "%${trimmed_format}f", $parameters->[-1]);
  }
);
isa_ok ($f, 'String::Sprintf');

my $out = $f->sprintf('(%10.2N, %10.2N)', 12345678.901, 87654.321);

is ($out, '(12,345,678.90,   87,654.32)', 'synopsis');
