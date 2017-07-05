use Test::More;
use_ok 'Tie::FileSection';
my $pos_ori = tell(*DATA);

sub getline{ 
	my $fh = shift;
	$_ = <$fh>;
	s/[\r\n]+//r; 
}

my $f = Tie::FileSection->new( file => \*DATA, first_line => 2, use_real_line_nr => 1 );
cmp_ok getline($f), 'eq', 'Line 2', 'section data line 1';
cmp_ok $., '==', 2, 'section line number = 2';
cmp_ok getline($f), 'eq', 'Line 3', 'section data line 2';
cmp_ok $., '==', 3, 'section line number = 3';
undef $f;

seek(*DATA, $pos_ori, 0); #reset DATA filehandle.
$f = Tie::FileSection->new( file => \*DATA, first_line => 2 );
cmp_ok getline($f), 'eq', 'Line 2', 'section data line 1';
cmp_ok $., '==', 1, 'section line number = 1';
cmp_ok getline($f), 'eq', 'Line 3', 'section data line 2';
cmp_ok $., '==', 2, 'section line number = 2';

done_testing( 9 );

__DATA__
Line 1
Line 2
Line 3