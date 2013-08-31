#! /usr/bin/perl -w

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                               #
# A rule-based POS tagger for Belorussian                       #
# Author: Vladislav Poritski, BSU                               #
# Description: see https://github.com/poritski/YABC_Tagger      #
#                                                               #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

use locale;
use Getopt::Std;
use Array::Utils qw/unique intersect/;
use List::Util qw/sum/;
use Benchmark;

# # # # # # # # # # # # #
# CONFIGURATION
# # # # # # # # # # # # #

# Letter samples
our $letter_b = "[�������������������������������\\']";
our $letter_l = "[qwertyuiopasdfghjklzxcvbnm]";
# Numeral substitution hash
%num_subst = (
	"�" => "NumOrd:nsN|NumOrd:nsA",
	"�" => "NumOrd:fsG|NumOrd:fsD|NumOrd:fsL",
	"�" => "NumOrd:msI|NumOrd:msL|NumOrd:nsI|NumOrd:nsL|NumOrd:0pD",
	"�" => "NumOrd:0pG|NumOrd:0pL",
	"�" => "NumOrd:msN|NumOrd:msA",
	"�" => "NumOrd:fsA",
	"�" => "NumOrd:0pN|NumOrd:0pA|NumOrd:fsN",
	"��" => "NumOrd:msG|NumOrd:nsG",
	"��" => "NumOrd:msD|NumOrd:nsD",
	"��" => "NumOrd:msI|NumOrd:nsI|NumOrd:0pD",
	"��" => "NumOrd:fsG|NumOrd:fsD|NumOrd:fsL"
	);
