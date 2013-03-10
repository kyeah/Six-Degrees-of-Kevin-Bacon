#!/usr/bin/perl
use v5.10;
use autodie;
use feature 'switch';
$| = 1;

my $sep = "---------------------------------------------------------------\n";
my $less_prompt = "Would you like to view using LESS? [y/n]: ";

my @prompts = ( 
    "Holy holes in donuts, Batman! Let's baconate: ",
    "Jinkies! I can't believe I've never tried to baconate: ",
    "If I was Kevin Bacon, I would baconate: ",
    "Gee willikers, I really want to baconate: ",
    "Holy smokes, I'm just dying to baconate: ",
    "I dedicate this next baconation to: ",
    "Shall I compare thee to a bacon's day? : ",
    "I bite my bacon at thee, ",
    'While I nodded, nearly napping, suddenly there came a tapping;
                 "Baconate me," said: ',
    "Better to reign in Hell, than to baconate: ",
    "Two actors diverged in a wood, and I,
                 I baconated the one less traveled by: ",
    "bacon: " );


my @spinner = qw(/ | \ -);
state $curr_spinner = 0;
state $counter = 0;
our %actors; 
our %movies;


##########################
###  DATABASE LOADING  ### 
##########################

print "Loading...";
my $start_time = time;

foreach $arg (@ARGV)
{
    open my $database, "-|", "zcat $arg";

    my $current_actor;
    while(<$database>) {
        
        # A fine line between performance and satisfying spinny
        if($counter == 15000){ 
            $counter = 0;
            $curr_spinner = ($curr_spinner+1)%4; 
            print "$spinner[$curr_spinner]\b";
        } $counter += 1;

        # Match movie; use //p to get actor (prematch) and details (postmatch)
        next unless /\t+ (?<movie>.* \s \(\d{4} (?:\/[IVXL]+)? \))/px;
        my ($movie, $actor) = ($+{movie}, ${^PREMATCH});
        $current_actor = $actor if $actor;
        next if substr($movie, 0, 1) eq '"' or ${^POSTMATCH} =~ /\( (?:VG|TV|V) \)/x;

        # Add data to hashies
        $movies{$current_actor} //= [];
        $actors{$movie} //= [];
        push $movies{$current_actor}, $movie;
        push $actors{$movie}, $current_actor;
    }
}
my $end_time = time - $start_time;
print "bam! [$end_time \bs]\n";   

########################
###  USER INTERFACE  ### 
########################

## Only file handling will be with LESS, so we can turn off the safety helmet.
no autodie;
$SIG{PIPE} = 'IGNORE';

sub spin_loader {
    if ($counter == 50000) { 
        $counter = 0;
        $curr_spinner = ($curr_spinner+1)%4; 
        print "$spinner[$curr_spinner]\b";
    } $counter += 1;
}

sub match_all {
    $actor = shift;
    for $key (@_) {
        return 0 unless $actor =~ /\b$key\b/i;  # Doesn't account for foreign characters
    }
    return 1;
}

print $prompts[rand @prompts];
while(<STDIN>) {
    chomp;
    exit unless $_;

    # User knows what they want - give it to 'em.
    if (exists $movies{$_}) {
        print "HELL YEAH I CAN SEARCH THAT.\n";
        search($_);
        print $sep.$prompts[rand @prompts];
        next;
    }

    # Lets help them out a bit.
    my $start_time = time;
    my @keywords = ($_ =~ /[^,\s]+/g);
    my @results;

    print "Searching...";
    for $actor (keys %movies) {
        push @results, $actor if match_all($actor, @keywords);       
        spin_loader;
    } 

    my $num_results = scalar @results;
    my $end = time - $start_time;
    print "bam! [$end \bs]\n";

    given ($num_results) {
        when (0) { print "Oops! No suggestions found. You're on your own.\n"; }
        when (1) { print "I hope you meant $results[0]!\n";
                   search($results[0]); } 
        when ([2..40]) { 
            print "Did you mean...\n";
            print "? $_\n" for sort @results;
            print "($num_results partial matches; [$end \bs])\n";
        }
        default { 
            # More than 40 results; give users the option to pipe the results through less.
            print "Number of results is large ($num_results).\n$less_prompt";
            while(<STDIN>) {
                last if /^(y|n)/;
                print $less_prompt;
            } 

            if (/^y/) {
                open LESS, '|-', 'less'; 
                select LESS;
            }

            print "Did you mean...\n";
            print "? $_\n" for sort @results;
            print "($num_results partial matches; [$end \bs])\n";


            if (/^y/) {
                select STDOUT;
                close LESS;
            }
        }
    }

    print $sep.$prompts[rand @prompts];
}


