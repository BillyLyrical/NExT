package Data::NExT::Util;

use strict;
use warnings;
use Exporter 'import';

our $VERSION = '0.1.0';

our @EXPORT_OK = qw(
    find find_adj find_first walk
    to_hash noun_names to_text
    tree
    where
    diff equals
    require_adj require_child validate
    check_refs
);

# --- Traversal ---

sub find {
    my ($nodes, $name) = @_;
    $nodes = [$nodes] unless ref $nodes eq 'ARRAY';
    my @result;
    for my $node (@$nodes) {
        next unless ref $node eq 'HASH';
        if ($node->{type} eq 'noun' && $node->{name} eq $name) {
            push @result, $node;
        }
        if ($node->{type} eq 'noun' && $node->{children}) {
            push @result, @{ find($node->{children}, $name) };
        }
    }
    return \@result;
}

sub find_adj {
    my ($nodes, $name) = @_;
    $nodes = [$nodes] unless ref $nodes eq 'ARRAY';
    my @result;
    for my $node (@$nodes) {
        next unless ref $node eq 'HASH';
        if ($node->{type} eq 'adj' && $node->{name} eq $name) {
            push @result, $node;
        }
        if ($node->{type} eq 'noun' && $node->{children}) {
            push @result, @{ find_adj($node->{children}, $name) };
        }
    }
    return \@result;
}

sub find_first {
    my ($nodes, $name) = @_;
    $nodes = [$nodes] unless ref $nodes eq 'ARRAY';
    for my $node (@$nodes) {
        next unless ref $node eq 'HASH';
        if ($node->{type} eq 'noun' && $node->{name} eq $name) {
            return $node;
        }
        if ($node->{type} eq 'noun' && $node->{children}) {
            my $found = find_first($node->{children}, $name);
            return $found if $found;
        }
    }
    return undef;
}

sub walk {
    my ($nodes, $callback) = @_;
    $nodes = [$nodes] unless ref $nodes eq 'ARRAY';
    for my $node (@$nodes) {
        next unless ref $node eq 'HASH';
        $callback->($node);
        if ($node->{type} eq 'noun' && $node->{children}) {
            walk($node->{children}, $callback);
        }
    }
}

# --- Extraction ---

