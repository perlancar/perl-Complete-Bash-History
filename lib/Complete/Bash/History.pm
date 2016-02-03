package Complete::Bash::History;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       complete_cmdline_from_hist
               );

use Complete::Bash qw(parse_cmdline join_wordbreak_words);

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
};

$SPEC{parse_options} = {
    v => 1.1,
    summary => 'Parse command-line for options and arguments, '.
        'more or less like Getopt::Long',
    description => <<'_',

Parse command-line into words using `Complete::Bash`'s `parse_cmdline()` then
separate options and arguments. Since this routine does not accept
`Getopt::Long` (this routine is meant to be a generic option parsing of
command-lines), it uses a few simple rules to server the common cases:

* After `--`, the rest of the words are arguments (just like Getopt::Long).

* If we get something like `-abc` (a single dash followed by several letters) it
  is assumed to be a bundle of short options.

* If we get something like `-MData::Dump` (a single dash, followed by a letter,
  followed by some letters *and* non-letters/numbers) it is assumed to be an
  option (`-M`) followed by a value.

* If we get something like `--foo` it is a long option. If the next word is an
  option (starts with a `-`) then it is assumed that this option does not have
  argument. Otherwise, the next word is assumed to be this option's value.

* Otherwise, it is an argument (that is, permute is assumed).

_

    args => {
        cmdline => {
            summary => 'Command-line, defaults to COMP_LINE environment',
            schema => 'str*',
        },
        point => {
            summary => 'Point/position to complete in command-line, '.
                'defaults to COMP_POINT',
            schema => 'int*',
        },
        words => {
            summary => 'Alternative to passing `cmdline` and `point`',
            schema => ['array*', of=>'str*'],
            description => <<'_',

If you already did a `parse_cmdline()`, you can pass the words result (the first
element) here to avoid calling `parse_cmdline()` twice.

_
        },
        cword => {
            summary => 'Alternative to passing `cmdline` and `point`',
            schema => ['array*', of=>'str*'],
            description => <<'_',

If you already did a `parse_cmdline()`, you can pass the cword result (the
second element) here to avoid calling `parse_cmdline()` twice.

_
        },
    },
    result => {
        schema => 'hash*',
    },
};
sub parse_options {
    my %args = @_;

    my ($words, $cword) = @_;
    if ($args{words}) {
        ($words, $cword) = ($args{words}, $args{cword});
    } else {
        ($words, $cword) = @{parse_cmdline($args{cmdline}, $args{point}, {truncate_current_word=>1})};
    }

    ($words, $cword) = @{join_wordbreak_words($words, $cword)};

    #use DD; dd [$words, $cword];

    my @types;
    my %opts;
    my @argv;
    my $type;
    $types[0] = 'command';
    my $i = 1;
    while ($i < @$words) {
        my $word = $words->[$i];
        if ($word eq '--') {
            if ($i == $cword) {
                $types[$i] = 'opt_name';
                $i++; next;
            }
            $types[$i] = 'separator';
            for ($i+1 .. @$words-1) {
                $types[$_] = 'arg,' . @argv;
                push @argv, $words->[$_];
            }
            last;
        } elsif ($word =~ /\A-(\w*)\z/) {
            $types[$i] = 'opt_name';
            for (split '', $1) {
                push @{ $opts{$_} }, undef;
            }
            $i++; next;
        } elsif ($word =~ /\A-([\w?])(.*)/) {
            $types[$i] = 'opt_name';
            # XXX currently not completing option value
            push @{ $opts{$1} }, $2;
            $i++; next;
        } elsif ($word =~ /\A--(\w[\w-]*)\z/) {
            $types[$i] = 'opt_name';
            my $opt = $1;
            $i++;
            if ($i < @$words) {
                if ($words->[$i] eq '=') {
                    $types[$i] = 'separator';
                    $i++;
                }
                if ($words->[$i] =~ /\A-/) {
                    push @{ $opts{$opt} }, undef;
                    next;
                }
                $types[$i] = 'opt_val';
                push @{ $opts{$opt} }, $words->[$i];
                $i++; next;
            }
        } else {
            $types[$i] = 'arg,' . @argv;
            push @argv, $word;
            $i++; next;
        }
    }

    return {
        opts      => \%opts,
        argv      => \@argv,
        cword     => $cword,
        words     => $words,
        word_type => $types[$cword],
        #_types    => \@types,
    };
}

