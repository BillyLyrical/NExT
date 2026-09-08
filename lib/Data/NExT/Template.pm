package Data::NExT::Template;

use strict;
use warnings;

our $VERSION = '0.1.0';

sub new {
    my ($class, %opts) = @_;
    my $self = {
        config    => $opts{config}    // {},
        functions => $opts{functions} // {},
        cli_vars  => $opts{cli_vars}  // {},
        opts      => $opts{opts}      // {},
    };
    bless $self, $class;
    return $self;
}

sub preprocess {
    my ($self, $input) = @_;
    my $output = $input;

    $output = $self->_process_ignore($output);
    $output = $self->_process_conditionals($output);
    $output = $self->_process_includes($output, '.');
    $output = $self->_expand_variables($output);
    $output = $self->_expand_functions($output);

    return $output;
}

# --- Ignore blocks ---

sub _process_ignore {
    my ($self, $text) = @_;
    # Strip innermost %Ignore...%EndIgnore first (handles nesting)
    my $max_iter = 100;
    while ($text =~ /[%]Ignore\b/ && $max_iter-- > 0) {
        # Find the first %Ignore
        $text =~ /[%]Ignore\b/s or last;
        my $start = $-[0];

        # Find the matching %EndIgnore (innermost: no %Ignore between)
        my $search_from = $+[0];
        my $depth = 1;
        my $end_pos = -1;

        while ($depth > 0 && $search_from < length($text)) {
            if (substr($text, $search_from) =~ /\G.*?[%](Ignore|EndIgnore)\b/s) {
                my $pos = $-[0] + $search_from;
                $search_from = $+[0] + $search_from;
                if ($1 eq 'Ignore') {
                    $depth++;
                } else {
                    $depth--;
                    if ($depth == 0) {
                        $end_pos = $search_from;
                    }
                }
            } else {
                last;
            }
        }

        if ($end_pos >= 0) {
            substr($text, $start, $end_pos - $start, '');
        } else {
            die "unclosed %Ignore\n";
        }
    }
    return $text;
}

# --- Conditionals ---

sub _process_conditionals {
    my ($self, $text) = @_;
    my $max_iter = 100;
    while ($text =~ /[%]If(?:def|ndef)\b/ && $max_iter-- > 0) {
        # Match innermost conditional (no nested conditionals inside)
        $text =~ s/([%]Ifn?def\("[^"]*"\).*?[%]Endif)/$self->_eval_one_conditional($1)/se;
    }
    die "unclosed %Ifdef\n" if $text =~ /[%]Ifn?def\b/;
    return $text;
}

sub _eval_one_conditional {
    my ($self, $block) = @_;

    my $is_unless = ($block =~ /^[%]Ifndef/);
    my ($var) = $block =~ /^[%]Ifn?def\("([^"]*)"\)/;

    my ($then, $else) = ('', '');
    if ($block =~ /^[%]Ifn?def\("[^"]*"\)(.*?)[%]Else(.*?)[%]Endif/s) {
        ($then, $else) = ($1, $2);
    } elsif ($block =~ /^[%]Ifn?def\("[^"]*"\)(.*?)[%]Endif/s) {
        $then = $1;
    }

    my $val = $self->_resolve_name($var);
    my $cond = defined $val && $val ne '';
    $cond = !$cond if $is_unless;
    return $cond ? $then : $else;
}

# --- Include processing ---

sub _process_includes {
    my ($self, $text, $current_dir) = @_;
    my $max_depth = $self->{opts}{max_depth} // 10;
    return $self->_process_includes_inner($text, $current_dir, 0, $max_depth);
}

