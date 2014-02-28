=head1 NAME

Config::Neat::Util - Common utility functions for other Config::Neat modules

=head1 COPYRIGHT

Copyright (C) 2012-2014 Igor Afanasyev <igor.afanasyev@gmail.com>

=head1 SEE ALSO

L<https://github.com/iafan/Config-Neat>

=cut

package Config::Neat::Util;

our $VERSION = '0.3';

use strict;

use Tie::IxHash;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
    new_ixhash
    is_number
    is_code
    is_hash
    is_ixhash
    is_array
    is_neat_array
    is_scalar
    is_simple_array
    hash_has_only_sequential_keys
    hash_has_sequential_keys
    get_next_auto_key
    offset_keys
    get_keys_in_order
    reorder_ixhash_numerically
    reorder_ixhash
    rename_ixhash_key
    read_file
);

sub new_ixhash {
    my $new = {};
    tie(%$new, 'Tie::IxHash');
    return $new;
}

sub is_number {
    my $n = shift;
    return ($n + 0) eq $n;
}

sub is_code {
    my $node = shift;
    return ref($node) eq 'CODE';
}

sub is_hash {
    my $node = shift;
    return ref($node) eq 'HASH';
}

sub is_ixhash {
    my $node = shift;
    return undef unless is_hash($node);
    return ref(tied(%$node)) eq 'Tie::IxHash';
}

sub is_array {
    my $node = shift;
    return ref($node) eq 'ARRAY';
}

sub is_neat_array {
    my $node = shift;
    return ref($node) eq 'Config::Neat::Array';
}

sub is_scalar {
    my $node = shift;
    return (ref(\$node) eq 'SCALAR') or (ref($node) eq 'SCALAR');
}

sub is_simple_array {
    my $node = shift;

    return 1 if is_scalar($node);
    return undef if is_hash($node);

    my $contains_hash = undef;
    my $contains_scalar = undef;

    foreach my $value (@$node) {
        if (is_hash($value)) {
            $contains_hash |= 1;
        } else {
            $contains_scalar |= is_scalar($value);
        }
        die "Mixing hashes with simple arrays/scalars within one node is not supported" if $contains_hash && $contains_scalar;
    }
    return $contains_scalar;
}

sub hash_has_only_sequential_keys {
    my $node = shift;
    return hash_has_sequential_keys($node, 1);
}

sub hash_has_sequential_keys {
    my ($node, $strict) = @_;
    die "Not a hash" unless is_hash($node);

    my $i = 0;
    map {
        if (is_number($_)) {
            return undef if $_ != $i;
            $i++;
        } else {
            return undef if $strict;
        }
    } keys %$node;
    return 1;
}

# supposed to be used against hash that matches the
# `hash_has_sequential_keys() == true` criterion
sub get_next_auto_key {
    my $node = shift;
    die "Not a hash" unless is_hash($node);

    # get max(key)
    my $i = -1; # so that next key will start with 0
    map {
        $i = $_ if $_ > $i && is_number($_);
    } keys %$node;

    # return max + 1
    return $i + 1;
}

sub offset_keys {
    my ($node, $offset) = @_;
    die "Not a Tie::IxHash" unless is_ixhash($node);
    return $node if $offset == 0;

    my $result = new_ixhash;

    # remap keys
    map {
        if (is_number($_)) {
            $result->{$_ + $offset} = $node->{$_};
        } else {
            $result->{$_} = $node->{$_};
        }
    } keys %$node;

    return $result;
}

# accepts an array of hasrefs
sub get_keys_in_order {
    my $result = new_ixhash;

    map {
        map {
            $result->{$_} = 1;
        } keys %$_;
    } @_;

    return keys %$result;
}

sub reorder_ixhash_numerically {
    my ($node) = @_;
    die "Not a Tie::IxHash" unless is_ixhash($node);

    # sort keys numerically
    my @a = sort {$a <=> $b} keys %$node;

    return reorder_ixhash($node, \@a);
}

sub reorder_ixhash {
    my ($node, $keysref) = @_;
    die "Not a Tie::IxHash" unless is_ixhash($node);

    my $result = new_ixhash;
    map { $result->{$_} = $node->{$_} if exists $node->{$_} } @$keysref;

    return $result;
}

sub rename_ixhash_key {
    my ($node, $from, $to) = @_;
    die "Not a Tie::IxHash" unless is_ixhash($node);
    die "Can\'t rename key '$from' to '$to', because the target key already exists" if exists $node->{$to};

    my $result = new_ixhash;
    map {
        my $key = $_ eq $from ? $to : $_;
        $result->{$key} = $node->{$_};
    } keys %$node;

    return $result;
}

sub read_file {
    my ($filename, $binmode) = @_;

    open(CFG, $filename) or die "Can't open [$filename]: $!";
    binmode(CFG, $binmode || ':utf8');
    my $text = join('', <CFG>);
    close(CFG);

    return $text;
} # end sub


1;