# Autoflush mode on. Do not disable
$| = 1;
# Command line options
getopts('c:i:m:o:u:');
# -i: Input
unless ($opt_i) { die "No input file supplied!"; }
else { $input_file = $opt_i; }
# -c: Columns number
unless ($opt_c) { $last_column_index = 2; }
elsif ($opt_c !~ /^\d+$/) { die "Invalid -m flag!"; }
else { $last_column_index = $opt_c - 1; }
# -o: Output ("tagged_" + input file name by default)
unless ($opt_o)
	{
	@path = split (/\//, $input_file);
	$path[$#path] = "tagged_" . $path[$#path];
	$output_file = join ("/", @path);
	}
else { $output_file = $opt_o; }
# -u: Unknown tokens ("unknown_" + input file name by default)
unless ($opt_u)
	{
	@path = split (/\//, $input_file);
	$path[$#path] = "unknown_" . $path[$#path];
	$unknown_file = join ("/", @path);
	}
else { $unknown_file = $opt_u; }
# -m: Tagset mask (none by default)
unless ($opt_m) { $tagset_mask = "none"; }
elsif ($opt_m ne "bnkorpus" && $opt_m ne "multext_east") { die "Invalid -m flag!"; }
else
	{
	if ($opt_m eq "multext_east")
		{
		print STDOUT "Sorry, the tagset mask you've chosen is not implemented now. The output will be unmasked.\n";
		$tagset_mask = "none";
		}
	else { $tagset_mask = $opt_m; }
	}
# Detailed mode. If needed for debugging, turn on and uncomment everywhere in the code
# $detailed = 0;

# # # # # # # # # # # # #
# SCRIPT BODY
# # # # # # # # # # # # #

$start = new Benchmark;

# Loading database and tagset mask, if needed
print STDOUT "Reading database...\n";
if ($tagset_mask ne "none")
	{
	open ($tsmap, "<./base/tagset_mapping_" . $tagset_mask . ".txt") or die "No tagset mask file found. Make sure you haven't removed it accidentally.";
	while (<$tsmap>)
		{
		chomp;
		if ($_ && $_ !~ /^\#/)
			{
			($tag, $substitute) = split (/\t/, $_);
			$mask{$tag} = $substitute;
			}
		}
	close ($tsmap);

	open ($db, "<./base/db.txt") or die "No database file found. Make sure you haven't removed it accidentally.";
	while (<$db>)
		{
		chomp;
		($w, $lemma, $pos) = split (/\t/, $_);
		$lemma{$w} = $lemma;
		$pos{$w} = join ("|", map { $mask{$_} } split (/\|/, $pos));
		}
	close ($db);
	}
else
	{
	open ($db, "<./base/db.txt") or die "No database file found. Make sure you haven't removed it accidentally.";
	while (<$db>)
		{
		chomp;
		($w, $lemma, $pos) = split (/\t/, $_);
		$lemma{$w} = $lemma;
		$pos{$w} = $pos;
		}
	close ($db);
	}

$intermediate = new Benchmark;
$diff = timediff($intermediate, $start);
printf "Complete in %.2f seconds.\n", (${$diff}[1] + ${$diff}[2]);

# Processing tokenized corpus
print STDOUT "Processing input...\n";
open ($raw, "<$input_file") or die "Invalid input file!";
open ($processed, ">$output_file") or die "Invalid output file!";
while (<$raw>)
	{
	chomp;
	++$total;
	if ($total % 10000 == 0) { printf "%u done\r", $total; }
	$res = $_;
	@line = split (/\t/, $_);

	# (Regular tokens = R)
	# R1. "As is"
	$wform = $line[$last_column_index];
	$lc_wform = lc($wform);
	if ($wform ne $lc_wform && $lemma{$wform} && $lemma{$lc_wform})
		{
		@l = (split (/\|/, $lemma{$wform}), split (/\|/, $lemma{$lc_wform}));
		@p = (split (/\|/, $pos{$wform}), split (/\|/, $pos{$lc_wform}));
		$res .= "\t" . join ("|", unique(@l)) . "\t" . join ("|", unique(@p));
		}
	elsif ($lemma{$wform})
		{ $res .= "\t$lemma{$wform}\t$pos{$wform}"; }
	elsif ($lemma{$lc_wform})
		{ $res .= "\t$lemma{$lc_wform}\t$pos{$lc_wform}"; }
	else
		{
		++$level2;
		# R2. Minor orthographic tweaks
		$clean = tweak_symb($wform);
		$lc_clean = lc($clean);
		if ($clean ne $lc_clean && $lemma{$clean} && $lemma{$lc_clean})
			{
			@l = (split (/\|/, $lemma{$clean}), split (/\|/, $lemma{$lc_clean}));
			@p = (split (/\|/, $pos{$clean}), split (/\|/, $pos{$lc_clean}));
			$res .= "\t" . join ("|", unique(@l)) . "\t" . join ("|", unique(@p));
			}
		elsif ($lemma{$clean})
			{ $res .= "\t$lemma{$clean}\t$pos{$clean}"; }
		elsif ($lemma{$lc_clean})
			{ $res .= "\t$lemma{$lc_clean}\t$pos{$lc_clean}"; }
		# (Tokens with numbers = N)
		# N1
		elsif ($wform =~ /^\d+((\.|\,)\d+)?$/)
			{ $res .= "\t$wform\tNumber"; }
		# N2
		elsif ($wform =~ /^\d+\:\d+$/)
			{ $res .= "\t$wform\tScore|Time"; }
		# N3
		elsif ($wform =~ /^\d{2}\:\d{2}\:\d{2}$/)
			{ $res .= "\t$wform\tTime"; }
		# N4
		elsif ($wform =~ /^\d{2}\.\d{2}\.\d{2}(\d{2})?$/)
			{ $res .= "\t$wform\tDate"; }
		# N5
		elsif ($wform =~ /^\d{1,4}\.$/)
			{ $res .= "\t$wform\tListItem"; }
		# N6
		elsif ($wform =~ /^(\d{2,3}|\d{1}\-\d{3}\-\d{3}|\d{1}\-\d{4}\-\d{2})(\-\d{2}){2}$/)
			{ $res .= "\t$wform\tPhone"; }
		# N7
		elsif ($wform =~ /^�\.\d+$/)
			{ $res .= "\t$wform\tIssueID"; }
		# N8
		elsif ($wform =~ /^(\d{1,4})\-([�������]|��|��|��|��)$/)
			{ $res .= "\t" . $1 . "-�\t" . $num_subst{$2}; }
		# (Other regex-detected classes = O)
		# O1. Ambiguous "i"
		elsif ($wform =~ /^I$/)
			{ $res .= "\t$wform|�\tRNumber|Latin|Conj:coord"; }
		# O2. Roman number
		elsif ($wform =~ /^[I�VX�LC�]+$/ && length($wform) <= 6)
			{
			$wform =~ s/�/I/g; $wform =~ s/�/X/g; $wform =~ s/�/C/g;
			$res .= "\t$wform\tRNumber";
			}
		# O3. Word in Latin script
		elsif ($wform =~ /^[a-z]+$/ig && length($wform) >= 3)
			{ $res .= "\t$wform\tLatin"; }
		# O4. Russian word
		elsif ($wform =~ /[���]/ig
				|| $wform =~ /[����]�/g
				|| $wform =~ /��/ig
				|| ($wform =~ /[���][��]/g && $wform !~ /(�|��)/ig)
				|| ($wform =~ /�[���]/g && $wform !~ /(�|��|[a-z])/ig)
				|| ($wform =~ /[��]�/g && $wform !~ /�/ig && $wform !~ /��/g && $wform !~ /�(��|�)�/ig)
				|| ($wform =~ tr/�/�/ && $wform =~ tr/�/�/ > 2 && $wform !~ /[a-z��\-]/))
			{ $res .= "\t$wform\tRussian"; }
		# O5. Truncated name
		elsif ($wform =~ /^[�����������������������̲���]$/)
			{ $res .= "\t$wform\tNP_initial"; }
		else
			{
			++$level3;
			# R3. Tarashkevitsa
			$tar_removed = tweak_tar($clean);
			$lc_tar_removed = lc($tar_removed);
			if ($tar_removed ne $lc_tar_removed && $lemma{$tar_removed} && $lemma{$lc_tar_removed})
				{
				@l = (split (/\|/, $lemma{$tar_removed}), split (/\|/, $lemma{$lc_tar_removed}));
				@p = (split (/\|/, $pos{$tar_removed}), split (/\|/, $pos{$lc_tar_removed}));
				$res .= "\t" . join ("|", map { $_ . "[TAR]" } unique(@l)) . "\t" . join ("|", unique(@p));
				}
			elsif ($lemma{$tar_removed})
				{ $res .= "\t" . $lemma{$tar_removed} . "[TAR]\t" . $pos{$tar_removed}; }
			elsif ($lemma{$lc_tar_removed})
				{ $res .= "\t" . $lemma{$lc_tar_removed} . "[TAR]\t" . $pos{$lc_tar_removed}; }
			else
				{
				++$level4;
				# R4. Line-delimiting hyphen
				$hyph_removed = tweak_hyph($clean);
				$lc_hyph_removed = lc($hyph_removed);
				if ($hyph_removed ne $lc_hyph_removed && $lemma{$hyph_removed} && $lemma{$lc_hyph_removed})
					{
					@l = (split (/\|/, $lemma{$hyph_removed}), split (/\|/, $lemma{$lc_hyph_removed}));
					@p = (split (/\|/, $pos{$hyph_removed}), split (/\|/, $pos{$lc_hyph_removed}));
					$res .= "\t" . join ("|", map { $_ . "[HYPH]" } unique(@l)) . "\t" . join ("|", unique(@p));
					# if ($detailed) { ++$discontinuous{$wform}{$hyph_removed}; ++$discontinuous{$wform}{$lc_hyph_removed}; }
					}
				elsif ($lemma{$hyph_removed})
					{
					$res .= "\t" . $lemma{$hyph_removed} . "[HYPH]\t" . $pos{$hyph_removed};
					# if ($detailed) { ++$discontinuous{$wform}{$hyph_removed}; }
					}
				elsif ($lemma{$lc_hyph_removed})
					{
					$res .= "\t" . $lemma{$lc_hyph_removed} . "[HYPH]\t" . $pos{$lc_hyph_removed};
					# if ($detailed) { ++$discontinuous{$wform}{$lc_hyph_removed}; }
					}
				# R5. 2-compound
				elsif ($wform =~ tr/\-\�/\-\�/ == 1)
					{
					($a, $b) = split (/\-|\�/, $wform);
					if ($lemma{$a} && $lemma{$b} && $pos{$a} eq $pos{$b})
						{ $res .= "\t" . $lemma{$a} . "-" . $lemma{$b} . "\t" . $pos{$a}; }
					elsif ($lemma{$a} && $lemma{$b})
						{
						@grams_a = split (/\|/, $pos{$a});
						@grams_b = split (/\|/, $pos{$b});
						@grams_isect = intersect(@grams_a, @grams_b);
						@adj_second = grep { /^(Adj\:|A[XQ]P)/ } @grams_b;
						if (@grams_isect > 0)
							{ $res .= "\t" . $lemma{$a} . "-" . $lemma{$b} . "\t" . join ("|", @grams_isect); }
						elsif ($#grams_a == 0 && ($grams_a[0] eq "Adv" || $grams_a[0] eq "RP") && @adj_second > 0)
							{ $res .= "\t" . $lemma{$a} . "-" . $lemma{$b} . "\t" . join ("|", @adj_second); }
						else
							{
							$res .= "\t?$wform\tUNK"; ++$unknown{$wform};
							# if ($detailed) { ++$compounds{join ("\t", ($a, $b, $lemma{$a}, $lemma{$b}, $pos{$a}, $pos{$b}))}; }
							}
						}
					elsif ($lemma{$b} && $a =~ /^\d+$/)
						{ $res .= "\t" . $a . "-" . $lemma{$b} . "\t" . $pos{$b}; }
					else { $res .= "\t?$wform\tUNK"; ++$unknown{$wform}; }
					}
				# R6. 3-compound
				elsif ($wform =~ tr/\-\�/\-\�/ == 2)
					{
					($a, $b, $c) = split (/\-|\�/, $wform);
					if ($lemma{$a} && $lemma{$b} && $lemma{$c} && $pos{$a} eq $pos{$b} && $pos{$b} eq $pos{$c})
						{ $res .= "\t" . $lemma{$a} . "-" . $lemma{$b} . "-" . $lemma{$c} . "\t" . $pos{$a}; }
					else { $res .= "\t?$wform\tUNK"; ++$unknown{$wform}; }
					}
				# Noncovered tokens
				else { $res .= "\t?$wform\tUNK"; ++$unknown{$wform}; }
				}
			}
		}
	# if ($detailed) { ++$detail{$res}; }
	print $processed $res . "\n";
	}
close ($raw);
close ($processed);

open (FILEOUT, ">$unknown_file") or die "Invalid file for unknown tokens!";
foreach (sort {$unknown{$b} <=> $unknown{$a}} keys %unknown) { print FILEOUT "$_\t$unknown{$_}\n"; }
close (FILEOUT);

=pod
if ($detailed)
	{
	open (FILEOUT, ">output_stat.txt");
	foreach (sort {$detail{$b} <=> $detail{$a}} keys %detail) { print FILEOUT "$_\t$detail{$_}\n"; }
	close (FILEOUT);
	
	open (FILEOUT, ">compounds.txt");
	foreach (sort {$compounds{$b} <=> $compounds{$a}} keys %compounds) { print FILEOUT "$_\t$compounds{$_}\n"; }
	close (FILEOUT);

	open (FILEOUT, ">discontinuous.txt");
	foreach $w (sort keys %discontinuous)
		{ foreach $s (sort keys %{$discontinuous{$w}}) { print FILEOUT "$w\t$s\t$discontinuous{$w}{$s}\n"; } }
	close (FILEOUT);
	}
=cut

$end = new Benchmark;
$diff = timediff($end, $intermediate);
$noncovered = sum (values %unknown);
$covered = $total - $noncovered;
printf "Complete in %.2f seconds.\n", (${$diff}[1] + ${$diff}[2]);
printf "%u tokens in total, %u tokens processed (%.4f).\n", $total, $covered, ($covered / $total);
printf "Recognized at once: %u (%.4f).\n", ($total - $level2), ($total - $level2) / $total;
printf "2nd level gain: %u (%.4f).\n", ($level2 - $level3), ($level2 - $level3) / $total;
printf "3rd level gain: %u (%.4f).\n", ($level3 - $level4), ($level3 - $level4) / $total;
printf "4th level gain: %u (%.4f).\n", ($level4 - $noncovered), ($level4 - $noncovered) / $total;
print STDOUT "Press any key to exit.\n";
$user = "";
$user = <>;

# # # # # # # # # # # # #
# SUBROUTINES
# # # # # # # # # # # # #

sub tweak_symb
	{
	my $a = shift;
	$a =~ s/^�/�/;
	$a =~ s/^�/�/;
	$a =~ s/^i$/�/;
	$a =~ s/([�����������])ii($|\-)/$1��$2/;
	$cyrcount = $a =~ tr/����������������������������ء���������ײ���//;
	$latcount = $a =~ tr/qwrtusdfghjklzvbnmQWRUSDFGJLZVN//;
	if ($cyrcount) { $a =~ s/i/�/g; $a =~ s/I/�/g; }
	elsif ($latcount) { $a =~ s/�/i/g; $a =~ s/�/I/g; }
	else
		{
		$a =~ s/($letter_b)i($|$letter_b)/$1�$2/g;
		$a =~ s/($letter_b)I($|$letter_b)/$1�$2/g;
		$a =~ s/^i($letter_b)/�$1/;
		$a =~ s/^I($letter_b)/�$1/;
		$a =~ s/($letter_l)�($|$letter_l)/$1i$2/g;
		$a =~ s/($letter_l)�($|$letter_l)/$1I$2/g;
		$a =~ s/^�($letter_l)/i$1/;
		$a =~ s/^�($letter_l)/I$1/;
		}
	return $a;
	}

sub tweak_tar
	{
	my $a = shift;
	$a =~ s/��([������])([�����])/�$1$2/i;
	$a =~ s/����([�����])/���$1/i;
	$a =~ s/��([���])/�'$1/i;
	$a =~ s/��([�������])([�����])/�$1$2/i;
	$a =~ s/����/�����/i;
	$a =~ s/��([��])([�����])/�$1$2/i;
	$a =~ s/��([��])([�����])/�$1$2/i;
	return $a;
	}

sub tweak_hyph
	{
	my $a = shift;
	if ($a =~ tr/\-/\-/ == 1) { $a =~ s/(\w)\-(\w)/$1$2/g; }
	return $a;
	}

# # # # # # # # # # # # #
# FOR POSSIBLE FUTURE USE
# # # # # # # # # # # # #

# our $non_tar = "^(��(�(�?|�|�)?|�(��|�|�|��|�)|��|��)|�(�(�|�(�|�)?|�(�|�?)|�(��|��)?|�|�|�)|�(��|��))|���|���|����|����|��|���|���|����)����$|^�����[����]|����[��]";