sub _process_includes_inner {
    my ($self, $text, $current_dir, $depth, $max_depth) = @_;

    if ($max_depth > 0 && $depth > $max_depth) {
        die "max include depth exceeded ($max_depth)\n";
    }

    my $saw_include = 1;
    while ($saw_include) {
        $saw_include = 0;

        if ($text =~ s/^(\s*)[%]Include\("([^"]*)"\)\s*$/_do_include($self, $2, $current_dir, $depth, $max_depth, 0)/me) {
            $saw_include = 1;
        }
        elsif ($text =~ s/^(\s*)[%]OptInclude\("([^"]*)"\)\s*$/_do_include($self, $2, $current_dir, $depth, $max_depth, 1)/me) {
            $saw_include = 1;
        }
        elsif ($text =~ s/^(.*?)[%]Include\("([^"]*)"\)/$1._do_include($self, $2, $current_dir, $depth, $max_depth, 0)/e) {
            $saw_include = 1;
        }
        elsif ($text =~ s/^(.*?)[%]OptInclude\("([^"]*)"\)/$1._do_include($self, $2, $current_dir, $depth, $max_depth, 1)/e) {
            $saw_include = 1;
        }
    }

    return $text;
}

sub _do_include {
    my ($self, $path, $current_dir, $depth, $max_depth, $optional) = @_;

    my $resolved = $self->_resolve_include_path($path, $current_dir);

    unless (defined $resolved) {
        if ($optional) {
            return '';
        }
        die "include file not found: '$path'\n";
    }

    open my $fh, '<', $resolved or do {
        if ($optional) {
            return '';
        }
        die "include file not found: '$path'\n";
    };
    my $content = do { local $/; <$fh> };
    close $fh;

    my $dir = $resolved;
    $dir =~ s{/[^/]*$}{};
    $content = $self->_process_includes_inner($content, $dir, $depth + 1, $max_depth);

    return $content;
}

sub _resolve_include_path {
    my ($self, $path, $current_dir) = @_;

    if ($path =~ m{^/}) {
        return $path if -f $path;
        return undef;
    }

    my $candidate = "$current_dir/$path";
    return $candidate if -f $candidate;

    my @search = $self->_build_search_path();
    for my $dir (@search) {
        $candidate = "$dir/$path";
        return $candidate if -f $candidate;
    }

    return undef;
}

sub _build_search_path {
    my ($self) = @_;
    my @path;

    push @path, '.';

    if (defined $ENV{NEXTPATH}) {
        push @path, split /:/, $ENV{NEXTPATH};
    }

    if ($self->{config}{include_path}) {
        my $p = $self->{config}{include_path};
        push @path, ref $p eq 'ARRAY' ? @$p : ($p);
    }

    if ($self->{opts}{include_path}) {
        push @path, @{$self->{opts}{include_path}};
    }

    if ($self->{_search_paths}) {
        push @path, @{$self->{_search_paths}};
    }

    return @path;
}

# --- Variable expansion ---

sub _expand_variables {
    my ($self, $text) = @_;
    # Handle %Env("NAME") — explicit ENV lookup
    $text =~ s/[%]Env\("([^"]*)"\)/$self->_resolve_explicit_env($1)/ge;
    # Handle %Var("path") — explicit hashref lookup
    $text =~ s/[%]Var\("([^"]*)"\)/$self->_resolve_explicit_var($1)/ge;
    # Handle ${VAR} / ${path} / ${A|B:default}
    $text =~ s/\$\{([^}]+)\}/$self->_resolve_var_expr($1)/ge;
    return $text;
}

sub _resolve_explicit_env {
    my ($self, $name) = @_;
    return $ENV{$name} if defined $ENV{$name};
    return '';
}

sub _resolve_explicit_var {
    my ($self, $path) = @_;
    if ($path =~ m{/}) {
        my $val = $self->_resolve_path($path);
        return defined $val ? $val : '';
    }
    return $self->{config}{$path} // '';
}

