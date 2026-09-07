package Data::NExT;

use strict;
use warnings;

our $VERSION = '0.1.1';
our $ERROR;

my $RE_NOUN  = qr/\G[A-Z][a-zA-Z0-9_]*/;
my $RE_ADJ   = qr/\G[a-z][a-zA-Z0-_-]*/;
my $RE_NUM   = qr/\G[0-9]+(?:\.[0-9]+)?/;
my $RE_SYM   = qr/\G\@([a-zA-Z_][a-zA-Z0-9_]*)/;

sub new {
    my ($class, $input) = @_;
    my $self = {
        input => $input,
        pos   => 0,
        line  => 1,
    };
    bless $self, $class;
    return $self;
}

sub _ch { substr($_[0]{input}, $_[0]{pos}, 1) }

sub _peek {
    my ($self) = @_;
    $self->_skip_ws;
    return 'EOF' if $self->{pos} >= length($self->{input});
    my $ch = $self->_ch;
    return '#' if $ch eq '#';
    return ']' if $ch eq ']';
    return '[' if $ch eq '[';
    return '(' if $ch eq '(';
    return ')' if $ch eq ')';
    return 'NOUN' if $ch ge 'A' && $ch le 'Z';
    if ($ch eq 't' && substr($self->{input}, $self->{pos}, 4) eq 'true') {
        my $after = substr($self->{input}, $self->{pos} + 4, 1);
        return 'BOOL_T' if !defined $after || $after !~ /[a-zA-Z0-9_\-]/;
    }
    if ($ch eq 'f' && substr($self->{input}, $self->{pos}, 5) eq 'false') {
        my $after = substr($self->{input}, $self->{pos} + 5, 1);
        return 'BOOL_F' if !defined $after || $after !~ /[a-zA-Z0-9_\-]/;
    }
    return 'ADJ' if $ch ge 'a' && $ch le 'z' || $ch eq '_' || $ch eq '-';
    return 'SYMBOL' if $ch eq '@';
    return 'STRING' if $ch eq '"';
    return 'NUM' if $ch ge '0' && $ch le '9';
    $ERROR = "line $self->{line}: unexpected character '$ch'";
    return 'ERR';
}

sub _skip_ws {
    my ($self) = @_;
    while ($self->{pos} < length($self->{input})) {
        my $ch = $self->_ch;
        if ($ch eq ' ' || $ch eq "\t" || $ch eq "\r") {
            $self->{pos}++;
        } elsif ($ch eq "\n") {
            $self->{line}++;
            $self->{pos}++;
        } elsif ($ch eq '#') {
            while ($self->{pos} < length($self->{input}) && $self->_ch ne "\n") {
                $self->{pos}++;
            }
        } else {
            last;
        }
    }
}

sub _read_noun {
    my ($self) = @_;
    my $line = $self->{line};
    pos($self->{input}) = $self->{pos};
    $self->{input} =~ $RE_NOUN;
    my $len = $+[0] - $self->{pos};
    if ($len > 0) {
        my $name = substr($self->{input}, $self->{pos}, $len);
        $self->{pos} += $len;
        return { type => 'noun', name => $name, line => $line };
    }
    return { type => 'noun', name => '', line => $line };
}

sub _read_adj {
    my ($self) = @_;
    my $line = $self->{line};
    pos($self->{input}) = $self->{pos};
    $self->{input} =~ $RE_ADJ;
    my $len = $+[0] - $self->{pos};
    my $name = substr($self->{input}, $self->{pos}, $len);
    $self->{pos} += $len;
    return { name => $name, line => $line };
}

sub _read_string {
    my ($self) = @_;
    my $line = $self->{line};
    $self->{pos}++; # skip opening "
    my $str = '';
    while ($self->{pos} < length($self->{input})) {
        my $c = $self->_ch;
        if ($c eq '\\') {
            $self->{pos}++;
            $c = $self->_ch;
            if    ($c eq 'n')  { $str .= "\n"; }
            elsif ($c eq 't')  { $str .= "\t"; }
            elsif ($c eq '\\') { $str .= "\\"; }
            elsif ($c eq '"')  { $str .= '"'; }
            else { $str .= $c; }
        } elsif ($c eq '"') {
            $self->{pos}++;
            return $str;
        } else {
            $self->{line}++ if $c eq "\n";
            $str .= $c;
        }
        $self->{pos}++;
    }
    $ERROR = "line $line: unterminated string";
    return undef;
}

sub _read_num {
    my ($self) = @_;
    my $line = $self->{line};
    pos($self->{input}) = $self->{pos};
    $self->{input} =~ $RE_NUM;
    my $len = $+[0] - $self->{pos};
    my $raw = substr($self->{input}, $self->{pos}, $len);
    $self->{pos} += $len;
    if ($raw =~ /\./) {
        return { type => 'float', value => $raw + 0, line => $line };
    }
    return { type => 'integer', value => $raw + 0, line => $line };
}

sub _read_symbol {
    my ($self) = @_;
    my $line = $self->{line};
    pos($self->{input}) = $self->{pos};
    $self->{input} =~ $RE_SYM;
    my $end = $+[0];
    my $name = $1;
    $self->{pos} = $end;
    return { type => 'symbol', value => '@' . $name, line => $line };
}

