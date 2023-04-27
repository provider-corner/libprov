# CC0 license applied, see LICENCE.md
# CC0 license also applied on the generated code

# This script takes 3 arguments, in this order
#
# - File name for a C source file to be generated
# - File name for a C header file to be generated
# - File name with input data
#
# The input data file must be possible to evaluate as a perl script,
# and must finish with an expression that's evaluated as an array ref,
# where:
#
# - the first item must be a name (string).  This is used as a C variable
#   |name| with the type 'struct provparams_parsetree []'.
# - remaining argument must be tuples with two items, a |param_name| and a
#   |param_string|.
#
# The generated C header file will contain a set of macro definition, where
# |param_name| and |param_string| are used, as well as a result number {n},
# and finish with a delaration of the variable |name|:
#
#     #define S_|param_name| "|param_string|"
#     #define V_|param_name| {n}
#     ...
#     int |name|(const char *key);
#
# The generated C source file will contain the definition of |name|:
#
#     int |name|(const char *key)
#     {
#         ...
#     };

use strict;
use warnings;
use lib '.';

sub gen_cases
{
    my $indent = shift;
    my $index = shift;
    my @parse_tree = @_;
    my $source = "";

    $source .= " " x $indent . "switch (*p++) {\n";
    do {
        $source .= " " x $indent . "case '$parse_tree[$index]->{lc}':\n";
        if ($parse_tree[$index]->{lc} ne $parse_tree[$index]->{uc}) {
            $source .= " " x $indent . "case '$parse_tree[$index]->{uc}':\n";
        }
        if ($parse_tree[$index]->{result}) {
            $source .= " " x ($indent + 4) . "return $parse_tree[$index]->{result};\n";
        } elsif  ($parse_tree[$index]->{next}) {
            $source .= gen_cases($indent + 4, $parse_tree[$index]->{next},
                                 @parse_tree);
            $source .= " " x ($indent + 4) . "break;\n";
        }
        $index = $parse_tree[$index]->{alt};
    } while ($index);
    $source .= " " x $indent . "}\n";
    return $source;
}

# Inputs:
# - name of LL parse tree variable
# - HASH of macro name => string (param key)
# Returns:
# - a string that's the generated C code
sub gen {
    my $fnname = shift;
    my %keys = @_;

    # The parse tree consists of small HASH tables like this:
    #
    # 'lc'     => character     lowercase character to match
    # 'uc'     => character     uppercase character to match
    # 'next'   => index         the parse item to go to when chars match
    # 'alt'    => index         the parse item to go to when chars don't match
    # 'result' => number        the resulting number (only when char is \0)
    my @parse_tree = ();

    my $next_result = 0;
    my %new_keys = ();

    foreach my $k (sort keys %keys) {
        my $index = 0;
      CHAR:
        foreach my $c (split("", $keys{$k})) {
            while ($index <= $#parse_tree) {
                my $next_branch
                    = ( ($parse_tree[$index]->{lc} eq $c
                         || $parse_tree[$index]->{uc} eq $c )
                        ? 'next' : 'alt' );
                my $new_index = $parse_tree[$index]->{$next_branch} // 0;
                if ($new_index > 0) {
                    $index = $new_index;
                } else {
                    $index
                        = $parse_tree[$index]->{$next_branch}
                        = $#parse_tree + 1;
                }
                next CHAR if $next_branch eq 'next';
            }
            # We've reached the end of what exists so far, so now we can only
            # add new stuff.
            die "Implementation error: \$index (= $index) != \$#parse_tree (= $#parse_tree) + 1\n"
                if $index != $#parse_tree + 1;
            push @parse_tree, {
                lc     => lc($c) || '\0',
                uc     => uc($c) || '\0',
                next   => ++$index,
            };
        }
        # Lastly, we make sure there's an entry for the ending NUL char
        if ($index > $#parse_tree) {
            $new_keys{$k} = ++$next_result;
            push @parse_tree, {
                lc     => '\0',
                uc     => '\0',
                result => "V_$k"
            };
        }
    }

    my $header =
        join("", (
            map {
                ( "#define S_$_ \"$keys{$_}\"\n",
                  "#define V_$_ $new_keys{$_}\n" )
            } sort keys %new_keys
        ))
        . <<"_____";

int $fnname(const char *key);
_____
    my $indent = 0;
    my $source =
        <<"_____"
int $fnname(const char *key)
{
    const char *p = key;
_____
        . gen_cases(4, 0, @parse_tree)
        . <<"_____"
    return 0;
}
_____
        ;

    my $res = { header => $header,
                source => $source };
    return $res;
}

# MAIN

my $gen_C_source = shift @ARGV;
my $gen_C_header = shift @ARGV;
my $input = shift @ARGV;

my $params;
unless ($params = do $input) {
    warn "couldn't parse $input: $@" if $@;
    warn "couldn't do $input: $!"    unless defined $params;
    warn "couldn't run $input"       unless $params;
}

die "$input didn't return an ARRAY ref"
    unless ref $params eq "ARRAY";
die "$input returned an empty ARRAY"
    unless @$params;

my $result = gen(@$params);

my $fh;
open $fh, "> $gen_C_header" or die "Couldn't open $gen_C_header: $!\n";
print $fh $result->{header};
close $fh;
open $fh, "> $gen_C_source" or die "Couldn't open $gen_C_source: $!\n";
print $fh <<"_____";
#include "$gen_C_header"
_____
print $fh $result->{source};
close $fh;