sub to_hash {
    my ($node) = @_;
    return undef unless ref $node eq 'HASH';
    return undef unless $node->{type} eq 'noun';

    my %hash;
    for my $child (@{$node->{children} // []}) {
        if ($child->{type} eq 'adj') {
            $hash{$child->{name}} = _adj_value($child->{value});
        } elsif ($child->{type} eq 'noun') {
            $hash{$child->{name}} = to_hash($child);
        }
    }
    return \%hash;
}

sub _adj_value {
    my ($val) = @_;
    return undef unless ref $val eq 'HASH';
    if ($val->{type} eq 'list') {
        return [ map { _adj_value($_) } @{$val->{items}} ];
    }
    return $val->{value};
}

sub noun_names {
    my ($nodes) = @_;
    $nodes = [$nodes] unless ref $nodes eq 'ARRAY';
    my @names;
    for my $node (@$nodes) {
        next unless ref $node eq 'HASH';
        if ($node->{type} eq 'noun') {
            push @names, $node->{name};
            if ($node->{children}) {
                push @names, @{ noun_names($node->{children}) };
            }
        }
    }
    return \@names;
}

sub to_text {
    my ($node, $indent) = @_;
    $indent //= 0;
    return '' unless ref $node eq 'HASH';

    my $pad = '    ' x $indent;

    if ($node->{type} eq 'noun') {
        my $name = $node->{name};
        my $text = "${pad}${name}[\n";
        for my $child (@{$node->{children} // []}) {
            $text .= to_text($child, $indent + 1);
        }
        $text .= "${pad}]\n";
        return $text;
    }

    if ($node->{type} eq 'adj') {
        my $val = _value_to_text($node->{value});
        my $name = $node->{name};
        return "${pad}${name}(${val})\n";
    }

    return '';
}

sub _value_to_text {
    my ($val) = @_;
    return '""' unless ref $val eq 'HASH';

    if ($val->{type} eq 'string')  { return '"' . _escape($val->{value}) . '"'; }
    if ($val->{type} eq 'integer') { return "$val->{value}"; }
    if ($val->{type} eq 'float')   { return "$val->{value}"; }
    if ($val->{type} eq 'boolean') { return $val->{value} ? 'true' : 'false'; }
    if ($val->{type} eq 'symbol')  { return $val->{value}; }
    if ($val->{type} eq 'list') {
        my @items = map { _value_to_text($_) } @{$val->{items}};
        return '[' . join(' ', @items) . ']';
    }
    if ($val->{type} eq 'noun') {
        return to_text($val, 0);
    }
    return '""';
}

sub _escape {
    my ($s) = @_;
    $s =~ s/\\/\\\\/g;
    $s =~ s/"/\\"/g;
    $s =~ s/\n/\\n/g;
    $s =~ s/\t/\\t/g;
    return $s;
}

# --- Building ---

sub tree {
    my ($spec) = @_;
    return _build_noun($spec);
}

sub _build_noun {
    my ($spec) = @_;

    return $spec if ref $spec eq 'HASH' && exists $spec->{type};

    my ($name, $children_spec) = @$spec;
    my @children;
    $children_spec //= [];

    for my $pair (@$children_spec) {
        my ($key, $val) = @$pair;

        if ($key =~ /^[A-Z]/ && ref $val eq 'ARRAY') {
            # Nested noun: ["Agent", [ [name=>"a"], [wit=>"b"] ]]
            if (@$val && ref $val->[0] eq 'ARRAY' && ref $val->[0][0] eq 'ARRAY') {
                # Multiple noun specs: ["Agent", [ [name=>"a"], [name=>"b"] ]]
                for my $child_spec (@$val) {
                    push @children, _build_noun([$key, $child_spec]);
                }
            } else {
                # Single noun with pairs
                push @children, _build_noun([$key, $val]);
            }
        } elsif (ref $val eq 'ARRAY') {
            # List value
            push @children, _build_adj($key, {
                type  => 'list',
                items => [ map { _make_value($_) } @$val ],
                line  => 0,
            });
        } else {
            push @children, _build_adj($key, _make_value($val));
        }
    }

    return { type => 'noun', name => $name, children => \@children, line => 0 };
}

sub _build_adj {
    my ($name, $val) = @_;
    return { type => 'adj', name => $name, value => $val, line => 0 };
}

sub _make_value {
    my ($val) = @_;
    return $val if ref $val eq 'HASH' && exists $val->{type};
    return { type => 'string', value => defined $val ? "$val" : '', line => 0 };
}

# --- Query ---

sub where {
    my ($nodes, $predicate) = @_;
    $nodes = [$nodes] unless ref $nodes eq 'ARRAY';
    my @result;
    for my $node (@$nodes) {
        next unless ref $node eq 'HASH';
        push @result, $node if $predicate->($node);
        if ($node->{type} eq 'noun' && $node->{children}) {
            push @result, @{ where($node->{children}, $predicate) };
        }
    }
    return \@result;
}

# --- Comparison ---

sub equals {
    my ($a, $b) = @_;
    return 0 if !ref $a || !ref $b;
    return 0 if $a->{type} ne $b->{type};

    if ($a->{type} eq 'noun') {
        return 0 if $a->{name} ne $b->{name};
        my @a_ch = @{$a->{children} // []};
        my @b_ch = @{$b->{children} // []};
        return 0 if scalar @a_ch != scalar @b_ch;
        for my $i (0 .. $#a_ch) {
            return 0 unless equals($a_ch[$i], $b_ch[$i]);
        }
        return 1;
    }

    if ($a->{type} eq 'adj') {
        return 0 if $a->{name} ne $b->{name};
        return _vals_equal($a->{value}, $b->{value});
    }

    return 0;
}

sub _vals_equal {
    my ($a, $b) = @_;
    return 0 if !ref $a || !ref $b;
    return 0 if $a->{type} ne $b->{type};
    if ($a->{type} eq 'list') {
        return 0 if scalar @{$a->{items}} != scalar @{$b->{items}};
        for my $i (0 .. $#{$a->{items}}) {
            return 0 unless _vals_equal($a->{items}[$i], $b->{items}[$i]);
        }
        return 1;
    }
    return "$a->{value}" eq "$b->{value}";
}

sub diff {
    my ($a, $b, $path) = @_;
    $path //= '';
    my @diffs;

    return (["${path}: type mismatch ($a->{type} vs $b->{type})"])
        if $a->{type} ne $b->{type};

    if ($a->{type} eq 'noun') {
        if ($a->{name} ne $b->{name}) {
            push @diffs, "${path}: noun name mismatch ($a->{name} vs $b->{name})";
            return \@diffs;
        }
        my $p = $path ? "$path/$a->{name}" : $a->{name};
        my @a_ch = @{$a->{children} // []};
        my @b_ch = @{$b->{children} // []};

        if (scalar @a_ch != scalar @b_ch) {
            push @diffs, "$p: child count mismatch (" . scalar(@a_ch) . " vs " . scalar(@b_ch) . ")";
        }
        my $max = scalar @a_ch > scalar @b_ch ? $#a_ch : $#b_ch;
        for my $i (0 .. $max) {
            if ($i > $#a_ch) {
                push @diffs, "$p: extra child in second tree at index $i";
            } elsif ($i > $#b_ch) {
                push @diffs, "$p: extra child in first tree at index $i";
            } else {
                push @diffs, @{ diff($a_ch[$i], $b_ch[$i], $p) };
            }
        }
    }

    if ($a->{type} eq 'adj') {
        if ($a->{name} ne $b->{name}) {
            my $aname = $a->{name};
            my $bname = $b->{name};
            push @diffs, "${path}: adj name mismatch (${aname} vs ${bname})";
        } elsif (!_vals_equal($a->{value}, $b->{value})) {
            my $aname = $a->{name};
            my $p = $path ? "${path}/${aname}" : $aname;
            push @diffs, "${p}: value mismatch";
        }
    }

    return \@diffs;
}

# --- Validation helpers ---

sub require_adj {
    my ($node, $name) = @_;
    die "require_adj: not a noun node\n" unless ref $node eq 'HASH' && $node->{type} eq 'noun';
    for my $child (@{$node->{children} // []}) {
        return 1 if $child->{type} eq 'adj' && $child->{name} eq $name;
    }
    die "required adjective '$name' missing on $node->{name}\n";
}

sub require_child {
    my ($node, $name) = @_;
    die "require_child: not a noun node\n" unless ref $node eq 'HASH' && $node->{type} eq 'noun';
    for my $child (@{$node->{children} // []}) {
        return 1 if $child->{type} eq 'noun' && $child->{name} eq $name;
    }
    die "required child '$name' missing on $node->{name}\n";
}

sub validate {
    my ($tree, %opts) = @_;
    my @errors;
    my $max_depth = $opts{max_depth} // 20;

    _validate_node($tree, \@errors, 0, $max_depth);
    return @errors;
}

sub _validate_node {
    my ($node, $errors, $depth, $max_depth) = @_;
    return unless ref $node eq 'HASH';

    if ($depth > $max_depth) {
        push @$errors, "max depth exceeded at $node->{name}";
        return;
    }

    if ($node->{type} eq 'noun') {
        if ($node->{children}) {
            for my $child (@{$node->{children}}) {
                _validate_node($child, $errors, $depth + 1, $max_depth);
            }
        }
    }

    if ($node->{type} eq 'adj') {
        my $val = $node->{value};
        if (!ref $val || !exists $val->{type}) {
            push @$errors, "$node->{name}: invalid value (not a value node)";
        }
    }
}

# --- Symbol reference checking ---

sub check_refs {
    my ($tree) = @_;
    $tree = [$tree] unless ref $tree eq 'ARRAY';

    my %counts;
    walk($tree, sub {
        my $node = shift;
        if ($node->{type} eq 'adj' && $node->{value}
            && ref $node->{value} eq 'HASH'
            && $node->{value}{type} eq 'symbol')
        {
            my $name = $node->{value}{value};
            $name =~ s/^@//;
            $counts{$name} //= { count => 0, line => $node->{line} };
            $counts{$name}{count}++;
        }
    });

    my @warnings;
    my @errors;
    for my $name (sort keys %counts) {
        my $info = $counts{$name};
        if ($info->{count} == 1) {
            push @warnings, "symbol \@$name appears only once (line $info->{line}): possibly undefined";
        }
    }

    return { warnings => \@warnings, errors => \@errors };
}

1;

__END__

=head1 NAME

Data::NExT::Util - Utility functions for working with NExT parse trees

=head1 SYNOPSIS

    use Data::NExT;
    use Data::NExT::Util qw(find to_hash to_text tree);

    my $tree = Data::NExT::parse($input);

    # Find all Agent nodes
    my @agents = @{ find($tree, 'Agent') };

    # Extract as hash
    my $config = to_hash($tree->[0]);

    # Build programmatically
    my $node = tree([
        Agent => [
            name => "critic",
            wit  => "logic",
        ],
    ]);

    # Serialize back to NExT
    print to_text($node);

=head1 DESCRIPTION

Data::NExT::Util provides optional utility functions for traversing,
querying, building, and comparing NExT parse trees. The core parser
(Data::NExT) works fine without this module — Util is a convenience
layer for common operations.

=head1 FUNCTIONS

=head2 Traversal

=head3 find($nodes, $name)

Finds all Noun nodes with the given name. Returns an arrayref.

=head3 find_adj($nodes, $name)

Finds all Adjective nodes with the given name. Returns an arrayref.

=head3 find_first($nodes, $name)

Finds the first Noun node with the given name. Returns the node or undef.

=head3 walk($nodes, $callback)

Calls $callback on every node in depth-first order.

=head2 Extraction

=head3 to_hash($node)

Converts a Noun node to a flat hashref. Adjective values become
hash values. Nested Nouns become nested hashrefs.

=head3 noun_names($nodes)

Returns an arrayref of all Noun names in the tree.

=head3 to_text($node)

Serializes a node back to NExT text format.

=head2 Building

=head3 tree($spec)

Builds a NExT tree from a concise spec:

    my $node = tree([
        Pipeline => [
            name => "my-pipeline",
            Agent => [
                name => "critic",
                wit  => "logic",
            ],
        ],
    ]);

Lists become list values. Pre-built nodes (hashrefs with type) are
passed through unchanged.

=head2 Query

=head3 where($nodes, $predicate)

Returns all nodes matching the predicate callback.

=head2 Comparison

=head3 equals($a, $b)

Returns true if two nodes are structurally identical.

=head3 diff($a, $b)

Returns an arrayref of difference descriptions between two nodes.

=head2 Validation

=head3 require_adj($node, $name)

Dies if the Noun node doesn't have the named Adjective.

=head3 require_child($node, $name)

Dies if the Noun node doesn't have a child Noun with the given name.

=head3 validate($tree, %opts)

Validates a tree structure. Returns a list of error strings.
Options: max_depth (default 20).

=head1 AUTHOR

Billy Lyrical

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
