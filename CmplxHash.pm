package Tie::CmplxHash;

use strict;
use vars qw($VERSION);
use Storable qw(freeze thaw);
use Carp;

$VERSION = '0.01';

##########################################################
# Copyright (c) 2000 Lorance Stinson lorance@madlinux.cx #
# All rights reserved! No warranty! Use at your own risk!#
# This program is free software; you can redistribute it #
# and/or modify it under the same terms as Perl itself.  #
##########################################################

# Creates a new tied hash object.
sub TIEHASH {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    $self->_init(@_);
    return $self;
}

# Init ourself.
sub _init {
    # Get our data.
    my $self       = shift;
    my $hash       = shift;
    my $cache_size = shift || 0;

    # Make sure we got a hash reference.
    unless ( ref($hash) eq 'HASH' ) {
        croak 'Usage: tie %new_hash, \'Tie::HashArray\', \%old_hash [,CACHE_SIZE]';
    }

    # Make the reference to the original hash.
    $self->{HASH} = $hash;

    # If caching is turned on set everything up.
    if ( $cache_size ) {
        # The size of the cache.
        $self->{CSIZE} = $cache_size;
        # The actual cache.
        $self->{CACHE} = {};
        # How many entries there really are in the cache.
        $self->{CREAL} = 0;
    }
}

# Serialize the data and store it into the original hash.
sub STORE {
    # Get our data.
    my $self  = shift;
    my $key   = shift;
    my $value = shift;

    # Store it in the cache.
    $self->_cache_add($key, $value);
    
    # Serialize the value and store it into the original hash.
    $self->{HASH}->{$key} = freeze $value;
}

# Retrieve the data from the original hash and reconstruct it.
sub FETCH {
    # Get our data.
    my $self  = shift;
    my $key   = shift;
    my $value = shift;

    # Make sure that key exists.
    return unless exists $self->{HASH}->{$key};

    # Check the cache.
    if ( $value = $self->_cache_get($key) ) { return $value }
    
    # Return the deserialize data.
    return thaw($self->{HASH}->{$key});
}

# The only reason I modified this is to deal with caching.
sub DELETE { 
    # Get our data.
    my $self = shift;
    my $key  = shift;

    # Delete the cache entry.
    $self->_cache_delete($key);

    # Delete the key in the original hash.
    delete $self->{HASH}->{$key}
}

# The only reason I modified this is to deal with caching.
sub CLEAR    { 
    # Get our data.
    my $self = shift;

    # Clear the real hash.
    %{$self->{HASH}} = ();

    # Reinit the cache.
    $self->_cache_clear
}

# Standard Tie::Hash routines.
# Nice and slim for speed.  That and I don't feel like reworking them.
sub FIRSTKEY { my $a = scalar keys %{$_[0]->{HASH}}; each %{$_[0]->{HASH}} }
sub NEXTKEY  { each %{$_[0]->{HASH}} }
sub EXISTS   { exists $_[0]->{HASH}->{$_[1]} }

# Add an entry to the cache.
sub _cache_add {
    # Get our data.
    my $self = shift;
    my $key  = shift;
    my $ref  = shift;

    # Make sure caching is on.
    return unless $self->{CSIZE};

    # See if the entry is there.
    if ( exists $self->{CACHE}->{$key} ) {
        # Update it and return.
        $self->{CACHE}->{$key}->[0] = $ref;
        $self->{CACHE}->{$key}->[1] = time;
    }

    # Add the entry.
    $self->{CACHE}->{$key} = [$ref,time];

    # Update the real count.
    $self->{CREAL}++;

    # Make sure we don't overflow.
    if ( $self->{CREAL} > $self->{CSIZE} ) {
        # Get a sorted list of keys based on time.
        my @sorted =
            map { $_->[0] }
            sort { $a->[1] <=> $b->[1] }
            map { [$_, $self->{CACHE}->{$_}->[1]] }
            keys %{$self->{CACHE}};

        # Delete the last used cache entry and fix the real size.
        delete $self->{CACHE}->{$sorted[-1]};
        --$self->{CREAL};
    }
}

