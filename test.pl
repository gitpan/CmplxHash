######################### We start with some black magic to print on failure.

BEGIN { $| = 1; print "1..?\n"; }
END {print "tests not ok\n" unless $loaded;}
use strict;
use Tie::CmplxHash;
use Data::Dumper;
use vars qw($loaded);
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# The variables we use in every test.
my %real = ();  # The real hash.
my %fake = ();  # The fake hash.
my $obj;        # The tie object.
my $ok;         # The result of each test.
my $number = 1; # The test number

# Tie a hash. - 2
$ok = 1;
++$number;
$obj = tie (%fake, 'Tie::CmplxHash', \%real, 1) or undef $ok;
print $ok ? "ok $number\n" : "not ok $number\n";

# Assign a value. - 3
$ok = 1;
++$number;
$fake{test} = [1,'a'];
exists $real{test} or undef $ok;
print $ok ? "ok $number\n" : "not ok $number\n";

# Check the cache. - 4
$ok = 1;
++$number;
$fake{test} = [1,'a'];
defined $obj->{CACHE} or undef $ok;
print $ok ? "ok $number\n" : "not ok $number\n";

# Assign a value. - 5
$ok = 1;
++$number;
$fake{test2} = ['a',1];
exists $real{test2} or undef $ok;
print $ok ? "ok $number\n" : "not ok $number\n";

# Check the cache size. - 6
$ok = 1;
++$number;
$fake{test} = [1,'a'];
$obj->{CREAL} == 1 or undef $ok;
print $ok ? "ok $number\n" : "not ok $number\n";

# Delete the values. - 7
$ok = 1;
++$number;
delete $fake{test};
delete $fake{test2};
!exists $real{test} or undef $ok;
!exists $real{test2} or undef $ok;
print $ok ? "ok $number\n" : "not ok $number\n";