#######################
###  THE BACONATOR  ### 
#######################

# I'm so, so sorry. At least I documented.

    # NESTED ORDER:
    # Previous Queues => Queues (Each queue contains actors with the same Bacon Number)
    # Queue => Arrays of Actors (Each array represents one movie from a parent actor)
    # Array of Actors => Actors
    # Use queue and actor index from array to find parent actor
    # Use movie index from array to find the connection movie


sub search {
    my $start_time = time;
    my $target = shift;
    my $bacon_number = 0;

    # Check for tom-foolery
    if ($target eq "Bacon, Kevin") {
        print "Kevin Bacon: level zero. [0s]\n";
        return;
    }

    # Prepare for adventure
    my ( $queue_index, $actor_index, $movie_index );  # Indices for finding parent actors and connection movies
    my ( %visited_movies, %visited_actors );
    my ( 
        @previous_queues,  # Array of arrays; each array represents a tree level/depth
        @current_queue,    # The current queue of actors to be searched
        @next_queue        # The next tree level/depth of actors to be searched
        );       

    $visited_actors{"Bacon, Kevin"} = 1;

    @current_queue = ( ["I",  # Queue_index [index for the connection movie's array of actors, in the last queue]
                        "dont",             # Actor_index [index for the parent actor, in the last queue]
                        "matter",           # Movie_index [index for the connection movie, in %movies{parent_actor}]
                        "Bacon, Kevin"] );  # All actors for the current connection movie; to be searched through    

    
    # Iteratively go through each actor set, check each actor, and add new actors to the next queue.
    while(@current_queue) {
        print "bacon number = $bacon_number? ";

        $queue_index = -1; # current actor_set
        foreach $actor_set (@current_queue) {
            $queue_index += 1;

            $actor_index = 2; # current actor
            foreach $actor (@$actor_set[3..@$actor_set-1]) { 
                $actor_index += 1;
                spin_loader;

                ### ACTOR FOUND ###
                if ($actor eq $target) {
                    my $end_time = int(time - $start_time);
                    print "YES\nFound! [$end_time \bs]\n";

                    my $temp = $bacon_number;
                    my $current_actor = $actor;

                    $queue_index = $actor_set->[0];
                    $actor_index = $actor_set->[1];
                    $movie_index = $actor_set->[2];

                    # Continuously step back through the queues using the stored indices
                    while ($temp > 0) {
                        my $actors_array = $previous_queues[$temp-1]->[$queue_index];
                        my $parent_actor = $actors_array->[$actor_index];
                        my $connecting_movie = ${$movies{$parent_actor}}[$movie_index];

                        $queue_index = $actors_array->[0];
                        $actor_index = $actors_array->[1];
                        $movie_index = $actors_array->[2];

                        print "$temp: $current_actor and $parent_actor appeared in:\n\t$connecting_movie\n";
                        $current_actor = $parent_actor;
                        $temp -= 1;
                    }

                    print "Wow! A bacon number of $bacon_number. How about that?\n";
                    return;
                } ### END ACTOR FOUND ###
                
                $movie_index = -1;  # current movie
                foreach $movie (@{$movies{$actor}}) {
                    $movie_index += 1;
                    spin_loader;
                    
                    next if exists $visited_movies{$movie};
                    $visited_movies{$movie} = 1;
                    
                    # Add unchecked actors who appeared in the movie
                    # Check for visited actors as soon as possible to avoid saving duplicates to memory
                    my @actor_array = ( $queue_index, $actor_index, $movie_index );
                    
                    foreach $next_actor (@{$actors{$movie}}) {
                        unless (exists $visited_actors{$next_actor}) {
                            push @actor_array, $next_actor; 
                            $visited_actors{$next_actor} = 1;
                        }
                    }

                    push @next_queue, \@actor_array; 
                }
                
            }
        }

        # Rotate Queues and increment bacon number
        push @previous_queues, [@current_queue];
        @current_queue = @next_queue;
        @next_queue = [];
        $bacon_number += 1;
        print "NO\n";
    }

    my $end_time = int(time - $start_time);
    print "Bacon Number not found. Are you a wizard? [$end_time \bs]\n";
}
