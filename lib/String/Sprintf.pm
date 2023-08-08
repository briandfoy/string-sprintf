package String::Sprintf;

use strict;
use warnings;

use 5.010_000; # for // operator

use Carp;

our $VERSION = '1.10';

sub formatter {  # constructor
    my $class = shift;
    (@_ % 2) and croak 'Odd number of arguments';
    my %handler = @_;
    $handler{'*'} ||= 'sprintf';   # default

    # sanity check
    my @errors;
    while(my($k, $v) = each %handler) {
        UNIVERSAL::isa($v, 'CODE')
          or !defined $v
          or $v eq 'sprintf'
          or push @errors, $k;
    }
    if(@errors) {
        my $errors = join ', ', @errors;
        my($s, $have) = @errors == 1 ? ('', 'has') : ('s', 'have');
        croak "Format$s $errors $have no CODE ref as a handler";
    }
    return bless \%handler, $class;
}

#
# A conversion flag is a space, a zero, a Unicode mathematical symbol,
# a Unicode punctuation mark, a Unicode currency symbol,
# or a Unicode modifier symbol, but not a dollar sign, a percent sign,
# an asterisk, a period, an opening brace, or a closing brace.
#
sub IsConversionFlag {
    return << 'END';
+0020
+0030
+utf8::IsSm
+utf8::IsPunct
+utf8::IsSc
+utf8::IsSk
-0024
-0025
-002A
-002E
-007B
-007D
END
}

#
# A conversion modifier is an ASCII upper case letter used to modify
# a conversion specifier. Although sprintf()-type conversions haven’t
# traditionally used modifiers, strftime()-type conversions do use them.
#
sub IsConversionModifier {
    return << 'END';
+0041	005A
END
}

#
# A conversion specifier is the format letter used for sprintf()-type
# conversions, i.e. A through Z and a through z, as well as non-letters
# like Unicode mathematical symbols, Unicode punctuation marks,
# Unicode currency symbols, or Unicode modifier symbols, but not ASCII
# mathematical symbols other than + (for strftime()-type conversions),
# ASCII punctuation marks, ASCII currency symbols, or ASCII modifier
# symbols.
#
sub IsConversionSpecifier {
    return << 'END';
+0041	005A
+0061	007A
+utf8::IsSm
+utf8::IsPunct
+utf8::IsSc
+utf8::IsSk
-0020	002A
-002C	0040
-005B	0060
-007B	007E
END
}

