#! /usr/bin/perl -w
use locale;
use Benchmark;
$| = 1;

$start = new Benchmark;

# Processing input data
open (FILEIN, "<dirlist.txt");
while (<FILEIN>)
	{
	chomp;
	# BEWARE! The next line is subject to change in accordance with your needs
	push @dirlist, "./tokenized/" . $_ . "/";
	}
close (FILEIN);

$fcount = 0;
foreach $d (@dirlist)
	{
	opendir (INPUT, $d);
	while (defined ($handle = readdir(INPUT)))
		{
		unless ($handle =~ /^\.{1,2}$/)
			{
			open ($file, "<" . $d. $handle);
			++$fcount;
			$wcount = 0;
			$fid = $d. $handle;
			# BEWARE! The next line is subject to change in accordance with your needs
			$fid =~ s:\.\/tokenized\/::g;
			$mapping{$fcount} = $fid;
			while (<$file>)
				{
				chomp;
				++$wcount;
				push @data, join ("\t", ($fcount, $wcount, $_));
				}
			close ($file);
			}
		}
	closedir (INPUT);
	}

open (FILEOUT, ">corpus.txt");
foreach (@data) { print FILEOUT "$_\n"; }
close (FILEOUT);

open (FILEOUT, ">corpus_fileid.txt");
foreach (1..$fcount) { print FILEOUT "$_\t$mapping{$_}\n"; }
close (FILEOUT);

$end = new Benchmark;
$diff = timediff($end, $start);

printf "Complete in %.2f seconds.\n", (${$diff}[1] + ${$diff}[2]);
print STDOUT "Press any key to exit.\n";
$user = "";
$user = <>;