# Clears the cache.
sub _cache_clear {
    # Get our data.
    my $self = shift;

    # Make sure caching is on.
    return unless $self->{CSIZE};

    # Reinit CACHE and CREAL.
    $self->{CACHE} = {};
    $self->{CREAL} = 0;
}

# Delete an entry from the cache.
sub _cache_delete {
    # Get our data.
    my $self = shift;
    my $key  = shift;

    # Make sure caching is on.
    return unless $self->{CSIZE};

    # See if the entry is there.
    if ( exists $self->{CACHE}->{$key} ) {
        # Delete the entry and fix the real size.
        delete $self->{CACHE}->{$key};
        --$self->{CREAL};
    }
}

# Get an entry from the cache.
sub _cache_get {
    # Get our data.
    my $self = shift;
    my $key  = shift;
    my $ref;

    # Make sure caching is on.
    return unless $self->{CSIZE};

    # See if the entry is there.
    if ( exists $self->{CACHE}->{$key} ) {
        # Update it and return.
        $self->{CACHE}->{$key}->[1] = time;
        return $self->{CACHE}->{$key}->[0];
    }
    return;
}

1;
__END__

=head1 NAME

Tie::HashArray - Allows arays to be stored inside a hash.

=head1 SYNOPSIS

  use Tie::CmplxHash;
  tie %newhash, \%oldhash [, CACHE_SIZE]; # Create the new hash object.
  $newhash{key} = $arrayref; # Store the array into the hash.
  $arrayref = $newhash{key}; # Get the array from the hash.

=head1 REQUIRES

Perl 5.004, Storable, Carp

=head1 DESCRIPTION

This module uses the Storable module to serialize/deserialize data and store/fetch it from the original hash.

All operations are performed on references.  This means that the original hash can be any hash (DBM, regular hash or even another Tie module).  It also means that it can store not only arrays but anything you want (though if you need to store anything much more complex than an array I sugest finding a better solution).

The main intent for this module is to store more complex data structures into DBM files.  DBM's are wonderful for small to medium amounts of data.  But when complex data structures are needed it can get hairy.  And there are times when a RDBMS is just a little much.  So this module extends the middle ground that DBM files cover just a little bit more.

=head1 CACHE

Yes you heard me right, cache.  I have implemented a small, no frills, cache to speed things up a little.  When working with large data structures or just a lot of data things can get a little slow.  So if CACH_SIZE is specified caching is turned on and the last CACHE_SIZE keys that are accessed are kept in memory.

All that is actually stored is te reference.  This will keep Perls garbage collector from freeing that memory (at least I hope it alwayse works that way) so it stays available.

When deciding wether to use cachin or not keep in mind that caching can actually do more harm than good.  It all depends on how you use the data.  If you do more reads than writes caching may help.  But if you do more writes than reads it will definitely harm you. Play with CACHE_SIZE and see what results you get.

=head1 WARNING

DO NOT MODIFY THE ORIGINAL HASH.  Unless you know what you are doing, once you start using this module on a hash DO NOT touch it directly.  In fact only use this module on a brand new fresh hash.  All kinds of nasty stuff could occure.  Stuff that I don't know how or fell like checking for.  This is not a end all do all module, it is a tool.  If used properly it can help out a lot, just like any other tool.  And if use improperly it can cause BIG headaches, just like any other tool.

As mentioned in the code and below.  There is no waranty at all.  I am not responsable for what you do with this tool.  If important data is destroyed it's your problem, not mine.  I warned you.

=head1 INSTALLATION

The same as all CPAN modules.

perl Makefile.PL

make

make test

make install

=head1 AUTHOR

Lorance Stinson, lorance@madlinux.cx

=head1 COPYRIGHT and LISCENSE

##########################################################
# Copyright (c) 2000 Lorance Stinson lorance@madlinux.cx #
# All rights reserved! No warranty! Use at your own risk!#
# This program is free software; you can redistribute it #
# and/or modify it under the same terms as Perl itself.  #
##########################################################

=head1 SEE ALSO

perl(1).
perlref(1).
perlreftut(1).


=cut
