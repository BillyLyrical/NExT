package Data::NExT::Util;

use strict;
use warnings;
use Exporter 'import';

our $VERSION = '0.2.0';

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
        if (exists $node->{$name}) {
            push @result, $node;
        }
        for my $val (values %$node) {
            if (ref $val eq 'HASH') {
                push @result, @{ find([$val], $name) };
            } elsif (ref $val eq 'ARRAY') {
                for my $item (@$val) {
                    if (ref $item eq 'HASH') {
                        push @result, @{ find([$item], $name) };
                    }
                }
            }
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
        if (exists $node->{$name}) {
            my $val = $node->{$name};
            unless (ref $val eq 'HASH' && exists $val->{type}) {
                push @result, { name => $name, value => $val };
            }
        }
        for my $val (values %$node) {
            if (ref $val eq 'HASH') {
                push @result, @{ find_adj([$val], $name) };
            }
        }
    }
    return \@result;
}

sub find_first {
    my ($nodes, $name) = @_;
    $nodes = [$nodes] unless ref $nodes eq 'ARRAY';
    for my $node (@$nodes) {
        next unless ref $node eq 'HASH';
        if (exists $node->{$name}) {
            return $node;
        }
        for my $val (values %$node) {
            if (ref $val eq 'HASH') {
                my $found = find_first([$val], $name);
                return $found if $found;
            }
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
        for my $val (values %$node) {
            if (ref $val eq 'HASH') {
                walk([$val], $callback);
            }
        }
    }
}

# --- Extraction ---

sub to_hash {
    my ($node) = @_;
    return $node if ref $node eq 'HASH';
    return undef;
}

sub noun_names {
    my ($nodes) = @_;
    $nodes = [$nodes] unless ref $nodes eq 'ARRAY';
    my @names;
    for my $node (@$nodes) {
        next unless ref $node eq 'HASH';
        for my $key (keys %$node) {
            if (ref $node->{$key} eq 'HASH') {
                push @names, $key;
                push @names, @{ noun_names([$node->{$key}]) };
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
    my $text = '';

    for my $key (keys %$node) {
        my $val = $node->{$key};
        if (ref $val eq 'HASH') {
            $text .= "${pad}${key}[\n";
            $text .= to_text($val, $indent + 1);
            $text .= "${pad}]\n";
        } else {
            my $val_text = _value_to_text($val, $indent);
            $text .= "${pad}${key}(${val_text})\n";
        }
    }

    return $text;
}

sub _value_to_text {
    my ($val, $indent) = @_;
    $indent //= 0;
    my $pad = '    ' x $indent;

    if (!defined $val) {
        return '""';
    }

    if (ref $val eq 'ARRAY') {
        my @items = map { _value_to_text($_, $indent) } @$val;
        return '[' . join(' ', @items) . ']';
    }

    if (ref $val eq 'HASH') {
        return to_text($val, $indent);
    }

    if ($val eq '1') {
        return 'true';
    }

    if ($val eq '0') {
        return 'false';
    }

    if ($val =~ /^-?\d+$/) {
        return "$val";
    }

    if ($val =~ /^-?\d+\.\d+$/) {
        return "$val";
    }

    if ($val =~ /^@/) {
        return $val;
    }

    if ($val =~ /\n/) {
        my $content = $val;
        $content .= "\n" unless $content =~ /\n$/;
        return '"""' . "\n" . $content . $pad . '"""';
    }

    return '"' . _escape($val) . '"';
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
    return _build_node($spec);
}

sub _build_node {
    my ($spec) = @_;

    return $spec if ref $spec eq 'HASH';

    my ($key, $val) = @$spec;

    if (ref $val eq 'ARRAY') {
        my %content;
        my @items = @$val;
        while (@items) {
            my $k = shift @items;
            my $v = shift @items;
            if ($k =~ /^[A-Z]/) {
                my $built = _build_node([$k, $v]);
                my ($built_key, $built_val) = %$built;
                if (exists $content{$k}) {
                    if (ref $content{$k} eq 'ARRAY') {
                        push @{$content{$k}}, $built_val;
                    } else {
                        $content{$k} = [$content{$k}, $built_val];
                    }
                } else {
                    $content{$k} = $built_val;
                }
            } else {
                if (exists $content{$k}) {
                    if (ref $content{$k} eq 'ARRAY') {
                        push @{$content{$k}}, _build_value($v);
                    } else {
                        $content{$k} = [$content{$k}, _build_value($v)];
                    }
                } else {
                    $content{$k} = _build_value($v);
                }
            }
        }
        return { $key => \%content };
    }

    return { $key => _build_value($val) };
}

sub _build_value {
    my ($val) = @_;

    if (ref $val eq 'ARRAY') {
        my @items = @$val;
        if (@items && !ref $items[0] && $items[0] =~ /^[A-Z]/) {
            my %content;
            while (@items) {
                my $k = shift @items;
                my $v = shift @items;
                if (exists $content{$k}) {
                    if (ref $content{$k} eq 'ARRAY') {
                        push @{$content{$k}}, _build_value($v);
                    } else {
                        $content{$k} = [$content{$k}, _build_value($v)];
                    }
                } else {
                    $content{$k} = _build_value($v);
                }
            }
            return \%content;
        }
        return $val;
    }

    if (ref $val eq 'HASH') {
        return $val;
    }

    return $val;
}

# --- Query ---

sub where {
    my ($nodes, $predicate) = @_;
    $nodes = [$nodes] unless ref $nodes eq 'ARRAY';
    my @result;
    for my $node (@$nodes) {
        next unless ref $node eq 'HASH';
        push @result, $node if $predicate->($node);
        for my $val (values %$node) {
            if (ref $val eq 'HASH') {
                push @result, @{ where([$val], $predicate) };
            }
        }
    }
    return \@result;
}

# --- Comparison ---

sub equals {
    my ($a, $b) = @_;
    return 0 if !ref $a || !ref $b;
    return 0 if ref $a ne 'HASH' || ref $b ne 'HASH';

    my @a_keys = sort keys %$a;
    my @b_keys = sort keys %$b;
    return 0 if scalar @a_keys != scalar @b_keys;

    for my $i (0 .. $#a_keys) {
        return 0 if $a_keys[$i] ne $b_keys[$i];
        my $av = $a->{$a_keys[$i]};
        my $bv = $b->{$b_keys[$i]};
        return 0 unless _vals_equal($av, $bv);
    }

    return 1;
}

sub _vals_equal {
    my ($a, $b) = @_;
    return 1 if !defined $a && !defined $b;
    return 0 if !defined $a || !defined $b;
    return 0 if ref $a ne ref $b;

    if (ref $a eq 'ARRAY') {
        return 0 if scalar @$a != scalar @$b;
        for my $i (0 .. $#$a) {
            return 0 unless _vals_equal($a->[$i], $b->[$i]);
        }
        return 1;
    }

    if (ref $a eq 'HASH') {
        return equals($a, $b);
    }

    return "$a" eq "$b";
}

sub diff {
    my ($a, $b, $path) = @_;
    $path //= '';
    my @diffs;

    return (["${path}: not both hashrefs"])
        if !ref $a || !ref $b || ref $a ne 'HASH' || ref $b ne 'HASH';

    my @a_keys = sort keys %$a;
    my @b_keys = sort keys %$b;

    my %all_keys;
    for my $k (@a_keys, @b_keys) {
        $all_keys{$k} = 1;
    }

    for my $k (sort keys %all_keys) {
        my $p = $path ? "$path/$k" : $k;
        if (!exists $a->{$k}) {
            push @diffs, "$p: missing in first tree";
        } elsif (!exists $b->{$k}) {
            push @diffs, "$p: missing in second tree";
        } else {
            push @diffs, @{ _diff_val($a->{$k}, $b->{$k}, $p) };
        }
    }

    return \@diffs;
}

sub _diff_val {
    my ($a, $b, $path) = @_;
    my @diffs;

    return (["${path}: type mismatch"]) if ref $a ne ref $b;

    if (ref $a eq 'ARRAY') {
        return (["${path}: array length mismatch"]) if scalar @$a != scalar @$b;
        for my $i (0 .. $#$a) {
            push @diffs, @{ _diff_val($a->[$i], $b->[$i], "$path\[$i\]") };
        }
        return \@diffs;
    }

    if (ref $a eq 'HASH') {
        return diff($a, $b, $path);
    }

    if ("$a" ne "$b") {
        push @diffs, "$path: value mismatch ($a vs $b)";
    }

    return \@diffs;
}

# --- Validation helpers ---

sub require_adj {
    my ($node, $name) = @_;
    die "require_adj: not a hashref\n" unless ref $node eq 'HASH';
    die "required adjective '$name' missing\n" unless exists $node->{$name};
    return 1;
}

sub require_child {
    my ($node, $name) = @_;
    die "require_child: not a hashref\n" unless ref $node eq 'HASH';
    die "required child '$name' missing\n" unless exists $node->{$name} && ref $node->{$name} eq 'HASH';
    return 1;
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
        push @$errors, "max depth exceeded";
        return;
    }

    for my $key (keys %$node) {
        my $val = $node->{$key};
        if (ref $val eq 'HASH') {
            _validate_node($val, $errors, $depth + 1, $max_depth);
        } elsif (ref $val eq 'ARRAY') {
            for my $item (@$val) {
                if (ref $item eq 'HASH') {
                    _validate_node($item, $errors, $depth + 1, $max_depth);
                }
            }
        }
    }
}

# --- Symbol reference checking ---

sub check_refs {
    my ($tree) = @_;
    $tree = [$tree] unless ref $tree eq 'ARRAY';

    my %counts;
    _collect_symbols($tree, \%counts, 0);

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

sub _collect_symbols {
    my ($nodes, $counts, $line) = @_;
    $nodes = [$nodes] unless ref $nodes eq 'ARRAY';

    for my $node (@$nodes) {
        next unless ref $node eq 'HASH';

        for my $key (keys %$node) {
            my $val = $node->{$key};

            if (!ref $val && defined $val && $val =~ /^@(.+)/) {
                my $name = $1;
                $counts->{$name} //= { count => 0, line => $line };
                $counts->{$name}{count}++;
            } elsif (ref $val eq 'HASH') {
                _collect_symbols([$val], $counts, $line);
            } elsif (ref $val eq 'ARRAY') {
                _collect_symbols($val, $counts, $line);
            }
        }
    }
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
(Data::NExT) works fine without this module - Util is a convenience
layer for common operations.

=head1 FUNCTIONS

=head2 Traversal

=head3 find($nodes, $name)

Finds all nodes with the given key. Returns an arrayref.

=head3 find_adj($nodes, $name)

Finds all adjective values (non-hashref values) with the given name.
Returns an arrayref of {name, value} pairs.

=head3 find_first($nodes, $name)

Finds the first node with the given key. Returns the node or undef.

=head3 walk($nodes, $callback)

Calls $callback on every node in depth-first order.

=head2 Extraction

=head3 to_hash($node)

Returns the node itself (since parse output is already a hashref).

=head3 noun_names($nodes)

Returns an arrayref of all noun names (keys with hashref values) in the tree.

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

Lists become list values. Hashrefs are passed through unchanged.

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

Dies if the node doesn't have the named adjective.

=head3 require_child($node, $name)

Dies if the node doesn't have a child with the given name.

=head3 validate($tree, %opts)

Validates a tree structure. Returns a list of error strings.
Options: max_depth (default 20).

=head1 AUTHOR

Billy Lyrical

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