sub _expect {
    my ($self, $tok) = @_;
    my $got = $self->_peek;
    if ($got ne $tok) {
        $ERROR = "line $self->{line}: expected $tok, got $got";
        return 0;
    }
    $self->{pos}++ if $tok eq '[' || $tok eq ']' || $tok eq '(' || $tok eq ')';
    return 1;
}

sub _parse_value {
    my ($self) = @_;
    $self->_skip_ws;
    my $tok = $self->_peek;
    if ($tok eq 'STRING') {
        my $v = $self->_read_string;
        return defined $v ? { type => 'string', value => $v, line => $self->{line} } : undef;
    }
    if ($tok eq 'NUM') {
        return $self->_read_num;
    }
    if ($tok eq 'BOOL_T') {
        $self->{pos} += 4;
        return { type => 'boolean', value => 1, line => $self->{line} };
    }
    if ($tok eq 'BOOL_F') {
        $self->{pos} += 5;
        return { type => 'boolean', value => 0, line => $self->{line} };
    }
    if ($tok eq 'SYMBOL') {
        return $self->_read_symbol;
    }
    if ($tok eq 'NOUN') {
        return $self->_parse_object;
    }
    $ERROR = "line $self->{line}: expected value, got $tok";
    return undef;
}

sub _parse_object {
    my ($self) = @_;
    my $noun = $self->_read_noun;
    return undef unless $self->_expect('[');
    my @children;
    while (1) {
        my $tok = $self->_peek;
        last if $tok eq ']' || $tok eq 'EOF';
        if ($tok eq 'NOUN') {
            my $child = $self->_parse_object;
            return undef unless defined $child;
            push @children, $child;
        } elsif ($tok eq 'ADJ') {
            my $adj = $self->_read_adj;
            unless ($self->_expect('(')) { return undef; }
            my $val = $self->_parse_value;
            return undef unless defined $val;
            unless ($self->_expect(')')) { return undef; }
            push @children, { type => 'adj', name => $adj->{name}, value => $val, line => $adj->{line} };
        } elsif ($tok eq '#') {
            $self->_skip_ws;
        } else {
            $ERROR = "line $self->{line}: unexpected token '$tok'";
            return undef;
        }
    }
    return undef unless $self->_expect(']');
    return { type => 'noun', name => $noun->{name}, children => \@children, line => $noun->{line} };
}

sub parse {
    my ($input) = @_;
    $ERROR = undef;
    my $parser = Data::NExT->new($input);
    my @blocks;
    while ($parser->_peek ne 'EOF') {
        my $tok = $parser->_peek;
        if ($tok eq 'NOUN') {
            my $obj = $parser->_parse_object;
            return undef if defined $ERROR;
            push @blocks, $obj;
        } elsif ($tok eq '#') {
            $parser->_skip_ws;
        } else {
            $ERROR = "line $parser->{line}: unexpected token '$tok'";
            return undef;
        }
    }
    return \@blocks;
}

1;

__END__

=head1 NAME

Data::NExT - Lightweight parser for the NExT (Noun Expression Tree) format

=head1 SYNOPSIS

    use Data::NExT;

    my $input = q{
    Window[
        title("Settings")
        width(500)
        Box[
            orientation("vertical")
            Label[ text("Hello") ]
        ]
    ]
    };

    my $tree = Data::NExT::parse($input);
    die "Error: $Data::NExT::ERROR\n" if defined $Data::NExT::ERROR;

    for my $node (@$tree) {
        print "$node->{name}\n" if $node->{type} eq 'noun';
    }

=head1 DESCRIPTION

Data::NExT is a declarative, hierarchical data format designed for LL(1)
single-pass parsing. It is purely declarative with no code, no logic,
and no Turing-complete expressions.

The format uses two structural token classes distinguished by their
first character:

  First char   Token class   Bracket   Example
  -----------  -----------   -------   -------
  [A-Z]        Noun          [ ]       Window, Agent, Box
  [a-z]        Adjective     ( )       title, name, subscribe
  @            Symbol        (none)    @cancel, @exit
  #            Comment       (none)    # this is a comment

=head1 FUNCTIONS

=head2 parse($input)

Parses a NExT string and returns a reference to an array of top-level
noun nodes. Returns C<undef> on error and sets C<$Data::NExT::ERROR>.

Each node is a hash reference:

    {
        type     => 'noun',            # or 'adj'
        name     => 'Window',          # noun name or adjective name
        children => [...],             # array of child nodes (nouns only)
        value    => {...},             # value node (adjectives only)
        line     => 1,                 # source line number
    }

Value nodes for adjectives:

    { type => 'string',  value => 'hello', line => 2 }
    { type => 'integer', value => 42,      line => 3 }
    { type => 'float',   value => 3.14,    line => 4 }
    { type => 'boolean', value => 1,       line => 5 }  # 1=true, 0=false
    { type => 'symbol',  value => '@foo',  line => 6 }
    { type => 'noun',    name => 'Var', children => [...], line => 7 }

=head1 AUTHOR

Billy Lyrical

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
