#!/usr/bin/perl

use strict;

##
select((select(STDOUT), $|=1)[0]);

##
# Terminal handling set-up
sub select_ne {
    my $str = shift;
    while(defined $str) {
        if(!($str eq "")) {
            return $str;
        }
        $str = shift;
    }
    return "";
}

my $back = select_ne(`tput cub 1`, "\033[1D");
my $civis = `tput civis`;
my $cnorm = `tput cnorm`;
my $normal = `tput sgr0`;
my $fg_red = select_ne(`tput setf 1`, `tput setaf 1`);

##
# Spinner
my @spinner = ("|", "/", "-", "-");
my $spinner_ind = 0;
my $spinner_iter = 0;
sub spinner_update {
    $spinner_iter += 1;
    if($spinner_iter % 16 == 0) {
        print("${back}$spinner[$spinner_ind]");
        $spinner_ind = ($spinner_ind + 1) % 4;
    }
}
sub spinner_reset {
    $spinner_ind = 0;
    $spinner_iter = 0;
}


sub parse_input {
    # Method signature:
    # parse_input $fname, \%actors \%movies
    my $fname = shift;
    my $fhandle = shift;
    my $actors = shift;
    my $movies = shift;
    print("${civis}Loading ${fg_red}$fname${normal}... ");
    
    my $last_actor;
    spinner_reset();
    while(<$fhandle>) {
        if(/.*\t+.*\(\d*\).*/) {
            my @data = split(/\t+/);
            if($data[0] eq "") {
                # This is a continuation of the last actor
                if(!(defined $last_actor)) {
                    print("Error in input: Orphaned movie in dataset\n");
                    print("[\"$data[0]\", \"$data[1]\"]\n");
                    return;
                }
            }else {
                # New actor
                # [ $name, %movies, $distance, $movie_ref ]
                $last_actor = [$data[0], {}, -1, undef];
                $actors->{$data[0]} = $last_actor;
            }
            my $movie;
            if(exists $movies->{$data[1]}) {
                $movie = $movies->{$data[1]};
                $movie->[1]->{$last_actor->[0]} = $last_actor;
            }else {
                # Create the new movie
                # [ $title, %actors, $distance, $actor_ref ]
                $movie = [$data[1], {$data[0]=>$last_actor}, -1, undef ];
                $movies->{$data[1]} = $movie;
            }
            
            $last_actor->[1]->{$data[1]=>$movie};
        }
        spinner_update();
    }
    print("${back}done\n");
}
sub update_refs {
    # Method signature:
    # update_refs \@actor $distance \%actors \%movies
    my $next = [shift];
    my $dist = shift;
    my $actors = shift;
    my $movies = shift;
    my ($titles, $stack);
    
    print("Updating Graph... ");
    spinner_reset();
    # Process our stack, ending when we have no more to consider
    do {
        $stack = $next;
        $next = [];
        while(scalar $stack) {
            # Pop from stack
            my $current = shift $stack;
            $current->[2] = $dist;
            my @titles = (keys %{${$current}[1]});
            for my $title ($titles) {
                # Grab the current movie
                my $cmovie = $movies->{$title};
                
                # Only consider the movie if we haven't already visited it
                # The distance will be -1 if this is true.
                if($cmovie->[2] == -1) {
                    # Update the movie
                    $cmovie->[2] = $dist;
                    $cmovie->[3] = $current;
                    
                    # Grab all actors in this movie, add them to the
                    # next stack if they haven't already been visited
                    for my $actor (values $cmovie->[1]) {
                        if($actor->[2] == -1) {
                            push($next, $actor);
                            # Make sure to build the trail backwards
                            # The actor needs to know which movie put him
                            # on the stack. The specific movie doesn't
                            # matter, so long as the distance is the same,
                            # so we don't care if we overwrite it here.
                            $actor->[3] = $cmovie;
                        }
                    }
                }
                spinner_update();
            }
        }
    }while(scalar $next);
    
    print("\033[1Ddone\n");
}

##
# Start program

my $movies = {};
my $actors = {};


# Time the loading so we can report the time it took to load.
my $start = time;
my $file1 = shift;
#open(my $file1handle, "zcat ${file1} |") or die();
#parse_input($file1, $file1handle, $actors, $movies);

my $file2 = shift;
open(my $file2handle, "zcat ${file1} |") or die();
parse_input($file2, $file2handle, $actors, $movies);
my $dt = time() - $start;

# Generate nice load report.
my $actors_size = scalar keys $actors;
my $movies_size = scalar keys $movies;
print("Read $actors_size actors in $movies_size movies in $dt seconds.\n");

# Bail out if Kevin Bacon isn't in the data set.
if(!(exists $actors->{'Bacon, Kevin'})) {
    die("Kevin Bacon not in dataset.\n");
}

my $bacon = $actors->{'Bacon, Kevin'};
my $bacon_movies = $bacon->[1];

# Do the flood fill
update_refs($bacon, 0, $actors, $movies);
