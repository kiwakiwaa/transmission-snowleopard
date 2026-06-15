#!/usr/bin/perl

use strict;
use warnings;
use Encode qw(decode);

sub read_text
{
    my ($path) = @_;

    open(my $fh, '<:raw', $path) or die "Unable to read $path: $!\n";
    local $/;
    my $text = <$fh>;
    close($fh);

    if (substr($text, 0, 2) eq "\xFF\xFE")
    {
        return decode('UTF-16LE', substr($text, 2));
    }

    if (substr($text, 0, 2) eq "\xFE\xFF")
    {
        return decode('UTF-16BE', substr($text, 2));
    }

    return decode('UTF-8', $text);
}

sub parse_strings
{
    my ($path) = @_;
    my $text = read_text($path);
    my @keys;
    my %values;

    while ($text =~ /^"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)";/mg)
    {
        my ($key, $value) = ($1, $2);
        push @keys, $key if !exists $values{$key};
        $values{$key} = $value;
    }

    return (\@keys, \%values);
}

if (@ARGV != 3)
{
    die "Usage: $0 SOURCE_STRINGS ALLOWED_STRINGS OUTPUT_STRINGS\n";
}

my ($source_path, $allowed_path, $output_path) = @ARGV;
my ($allowed_keys, $fallback_values) = parse_strings($allowed_path);
my (undef, $translated_values) = parse_strings($source_path);

open(my $out, '>:encoding(UTF-8)', $output_path) or die "Unable to write $output_path: $!\n";

for my $key (@$allowed_keys)
{
    my $value = exists $translated_values->{$key} ? $translated_values->{$key} : $fallback_values->{$key};
    print $out "\"$key\" = \"$value\";\n";
}

close($out);