sub _resolve_var_expr {
    my ($self, $expr) = @_;

    if ($expr =~ /\|/) {
        my @parts = split /\|/, $expr, -1;
        my $default;
        if ($parts[-1] =~ /:/) {
            ($parts[-1], $default) = split /:/, $parts[-1], 2;
        }
        return $self->_resolve_fallback(\@parts, $default);
    }

    if ($expr =~ m{/}) {
        my ($path, $default) = split /:/, $expr, 2;
        my $val = $self->_resolve_path($path);
        return defined $val ? $val : ($default // '');
    }

    my ($name, $default) = split /:/, $expr, 2;
    my $val = $self->_resolve_name($name);
    return defined $val ? $val : ($default // '');
}

sub _resolve_name {
    my ($self, $name) = @_;

    return $self->{cli_vars}{$name} if exists $self->{cli_vars}{$name};
    return $self->{config}{$name} if exists $self->{config}{$name};
    return $ENV{$name} if defined $ENV{$name};

    return undef;
}

sub _resolve_path {
    my ($self, $path) = @_;
    my @parts = split m{/}, $path, -1;

    return $self->{cli_vars}{$path} if exists $self->{cli_vars}{$path};

    my $val = $self->{config};
    for my $part (@parts) {
        return undef unless ref $val eq 'HASH';
        $val = $val->{$part};
    }
    return $val if defined $val;

    return undef;
}

sub _resolve_fallback {
    my ($self, $names, $default) = @_;
    for my $name (@$names) {
        next if $name eq '';
        my $val = $self->_resolve_name($name);
        return $val if defined $val;
    }
    return $default // '';
}

# --- Function expansion ---

sub _expand_functions {
    my ($self, $text) = @_;
    $text =~ s/[%]([A-Z][a-zA-Z0-9_]*)\("([^"]*)"\)/$self->_call_func($1, $2)/ge;
    $text =~ s/[%]([A-Z][a-zA-Z0-9_]*)\b/$self->_call_func($1, '')/ge;
    $text =~ s/[%]([a-z][a-zA-Z0-_-]*)\("([^"]*)"\)/$self->_call_func($1, $2)/ge;
    $text =~ s/[%]([a-z][a-zA-Z0-_-]*)\b/$self->_call_func($1, '')/ge;
    return $text;
}

sub _call_func {
    my ($self, $name, $arg) = @_;
    my $func = $self->{functions}{$name};
    unless ($func) {
        die "undefined function '$name'\n";
    }
    my $result = eval { $func->($arg) };
    if ($@) {
        chomp $@;
        die "function '$name' failed: $@\n";
    }
    return defined $result ? $result : '';
}

1;

__END__

=head1 NAME

Data::NExT::Template - Pre-processor for NExT template files

=head1 SYNOPSIS

    use Data::NExT::Template;

    my $t = Data::NExT::Template->new(
        config    => { db_host => 'localhost' },
        functions => {
            'hostname' => sub { `hostname -s` },
        },
        cli_vars  => { PORT => '3000' },
        opts      => { max_depth => 10 },
    );

    my $nxt = $t->preprocess($template_text);

=head1 DESCRIPTION

Data::NExT::Template pre-processes .nxt template files into pure NExT.
It handles variable interpolation, host-language function calls,
conditional blocks, file inclusion, and ignore blocks.

The output is valid NExT text ready for Data::NExT::parse().

=head1 METHODS

=head2 new(%opts)

Creates a new template pre-processor.

Options:

  config     - hashref of variable values (lowest priority after ENV)
  functions  - hashref of name => sub { ... } callbacks
  cli_vars   - hashref of CLI variable overrides (highest priority)
  opts       - hashref of options:
                 max_depth    - max include depth (default 10, 0=unlimited)
                 include_path - arrayref of additional search paths

=head2 preprocess($text)

Processes the template text and returns pure NExT.

Processing order:
  1. Strip %Ignore / %EndIgnore blocks
  2. Evaluate %Ifdef / %Ifndef / %Else / %Endif conditionals
  3. Expand %Include / %OptInclude directives
  4. Expand ${VAR} variables, ${path} paths, ${A|B:default} chains
  5. Expand %function calls

=head1 AUTHOR

Billy Lyrical

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