#
# Parse conversion specifications and identify their components.
#
sub parse_conversions
{
    my ($self, $string) = @_;

    my @component = ();
    my $conversion_count = 0;
    my $component_group = qr(
      # $2 or $9: flags (space, #, +, -, 0 “predefined”)
      (\p{IsConversionFlag}+)?

      # $3 or $10: vector flag (vector conversions; includes lookahead
      # assertion to avoid capturing a “v” conversion specifier)
      ((?:\*(?a:\d+\$)?)?v(?=[^v]*\p{IsConversionSpecifier}))?

      # $4 or $11: width
      ((?a)\d+|\*(?a:\d+\$)?)?

      # $5 or $12: precision (numeric conversions)
      # or maximum width (string conversions)
      (\.(?a:\d+|\*(?a:\d+\$)?))?

      # $6 or $13: size (numeric conversions; includes lookahead assertion
      # to avoid capturing an “h” or “l” conversion specifier)
      (hh|ll|[LVhjlqtz](?=\p{IsConversionModifier}*\p{IsConversionSpecifier}))?

      # $7 or $14: modifier ([EO] “predefined” in strftime(); includes
      # lookahead assertion to avoid capturing an ASCII upper case
      # conversion specifier)
      (\p{IsConversionModifier}+(?=\p{IsConversionSpecifier}))?

      # $8 or $15: format specifier ([ABDEFGOUXabcdefginopsux] “predefined”
      # in sprintf())
      (\p{IsConversionSpecifier})
    )x;
    $string =~ s(\%(?:\%|
      # $1: format parameter index
      ((?a)\d+\$)?

      # $2 through $8 (ungrouped by braces) or $9 through $15 (grouped by braces)
      (?:${component_group}|\{${component_group}\})
    )){
      ($8 || $15) ? do
      {
        push @component, ($8) ? [ $1, $2, $3, $4, $5, $6, $7, $8 ]
          : [ $1, $9, $10, $11, $12, $13, $14, $15 ];

        print "\n" if ($conversion_count++ > 0);
        print 'parameter_index: "', ($component[-1]->[0] // ''), qq{"\n};
        print 'flags:           "', ($component[-1]->[1] // ''), qq{"\n};
        print 'vector_flag:     "', ($component[-1]->[2] // ''), qq{"\n};
        print 'width:           "', ($component[-1]->[3] // ''), qq{"\n};
        print 'precision:       "', ($component[-1]->[4] // ''), qq{"\n};
        print 'size:            "', ($component[-1]->[5] // ''), qq{"\n};
        print 'modifier:        "', ($component[-1]->[6] // ''), qq{"\n};
        print 'specifier:       "', $component[-1]->[7], qq{"\n};
      } : do
      {
        push @component, [ '%' ];

        print "\n" if ($conversion_count++ > 0);
        print '"%"', "\n";
      }
   }gex;

   (wantarray) ? @component : $conversion_count;
}

#
# Construct a trimmed format string from $format_components,
# using replacement values from $replacement_components where appropriate.
#
sub trimmed_format {
    my ($self, $format_components, $replacement_components) = @_;

    my $HASH = 'HASH';
    my $format_components_are_HASH =
      ($HASH eq ref $format_components) ? 1 : 0;
    if (!$format_components_are_HASH) {
        croak '$format_components is not a hash reference';
    }

    my $format_components_are_all_present = 1;
    my @expected_key = qw{flags vector_flag width precision size modifier};
    foreach my $key (@expected_key) {
        if (!exists $format_components->{$key}) {
            $format_components_are_all_present = 0;
            last;
        }
    }
    if (!$format_components_are_all_present) {
        croak '$format_components does not have all of its expected keys';
    }

    my $replacement_components_are_HASH =
      ($HASH eq ref $replacement_components) ? 1 : 0;
    if (!$replacement_components_are_HASH
      && defined $replacement_components) {
        croak '$replacement_components is neither a hash reference nor undef';
    }

    my %format_component = %{ $format_components };
    my $parameter_index = 'parameter_index';
    if ($replacement_components_are_HASH) {
        if (exists $format_component{$parameter_index}
          && exists $replacement_components->{$parameter_index}) {
            $format_component{$parameter_index} =
              $replacement_components->{$parameter_index};
        }
        foreach my $key (@expected_key) {
            if (exists $replacement_components->{$key}) {
                $format_component{$key} = $replacement_components->{$key};
            }
        }
    }

    join '', map { $format_component{$_} // '' }
      $parameter_index, @expected_key;
}

sub sprintf {
    my($self, $string, @value) = @_;
    my $value_index = 0;
    my $component_group = qr(
      # $2 or $9: flags (space, #, +, -, 0 “predefined”)
      (\p{IsConversionFlag}+)?

      # $3 or $10: vector flag (vector conversions; includes lookahead
      # assertion to avoid capturing a “v” conversion specifier)
      ((?:\*(?a:\d+\$)?)?v(?=[^v]*\p{IsConversionSpecifier}))?

      # $4 or $11: width
      ((?a)\d+|\*(?a:\d+\$)?)?

      # $5 or $12: precision (numeric conversions)
      # or maximum width (string conversions)
      (\.(?a:\d+|\*(?a:\d+\$)?))?

      # $6 or $13: size (numeric conversions; includes lookahead assertion
      # to avoid capturing an “h” or “l” conversion specifier)
      (hh|ll|[LVhjlqtz]
        (?=\p{IsConversionModifier}*\p{IsConversionSpecifier}))?

      # $7 or $14: modifier ([EO] “predefined” in strftime(); includes
      # lookahead assertion to avoid capturing an ASCII upper case
      # conversion specifier)
      (\p{IsConversionModifier}+(?=\p{IsConversionSpecifier}))?

      # $8 or $15: format specifier ([ABDEFGOUXabcdefginopsux] “predefined”
      # in sprintf())
      (\p{IsConversionSpecifier})
    )x;
    $string =~ s(\%(?:\%|
      # $1: format parameter index
      ((?a)\d+\$)?

      # $2 through $8 (ungrouped by braces)
      # or $9 through $15 (grouped by braces)
      (?:${component_group}|\{${component_group}\})
    )){
      ($8 || $15) ? do
      {
        my ($parameter_index, $flags, $vector_flag, $width,
          $precision, $size, $modifier, $specifier) = ($1, (($8)
            ? ($2, $3, $4, $5, $6, $7, $8)
            : ($9, $10, $11, $12, $13, $14, $15)
        ));
        my ($simplified_vector_flag, $simplified_width,
          $simplified_precision) = (undef, undef, undef);

        #
        # Assemble @parameter so that parameter indices will not be needed
        # in $trimmed_format.
        #
        my @parameter = ();
        if (defined $vector_flag) {
            if ($vector_flag =~ m/^\*(\d+)\$v$/a) {
                push @parameter, $value[$1 - 1];
                $simplified_vector_flag = '*v';
            } elsif ($vector_flag eq '*v') {
                push @parameter, $value[$value_index++];
            } else {
                # Do nothing.
            }
        }
        if (defined $width) {
            if ($width =~ m/^\*(\d+)\$$/a) {
                push @parameter, $value[$1 - 1];
                $simplified_width = '*';
            } elsif ($width eq '*') {
                push @parameter, $value[$value_index++];
            } else {
                # Do nothing.
            }
        }
        if (defined $precision) {
            if ($precision =~ m/^\.\*(\d+)\$$/a) {
                push @parameter, $value[$1 - 1];
                $simplified_precision = '.*';
            } elsif ($precision eq '.*') {
                push @parameter, $value[$value_index++];
            } else {
                # Do nothing.
            }
        }
        push @parameter, $value[(defined $parameter_index) ?
          substr($parameter_index, 0, -1) - 1 : $value_index++];

        #
        # Assemble the simplified (i.e. with all parameter indices removed)
        # trimmed format string. This trimmed format string should be used
        # in tandem with @parameter.
        #
        my %simplified_component = (
          flags => $flags,
          vector_flag => $simplified_vector_flag // $vector_flag,
          width => $simplified_width // $width,
          precision => $simplified_precision // $precision,
          size => $size,
          modifier => $modifier
        );
        my $trimmed_format = $self->trimmed_format(\%simplified_component);

        if (ref(my $handler = $self->{$specifier} || $self->{'*'})) {
            my %format_component = (
              parameter_index => $parameter_index,
              flags => $flags,
              vector_flag => $vector_flag,
              width => $width,
              precision => $precision,
              size => $size,
              modifier => $modifier,
              specifier => $specifier
            );

            #
            # Before version 1.10, the handler’s arguments were
            # $width, $value, $values, and $letter.
            #
            # Starting with version 1.10, the handler’s arguments are
            # $trimmed_format, $parameters, $values, and $format_components.
            #
            # The first argument, $trimmed_format, is unchanged, except for
            # its name. It was renamed to reflect that it can contain more
            # than just the width component of the conversion specification.
            # As before, it contains everything but the initial percent sign
            # and the terminating conversion specifier, and $trimmed_format
            # should still be used in tandem with $parameters rather than
            # with $values.
            #
            # The second argument, $parameters, is now a list reference
            # instead of a scalar. This is so that the parameters that
            # are referred to by asterisks in $trimmed_format are readily
            # accessible. The legacy scalar $value is now accessible as
            # $parameters->[-1] within the handler.
            #
            # The third argument, $values, is unchanged.
            #
            # The fourth argument, $format_components, is now a hash reference
            # instead of a scalar. Since its components can contain parameter
            # indices, a format string made from it should be used in tandem
            # with $values rather than with $parameters. If a conversion uses
            # flags or specifiers that aren’t supported by CORE::sprintf, or
            # if it uses any modifiers, then $values and a format string that
            # is based on $format_components (such as one returned by the
            # trimmed_format method) should be used in the handler rather
            # than $parameters and $trimmed_format. The legacy scalar $letter
            # is now accessible as $format_components->{specifier} within
            # the handler.
            #
            $handler->($trimmed_format, \@parameter, \@value,
              \%format_component);
        } else {
            CORE::sprintf '%' . $trimmed_format . $specifier, @parameter;
        }
      } : '%'
    }gex;

    $string;
}

42;

__END__

=encoding utf8

=head1 NAME

String::Sprintf - Custom overloading of sprintf

=head1 SYNOPSIS

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

    my $out = $f->sprintf('(%10.2N, %10.2N)', 12345678.901, 87654.321);
    print "Formatted result: $out\n";

=head1 DESCRIPTION

How often has it happened that you'd wished for a format that C<(s)printf> just doesn't support? Have you ever wished you could overload C<sprintf> with custom formats? Well, I know I have. And this module provides a way to do just that.

=head1 USAGE

So what is a formatter? Think of it as a "thing" that contains custom settings and behaviour for C<sprintf>(). Any formatting style that you don't set ("overload") falls back to the built-in keyword C<sprintf>.

You can make a minimal formatter that behaves just like C<sprintf> (and that is actually using C<sprintf> internally) with:

  # nothing custom, all default:
  my $default = String::Sprintf->formatter();
  print $default->sprintf("%%%02X\n", 35);

  # which produces the same result as:
  print sprintf("%%%02X\n", 35);   # built-in

Because of the explicit use of these formatters, you can, of course, use several different formatters at the same time, even in the same expression. That is why it's better that it doesn't actually I<really> overload the built-in C<sprintf>. Plus, it was far easier to implement this way.

The syntax used is OO Perl, though I don't really consider this as an object-oriented module. For example, I foresee no reason for subclassing, and all formatters behave differently. That's what they're for.

=head1 METHODS

=head2 class methods:

=head3 formatter( 'A' => \&formatter_A, 'B' => \&formatter_B, ... )

This method returns a formatter object that holds custom formatting definitions, each associated with a conversion specifier, for its method C<sprintf>. Its arguments consist of hash-like pairs of a conversion specifier (letters are case sensitive) and a sub reference that is used for callbacks, and that is expected to return the formatted substring.

A key of C<*> is the default format definition which will be used if
no other definition matches. If you don't specify a C<*> format, the
formatter uses Perl's builtin C<sprintf>.

=head3 trimmed_format ( \%format_component, \%replacement_component )

This method returns a "trimmed" format string (i.e. a format string with neither an initial percent sign nor a terminating conversion specifier) based on the key values of \%format_component. If \%replacement_component is also provided, its key values will override those values of matching keys in \%format_component.

=head3 parse_conversions ( $string )

This method is mainly intended for debugging conversion specifications; it accepts a conversion specification string (which can contain multiple specifications), parses each specification in the string, and prints each specification's components to C<STDOUT>. In list context, it returns a list of array references to the parsed specifications; in scalar context, it returns the count of parsed specifications.

=head2 callback API

A callback is supposed to behave like this:

  sub callback {
      my($trimmed_format, $parameters, $values, $format_components) = @_;
      my $formatted_string;
      # ...
      return $formatted_string;
  }

=head3 Arguments: my($trimmed_format, $parameters, $values, $format_components) = @_;

There are four arguments passed to the callback functions, in order of descending importance. So the more commonly used parameters come first - and yes, that's my mnemonic. They are:

=head4 $trimmed_format

The part that got put between the initial '%' and the terminating conversion specifier. Note that all parameter indices are removed from C<$trimmed_format>, and the order of C<$parameters> is adjusted accordingly, but '*' characters that are used to indicate that width, precision, etc. are obtained from the parameter list still remain in C<$trimmed_format> (and the corresponding parameters remain in C<$parameters>).

=head4 $parameters = \@parameter

An array reference containing the list of arguments that are needed for C<$trimmed_format>. Note that C<$parameters-E<gt>[-1]> is the parameter that is supposed to be formatted.

=head4 $values = \@value

An array reference containing the whole list of all passed arguments that were originally provided to the callback sub, which is needed by a format string that is created from C<$format_components>.

=head4 $format_components = \%format_component

A hash reference containing all of the components of the original format string, including parameter indices, except for the initial '%'. The relevant keys are "parameter_index", "flags", "vector_flag", "width", "precision", "size", "modifier", and "specifier"; for example, C<$format_specifier-E<gt>{$specifier}> is what caused the callback to be invoked, and it can be used to determine which specifier used a common callback sub.

=head3 return value: a string

The return value in scalar context of this sub is inserted into the final, composed result, as a string.

=head2 instance method:

=head3 sprintf($format_string, @argument)

This method inserts the arguments you pass to it into the formatting string, and returns the constructed string, just like the built-in C<sprintf> does.

If you're using conversion specifiers that were I<not> provided when you'd built the formatter, then it will fall back to the native formatter: L<perlfunc/sprintf>. So you need only provide formatters for which you're not happy with the built-ins.

=head1 EXPORTS

Nothing. What did you expect?

=head1 SEE ALSO

L<perlfunc/sprintf>, sprintf(3), L<POSIX/strftime>, strftime(3)

=head1 BUGS

You tell me...?

=head1 SUPPORT

Currently maintained by brian d foy C<< <bdfoy@cpan.org> >> and hosted
on GitHub (https://github.com/briandfoy/string-sprintf).

=head1 AUTHOR

    Bart Lateur
    CPAN ID: BARTL
    Me at home, eating a hotdog
    bart.lateur@pandora.be
    L<http://perlmonks.org/?node=bart>
    L<http://users.pandora.be/bartl/>

=head1 REPOSITORY

L<https://github.com/briandfoy/string-sprintf>

=head1 COPYRIGHTS

E<copy> 2006 Bart Lateur.

E<copy> 2015, 2020, 2022 brian d foy.

=head1 LICENSE

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

My personal terms are like this: you can do whatever you want with this software: bundle it with any software, be it for free, released under the GPL, or commercial; you may redistribute it by itself, fix bugs, add features, and redistribute the modified copy. I would appreciate being informed in case you do the latter.

What you may not do, is sell the software as a standalone product.

=cut

