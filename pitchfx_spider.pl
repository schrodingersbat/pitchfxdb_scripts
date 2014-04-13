#! /usr/bin/perl

use LWP;
my $browser = LWP::UserAgent->new;
$baseurl = "http://gd2.mlb.com/components/game/mlb";
$outputdir = "/home/svf/baseball/fullgames";

use Time::Local;

sub extractDate($) {
    # extracts and formats date from a time stamp
    ($t) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) 
	= localtime($t);
    $mon  += 1;
    $year += 1900;
    $mon = (length($mon) == 1) ? "0$mon" : $mon;
    $mday = (length($mday) == 1) ? "0$mday" : $mday;
    return ($mon, $mday, $year);
}

sub verifyDir($) {
    # verifies that a directory exists,
    # creates the directory if the directory doesn't
    my ($d) = @_;
    if (-e $d) {
	die "$d not a directory\n" unless (-d $outputdir);
    } else {
	die "could not create $d: $!\n" unless (mkdir $d);
    }    
}

# get all important files from MLB.com, 4/3/05 through yesterday
#($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
#$start = timelocal(0,0,0,3,3,105);
#$start = timelocal(0,0,0,$mday - 4,$mon,$year);
#$start = timelocal(0,0,0,1,3,109);
$start = timelocal(0,0,0,12,3,114);
($mon, $mday, $year) = extractDate($start);
print "starting at $mon/$mday/$year\n";

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
#$now = timelocal(0,0,0,$mday - 1,$mon,$year);
$now = timelocal(0,0,0,$mday,$mon,$year);
#$now = timelocal(0,0,0,3,10,105);
($mon, $mday, $year) = extractDate($now);
print "ending at $mon/$mday/$year\n";

verifyDir($outputdir);