$SPEC{complete_cmdline_from_hist} = {
    v => 1.1,
    summary => 'Complete command line from recent entries in bash history',
    description => <<'_',

This routine will search your bash history file (recent first a.k.a. backward)
for entries for the same command, and complete option with the same name or
argument in the same position. For example, if you have history like this:

    cmd1 --opt1 val arg1 arg2
    cmd1 --opt1 valb arg1b arg2b arg3b
    cmd2 --foo

Then if you do:

    complete_cmdline_from_hist(comp_line=>'cmd1 --bar --opt1 ', comp_point=>18);

then it means the routine will search for values for option `--opt1` and will
return:

    ["val", "valb"]

Or if you do:

    complete_cmdline_from_hist(comp_line=>'cmd1 baz ', comp_point=>9);

then it means the routine will search for second argument (argv[1]) and will
return:

    ["arg2", "arg2b"]

_
    args => {
        path => {
            summary => 'Path to `.bash_history` file',
            schema => 'str*',
            description => <<'_',

Defaults to `~/.bash_history`.

If file does not exist or unreadable, will return empty completion answer.

_
        },
        max_hist_lines => {
            summary => 'Stop searching after this amount of history lines',
            schema => ['int*'],
            default => 3000,
            description => <<'_',

-1 means unlimited (search all lines in the file).

Timestamp comments are not counted.

_
        },
        max_result => {
            summary => 'Stop after finding this number of distinct results',
            schema => 'int*',
            default => 100,
            description => <<'_',

-1 means unlimited.

_
        },
        cmdline => {
            summary => 'Command line, defaults to COMP_LINE',
            schema => 'str*',
        },
        point => {
            summary => 'Command line, defaults to COMP_POINT',
            schema => 'int*',
        },
    },
    result_naked=>1,
};
sub complete_cmdline_from_hist {
    require Complete::Util;
    require File::ReadBackwards;

    my %args = @_;

    my $path = $args{path} // $ENV{HISTFILE} // "$ENV{HOME}/.bash_history";
    my $fh = File::ReadBackwards->new($path) or return [];

    my $max_hist_lines = $args{max_hist_lines} // 3000;
    my $max_result     = $args{max_result}     // 100;

    my $word;
    my ($cmd, $opt, $pos);
    my $cl = $args{cmdline} // $ENV{COMP_LINE} // '';
    my $res = parse_options(
        cmdline => $cl,
        point   => $args{point} // $ENV{COMP_POINT} // length($cl),
    );
    $cmd = $res->{words}[0];
    $cmd =~ s!.+/!!;

    my $which;
    if ($res->{word_type} eq 'opt_val') {
        $which = 'opt_val';
        $opt   = $res->{words}->[$res->{cword}-1];
        $word  = $res->{words}->[$res->{cword}];
    } elsif ($res->{word_type} eq 'opt_name') {
        $which = 'opt_name';
        $opt   = $res->{words}->[ $res->{cword} ];
        $word  = $opt;
    } elsif ($res->{word_type} =~ /\Aarg,(\d+)\z/) {
        $which = 'arg';
        $pos  = $1;
        $word = $res->{words}->[$res->{cword}];
    } else {
        return [];
    }

    #use DD; dd {which=>$which, pos=>$pos, word=>$word};

    my %res;
    my $num_hist_lines = 0;
    while (my $line = $fh->readline) {
        chomp($line);

        # skip timestamp comment
        next if $line =~ /^#\d+$/;

        last if $max_hist_lines >= 0 && $num_hist_lines++ >= $max_hist_lines;

        my ($hwords, $hcword) = @{ parse_cmdline($line, 0) };
        next unless @$hwords;

        # COMP_LINE (and COMP_WORDS) is provided by bash and does not include
        # multiple commands (e.g. in '( foo; bar 1 2<tab> )' or 'foo -1 2 | bar
        # 1 2<tab>', bash already only supplies us with 'bash 1 2' instead of
        # the full command-line. This is different when we try to parse the full
        # command-line from history. Complete::Bash::parse_cmdline() is not
        # sophisticated enough to understand full bash syntax. So currently we
        # don't support multiple/complex statements. We'll need a more
        # proper/feature-complete bash parser for that.

        # strip ad-hoc environment setting, e.g.: DEBUG=1 ANOTHER="foo bar" cmd
        while (1) {
            if ($hwords->[0] =~ /\A[A-Za-z_][A-Za-z0-9_]*=/) {
                shift @$hwords; $hcword--;
                next;
            }
            last;
        }
        next unless @$hwords;

        # get the first word as command name
        my $hcmd = $hwords->[0];
        $hcmd =~ s!.+/!!;
        #say "D:hcmd=$hcmd, cmd=$cmd";
        next unless $hcmd eq $cmd;

        my $hpo = parse_options(words=>$hwords, cword=>$hcword);

        if ($which eq 'opt_name') {
            for (keys %{ $hpo->{opts} }) {
                $res{length($_) > 1 ? "--$_":"-$_"}++;
            }
            next;
        }

        if ($which eq 'opt_val') {
            for (@{ $hpo->{opts} // []}) {
                next unless defined;
                $res{$_}++;
            }
            next;
        }

        if ($which eq 'arg') {
            next unless @{ $hpo->{argv} } > $pos;
            $res{ $hpo->{argv}[$pos] }++;
            next;
        }

        die "BUG: invalid which value '$which'";
    }

    Complete::Util::complete_array_elem(
        array => [keys %res],
        word  => $word // '',
    );
}

1;
#ABSTRACT:

=head1 SYNOPSIS


=head1 DESCRIPTION

=cut
