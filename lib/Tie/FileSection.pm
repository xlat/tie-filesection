package Tie::FileSection;
use strict;
# ABSTRACT: restrict files sequential access using array like boundaries
require Tie::Handle;
our @ISA  = qw( Tie::StdHandle );
our $VERSION = 0.01;

sub new{
	my $pkg = $_[0] eq __PACKAGE__ ? shift : __PACKAGE__ ;
	my %opts = @_;
	my $filename = $opts{filename} or die "filename parameter is mandatory!";
	my $first_line = $opts{first_line} // 0;
	my $last_line = $opts{last_line} // 0;
	open my $FH, '<', $filename or die "** could not open file $filename : $!\n";
	tie *F, $pkg, $FH, $first_line, $last_line;
	return \*F;
}

sub TIEHANDLE{
	my ($pkg, $FH, $first_line, $last_line) = @_;
	my $self = bless { 
			handle      => $FH, 
			first_line  => $first_line,
			last_line   => $last_line,
			init		=> 0,	#lazy read
			curr_line   => 0,
			line_buffer => [],
			tell_buffer => [],
		}, $pkg;
	return $self;
}

sub UNTIE{
	my $fh = $_[0]->{handle};
	undef $_[0];
	close( $fh );
}

sub EOF{
	my $self = shift;
	my $f = $self->{first_line};
	my $l = $self->{last_line};
	if($f>=0 && $l>0 && $f > $l){ #static EOF
		return 1;
	}
	if($f<0 && $l<0 && $l < $f ){ #static EOF
		return 1;
	}
	
	if($f<0 && $l>0){
		return abs($f) + $self->{curr_line} >= $l;
	}
	
	if($self->{init} && 0 <= $l && $l >= $self->{curr_line}){
		return 1;
	}
	
	if(eof( $self->{handle} )){
		#take in account buffer here
		if($l < 0 && scalar(@{$self->{line_buffer}})<abs($l)){
			return 1;
		}
		else{
			#buffer not empty
			return if @{$self->{line_buffer}};
		}
	
		return 1;
	}
	return;
}

sub TELL	{ 
	my $self = shift;
	return tell($self->{handle}) unless $self->{use_buffer};
	return $self->{tell_buffer}[0];
}

sub _readline{
	my $self = shift;
	my $fh   = $self->{handle};
	my $l    = $self->{last_line};
	my $tellbuff = $self->{tell_buffer};
	my $linebuff = $self->{line_buffer};
	unless($self->{init}++){
		my $f    = $self->{first_line};
		if($f > 0){
			my $i = $f;
			while(--$i && defined scalar <$fh>){
			}
		}
		elsif($f < 0){
			#need to read until eof for abs($f) records
			for(1..abs $f){
				push @$tellbuff, tell($fh);
				push @$linebuff, scalar <$fh>;
			}
			$self->{use_buffer}++;
			while(!eof $fh){
				shift @$tellbuff;
				shift @$linebuff;
				push @$tellbuff, tell($fh);				
				push @$linebuff, scalar <$fh>;
			}
		}
		if($f > 0 && $l < 0){
			for(1..abs $l){
				push @$tellbuff, tell($fh);
				push @$linebuff, scalar <$fh>;
			}
			$self->{use_buffer}++;
		}
		if(eof($fh)){
			#add the final pos if requested aftere EOF.
			push @$tellbuff, tell($fh);
		}
		$. = undef;
	}	
	#read one line and return it, take in accound first_line/last_line and buffer
	my $eof = eof($fh);
	my $pos  = tell($fh);
	my $line = $eof ? undef : <$fh>;
	if($self->{use_buffer}){
		unless($eof){
			push @$linebuff, $line;
			push @$tellbuff, $pos;
		}
		elsif($l < 0 && scalar(@$linebuff)<abs($l)){
			return;
		}
		$line = shift @$linebuff;
		shift @$tellbuff unless @$tellbuff == 1; #always keep last pos
	}
	$self->{curr_line}++;
	$. = $self->{curr_line};
	return $line;
}

sub READLINE { 
	my $self = shift;
	return if $self->EOF;	#test basics boundaries
	unless(wantarray){
		return $self->_readline;
	}
	#ARRAY
	my @rows;
	while(defined($_=$self->READLINE)){ 
		push @rows, $_;
	}
	@rows;
}

sub CLOSE   { close($_[0]->{handle}) }
sub FILENO	{ fileno($_[0]->{handle}) }
1;