for ($t = $start; $t < $now; $t += 60*60*24) {
    ($mon, $mday, $year) = extractDate($t);
    print "processing $mon/$mday/$year\n";

    verifyDir("$outputdir/year_$year");
    verifyDir("$outputdir/year_$year/month_$mon");
    verifyDir("$outputdir/year_$year/month_$mon/day_$mday");

    $dayurl = "$baseurl/year_$year/month_$mon/day_$mday/";
    print "\t$dayurl\n";
    
    $response = $browser->get($dayurl);
    die "Couldn't get $dayurl: ", $response->status_line, "\n"
        unless $response->is_success;
    $html = $response->content;
    my @games = ();
    while($html =~ m/<a href=\"(gid_\w+\/)\"/g ) {
        push @games, $1;
    }

    foreach $game (@games) {
	$gamedir = "$outputdir/year_$year/month_$mon/day_$mday/$game";
	if (-e $gamedir) {
	    # already fetched info on this game
	    print "\t\tskipping game: $game\n";
	} else {
	    print "\t\tfetcing game: $game\n";
	    verifyDir($gamedir);
	    $gameurl = "$dayurl/$game";
	    $response = $browser->get($gameurl);
	    die "Couldn't get $gameurl: ", $response->status_line, "\n"
		unless $response->is_success;
	    $gamehtml = $response->content;
	    
	    if($gamehtml =~ m/<a href=\"boxscore\.xml\"/ ) {
		$boxurl = "$dayurl/$game/boxscore.xml";
		$response = $browser->get($boxurl);
		die "Couldn't get $boxurl: ", $response->status_line, "\n"
		    unless $response->is_success;
		$boxhtml = $response->content;
		open BOX, ">$gamedir/boxscore.xml" 
		    or die "could not open file $gamedir/boxscore.xml: $|\n";
		print BOX $boxhtml;
		close BOX;
	    } else {
		print "warning: no xml box score for $game\n";
	    }
            if($gamehtml =~ m/<a href=\"game\.xml\"/ ) {
                $gameurl = "$dayurl/$game/game.xml";
                $response = $browser->get($gameurl);
                die "Couldn't get $gameurl: ", $response->status_line, "\n"
                    unless $response->is_success;
                $boxhtml = $response->content;
                open BOX, ">$gamedir/game.xml"
                    or die "could not open file $gamedir/game.xml: $|\n";
                print BOX $boxhtml;
                close BOX;
            } else {
                print "warning: no xml game score for $game\n";
            }
	    
	    if($gamehtml =~ m/<a href=\"players\.xml\"/ ) {
		$plyrurl = "$dayurl/$game/players.xml";
		$response = $browser->get($plyrurl);
		die "Couldn't get $plyrurl: ", $response->status_line, "\n"
		    unless $response->is_success;
	    $plyrhtml = $response->content;
		open PLYRS, ">$gamedir/players.xml" 
		    or die "could not open file $gamedir/players.xml: $|\n";
		print PLYRS $plyrhtml;
		close PLYRS;
	    } else {
		print "warning: no player list for $game\n";
	    }
	    
	    
	    if($gamehtml =~ m/<a href=\"inning\/\"/ ) {
		$inningdir = "$gamedir/inning";
		verifyDir($inningdir);
		$inningurl = "$dayurl/$game/inning/";
		$response = $browser->get($inningurl);
		die "Couldn't get $gameurl: ", $response->status_line, "\n"
		    unless $response->is_success;
		$inninghtml = $response->content;

		my @files = ();
		while($inninghtml =~ m/<a href=\"(inning_.*)\"/g ) {
		    push @files, $1;
		}
		
		foreach $file (@files) {
		    print "\t\t\tinning file: $file\n";
		    $fileurl = "$inningurl/$file";
		    $response = $browser->get($fileurl);
		    die "Couldn't get $fileurl: ", $response->status_line, "\n"
			unless $response->is_success;
		    $filehtml = $response->content;
		    open FILE, ">$inningdir/$file" 
			or die "could not open file $inningdir/$file: $|\n";
		    print FILE $filehtml;
		    close FILE;
		}
	    }
	    
	    if($gamehtml =~ m/<a href=\"batters\/\"/ ) {
		$battersdir = "$gamedir/batters";
		verifyDir($battersdir);
		$battersurl = "$dayurl/$game/batters/";
		$response = $browser->get($battersurl);
		die "Couldn't get $battersurl: ", $response->status_line, "\n"
		    unless $response->is_success;
		$battershtml = $response->content;
		
		my @files = ();
		while($battershtml =~ m/<a href=\"(\d+\.xml)\"/g ) {
		    push @files, $1;
		}
		
		foreach $file (@files) {
		    print "\t\t\tbatter file: $file\n";
		    $fileurl = "$battersurl/$file";
		    $response = $browser->get($fileurl);
		    die "Couldn't get $fileurl: ", $response->status_line, "\n"
			unless $response->is_success;
		    $filehtml = $response->content;
		    open FILE, ">$battersdir/$file" 
			or die "could not open file $battersdir/$file: $|\n";
		    print FILE $filehtml;
		    close FILE;
		}
	    }
	    
	    if($gamehtml =~ m/<a href=\"pitchers\/\"/ ) {
		$pitchersdir = "$gamedir/pitchers";
		verifyDir($pitchersdir);
		$pitchersurl = "$dayurl/$game/pitchers/";
		$response = $browser->get($pitchersurl);
		die "Couldn't get $pitchersurl: ", $response->status_line, "\n"
		    unless $response->is_success;
		$pitchershtml = $response->content;
		
		my @files = ();
		while($pitchershtml =~ m/<a href=\"(\d+\.xml)\"/g ) {
		    push @files, $1;
		}
		
		foreach $file (@files) {
		    print "\t\t\tpitcher file: $file\n";
		    $fileurl = "$pitchersurl/$file";
		    $response = $browser->get($fileurl);
		    die "Couldn't get $fileurl: ", $response->status_line, "\n"
			unless $response->is_success;
		    $filehtml = $response->content;
		    open FILE, ">$pitchersdir/$file" 
			or die "could not open file $pitchersdir/$file: $|\n";
		    print FILE $filehtml;
		    close FILE;
		}
	    }
	    
	    
	    if($gamehtml =~ m/<a href=\"pbp\/\"/ ) {
		$pbpdir = "$gamedir/pbp";
		verifyDir($pbpdir);
		
		$bpbpdir = "$gamedir/pbp/batters";
		verifyDir($bpbpdir);
		$bpbpurl = "$dayurl/$game/pbp/batters";
		$response = $browser->get($bpbpurl);
		die "Couldn't get $bpbpurl: ", $response->status_line, "\n"
		    unless $response->is_success;
		$bpbphtml = $response->content;
		
		my @files = ();
		while($bpbphtml =~ m/<a href=\"(\d+\.xml)\"/g ) {
		    push @files, $1;
		}
		
		foreach $file (@files) {
		    print "\t\t\tpbp batter file: $file\n";
		    $fileurl = "$bpbpurl/$file";
		    $response = $browser->get($fileurl);
		    die "Couldn't get $fileurl: ", $response->status_line, "\n"
			unless $response->is_success;
		    $filehtml = $response->content;
		    open FILE, ">$bpbpdir/$file" 
			or die "could not open file $bpbpdir/$file: $!\n";
		    print FILE $filehtml;
		    close FILE;
		}
		
		$ppbpdir = "$gamedir/pbp/pitchers";
		verifyDir($ppbpdir);
		$ppbpurl = "$dayurl/$game/pbp/pitchers";
		$response = $browser->get($ppbpurl);
		die "Couldn't get $ppbpurl: ", $response->status_line, "\n"
		    unless $response->is_success;
		$ppbphtml = $response->content;
		
		my @files = ();
		while($ppbphtml =~ m/<a href=\"(\d+\.xml)\"/g ) {
		    push @files, $1;
		}
		
		foreach $file (@files) {
		    print "\t\t\tpbp pitcher file: $file\n";
		    $fileurl = "$ppbpurl/$file";
		    $response = $browser->get($fileurl);
		    die "Couldn't get $fileurl: ", $response->status_line, "\n"
			unless $response->is_success;
		    $filehtml = $response->content;
		    open FILE, ">$ppbpdir/$file" 
			or die "could not open file $ppbpdir/$file: $|\n";
		    print FILE $filehtml;
		    close FILE;
		}
	    }
	    sleep(1); # be at least somewhat polite; one game per second
	}
    }
}
