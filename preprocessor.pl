#! /usr/bin/perl -w
use locale;
use Encode;
use Benchmark;
$| = 1;

$start = new Benchmark;

open (FILEIN, "<dirlist.txt") or die "No directory list supplied!";
while (<FILEIN>) { chomp; push @dirlist, $_; }
close (FILEIN);

foreach (@dirlist)
	{
	%contents = ();
	# BEWARE! The next line is subject to change in accordance with your needs
	($current_dir, $output_dir) = ("./raw/" . $_ . "/", "./tokenized/" . $_ . "/");
	opendir (INPUT, $current_dir);
	while (defined ($handle = readdir(INPUT)))
		{
		unless ($handle =~ /^\.{1,2}$/)
			{
			($inhandle, $outhandle) = ($current_dir . $handle, $output_dir . $handle);
			$outhandle =~ s/^\.|\.txt$//g;
			open (FILEIN, "<$inhandle"); { local $/; $file = <FILEIN>; } close (FILEIN);
			
			$file =~ s/(\”)(…|\(|\/)/$1 $2/g;
			$file =~ s/(\w)…(\w)/$1… $2/g;
			$file =~ s/(\w)—(\w)/$1 — $2/g;
			$file =~ s/(\d)(\–|\—)(\d)/$1 $2 $3/g;
			$file =~ s/(\s\$)(\d+((\.|\,)\d+)?)/$1 $2/g;
			$file =~ s/(\sBr)(\d+((\.|\,)\d+)?)/$1 $2/g;
			$file =~ s/([I²VXÕLCÑ])(\–|\—)([I²VXÕLCÑ])/$1 $2 $3/g;
			$file =~ s/\n\*\s+\*\s+\*\n/\n***\n/g;
			$file =~ s/(\-òàê[i³])([\s.,;:?!])/ $1$2/g;
			$file =~ s/\’/'/g;
			
			Encode::from_to($file, 'cp1251', 'utf8');
			$contents{$outhandle} = $file;
			}
		}
	open (FILEOUT, ">fulldir.txt");
	foreach (keys %contents) { print FILEOUT "$_\n$contents{$_}\n"; }
	close (FILEOUT);
	
	print STDOUT "$current_dir: Tokenizing all files at once...\t";
	system("perl utf8-tokenize.pl -f fulldir.txt > tokenized.txt");
	open (FILEIN, "<tokenized.txt"); { local $/; $contents = <FILEIN>; } close (FILEIN);
	Encode::from_to($contents, 'utf8', 'cp1251');
	open (FILEOUT, ">tokenized.txt"); print FILEOUT $contents; close (FILEOUT);
	print STDOUT "Done\n";
	
	open (FILEIN, "<tokenized.txt");
	while (<FILEIN>)
		{
		chomp;
		if (/\/tokenized/) { close (FILEOUT); open (FILEOUT, ">." . $_ . ".txt"); }
		else { print FILEOUT $_ . "\n"; }
		}
	close (FILEIN);

	unlink("fulldir.txt");
	unlink("tokenized.txt");
	}

$end = new Benchmark;
$diff = timediff($end, $start);

printf "Complete in %d seconds.\n", (${$diff}[0]);
print STDOUT "Press any key to exit.\n";
$user = "";
$user = <>;