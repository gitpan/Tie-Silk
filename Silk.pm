package Tie::Silk;
# Somewhat Intuitive List Knitter
use Log::Easy qw(:all);
use strict;
our $VERSION = '0.01_01';
require Tie::Hash;
our @ISA = qw(Tie::StdHash);
sub TIEHASH {
  $log->write($tll, "trace: ");
  #$log->write($sll, "ARGS: ", \@_);
  my $class = shift;
  my ( @k, @v, %i, %s );
  my $core = { KEY    => \@k, # keys ordered
	       VALUE  => \@v, # values ordered
	       INDEX  => \%i, # index map of key => value pairs
               STATS  => { SIZE   => -1,
                           #ITER   =>  0,
			 },
	     };
  my $th = bless $core, $class;
  if ( my @init = @_ ) {
    if ( @init % 2 ) {
      $log->write(ERROR, "odd number of elements in a hash assignment");
      push @init, undef;
    }
    my $N = @init / 2;
    $log->write($sll, "N: ", $N);
    for ( my $index = 0; $index < $N; $index++ ) {
      STORE( $th, $init[2*$index] => $init[2*$index+1] );
    }
  }
  #$log->write($sll, "CORE: ", $core );
  return $th;
}

sub _get_key_index {
  $log->write($tll, "trace: ");
  my $th = shift;
  #$log->write($sll, "ARGS: ", \@_ );
  my ( $v, $k, $i) = @$th{qw(VALUE KEY INDEX)};
  my $try = shift;
  $log->write($sll, '$try: ', $try);
  my $key;
  my $index;
  my $integer;
  my $sign;
  $key = $try;
  $key =~ s/^(-)// and $sign = -1;
  $log->write($sll, '$sign: ', $sign);
  if ( $key =~ /^\d+$/ ) {
    $log->write($sll, '# negative integer return the <key> value' );
    # positive integer return the <array> value
    $integer = 1;
    $index = $key; # make sure the index is positive
    $key = exists $k->[$index] ? $k->[$index] : $index;
    $log->write($sll, "RETURN $sign DIGIT: ($try)", $key, ":", $index);
  } else {
    # it is not an integer so we treat it like a hash key
    $index = exists $i->{$key} ? $i->{$key} : $#$k+1;
    $log->write($sll, "RETURN NON-DIGIT: ($try)", $key, ":", $index);
  }

  $log->write($sll, "TRY: ", $try, ", KEY: ", $key, ", INDEX: ", $index, ", SIGN: ", $sign, ", INTEGER: ", $integer );
  return ( $try, $key, $index, $sign, $integer );
}
{
  my $store_neg_key;
  # this is used for the corresponding fetch if you set something like
  # $h{'-foobar'} = 'bazpop' which essentially replaces the hash key
  # `foobar' with the key 'bazbop' and we want it to return the key we
  # just altered like one would expect in perl. This has to be done
  # because when we STORE (ala $h{key}='value')perl actually calls
  # STORE to set the value and then for the return value calls FETCH
  # with the same key. So, $store_neg_key tells FETCH that we are perl
  # is coming back from a STORE to re-FETCH the STORE'd value

  sub STORE     {
    $log->write($tll, "trace: ");
    my $th = shift;
    #$log->write($sll, "ARGS: ", \@_ );
    my ( $v, $k, $i) = @$th{qw(VALUE KEY INDEX)};
    my ( $try, $key, $index, $sign, $integer ) = $th->_get_key_index(shift);
    my $value = shift;
    $log->write($dll, "TRY: ", $try, ", KEY: ", $key, ", INDEX: ", $index, ", SIGN: ", $sign, ", INTEGER: ", $integer, ", VALUE: ", $value );
    my $r;
    if ( $integer ) { # using like an array
      $log->write($sll, "# using like an array");
      if ( exists $k->[$index] ) { # slot exists and exists $v->[$index] || trouble
        if ( $sign ) { # manipulating hash key
          $log->write($sll, "# manipulating hash key");
          $key = $value;
          if ( $key =~ /^\d+$/ ) {
            #cannot use digits as hash keys, unless it is the same index as the next open slot
            unless( $key eq $th->{STATS}{SIZE} ) {
              $log->write(CRIT, ref $th, " cannot use digits as hash keys - TRY:KEY:INDEX:OLD_KEY == ", $try, ":", $key, ":", $index, ":", $k->[$index] );
              return undef;
            }
          }
          #$log->write($sll, "CORE: n:$index ", $th );
          if ( exists $i->{$key} ) {
            $log->write(CRIT, ref $th, " AMBIGUOUS KEY ASSIGNMENT: overwriting an old key with a new key, but the name for the new key already exists, which existing value am I supposed to use? - TRY:KEY:INDEX:OLD_KEY == ", $try, ":", $key, ":", $index, ":", $k->[$index] );
          }
          $i->{$value} = delete $i->{$k->[$index]};
          # in this case do I want to return the hash key or the data value?
          # I guess the hash key makes sense, because this is what would be returned from a fetch with a negative integer
          $r = $k->[$index] = $key;
          #$log->write($sll, "CORE: ", $th );
        } else { # manipulating value
          $log->write($sll, "# manipulating value");
          $r = $v->[$index] = $value;
        }
        undef $try;
      }
    } elsif ( exists $i->{$key} ) { # slot exists simple hash key usage
      $log->write($sll, "# slot exists simple hash key usage");
      undef $try;
      if ( $sign ) {
        $r = $k->[$index] = $value;
        delete $i->{$key};
        $i->{$value} = $index;
        $store_neg_key = "-$index";
      } else {
        $r = $v->[$index] = $value;
      }
    }
    if ( $try ) { # create new slot
      if ( $key =~ /^\d+$/ ) { #cannot use digits as hash keys
        $log->write(CRIT, "cannot use digits as hash keys - TRY:KEY:INDEX:VALUE == ", $try, ":", $key, ":", $index, ":", $value );
        return undef;
      } else {
        $log->write($sll, "# create new slot");
        $k->[$index] = $key;
        $v->[$index] = $value;
        $i->{$key} = $index;
        $th->{STATS}{SIZE}++;
      }
    }
    $log->write($sll, "RETURN: ", $r );
    return $r;
  }
  
  sub FETCH     {
    #my $sll = $sll;
    $log->write($sll, "trace: ");
    my $th = shift;
    $log->write($sll, "ARGS:", \@_);
    my ( $v, $k, $i) = @$th{qw(VALUE KEY INDEX)};
    if ( $store_neg_key ) {
      unshift @_, $store_neg_key;
      $store_neg_key = undef;
    }
    my ( $try, $key, $index, $sign, $integer ) = $th->_get_key_index(shift);
    $log->write($sll, "KEY: ", $key );
    $log->write($sll, "CORE: ", $th );
    my $r;
    if ( $integer ) { # using like an array
      $log->write($sll, "# using like an array");
      if ( $sign ) { # fetching hash key
        $r = $k->[$index];
        $log->write($sll, "# fetching hash key: $r, ");
      } else { # fetching value
        $r = $v->[$index];
        $log->write($sll, "# fetching value: $r");
      }
    } elsif ( exists $i->{$key} ) { # slot exists simple hash key usage
      $log->write($sll, "# using like a hash $key");
      if ( $sign ) { # the user wants the index of the data at location $key
        $r = $i->{$key};
        $log->write($sll, "# fetching key index: $r");
      } else {
        $r = $v->[$index];
        $log->write($sll, "# slot exists simple hash key usage: $r", $r);
      }
    }
    #$log->write($sll, "CORE: ", $th );
    $log->write($sll, "( \$try=`$try', \$value=`$r', \$key=`$key', \$index=`$index', \$sign=`$sign', \$integer=`$integer' )" );
    return $r;
  }
}
{
  sub FIRSTKEY {
    $log->write($sll, "trace: ");
    my $th = shift;
    my ( $v, $k, $i) = @$th{qw(VALUE KEY INDEX)};
#    $log->write($sll, '($v->[0], $k->[0]): ', "($v->[0], $k->[0])");
    ($v->[0], $k->[0]);
  }
  sub NEXTKEY {
    $log->write($sll, "trace: ");
    my $th = shift;
    #$log->write($sll, ": th : ", $th );
    #$log->write($sll, ":", \@_ );
    my $lastkey = shift;
    #$log->write($dll, ": lastkey = `$lastkey'" );
    my $n = $th->FETCH("-$lastkey");
    #$log->write($dll, ": lastkey index = `$n'" );
    $n++;
    #$log->write($dll, ": nextkey index = `$n'" );
    #$n = $th->FETCH("-$i");
    #$log->write($sll, ": nextkey = `", $th->FETCH("-$n"), "'" );
    $log->write($sll, ": nextkey index = `$n'" );
    my ( $v, $k, $i) = @$th{qw(VALUE KEY INDEX)};
    #$log->write($sll, ": (lastkey=$lastkey) returning nextkey = `$n' (\$v->[$n], \$k->[$n]) = (", $v->[$n],", ", $k->[$n],")");
    #$log->write($dll, "(\$v->[$n], \$k->[$n]): ", "($v->[$n], $k->[$n])");
    ($v->[$n], $k->[$n]);
  }
}

sub EXISTS {
  $log->write($tll, "trace: ");
  my $th = shift;
  my ( $v, $k, $i) = @$th{qw(VALUE KEY INDEX)};
  my ( $try, $key, $index, $sign, $integer ) = $th->_get_key_index(shift);
  $log->write($sll, "EXISTS KEY? $key(", $index||'', "):", $k->[$index]||'', ":", $i->{$key}||'', ":\n");
  exists $k->[$index] if defined $index;
}

sub DELETE    {
  $log->write($tll, "trace: ");
  my $th = shift;
  my ( $v, $k, $i) = @$th{qw(VALUE KEY INDEX)};
  my ( $try, $key, $index, $sign, $integer ) = $th->_get_key_index(shift);
  my $r;
  if ( exists $i->{$key} ) {
    $r = $v->[$index];
    $log->write($sll, "EXISTS KEY? $key(", $index, "):", $k->[$index], ":", $i->{$key}, ":\n");
    @$k = ( @$k[0 .. $index-1], @$k[$index+1 .. $#$k] );
    @$v = ( @$v[0 .. $index-1], @$v[$index+1 .. $#$v] );
    delete $i->{$key};
    $th->{STATS}{SIZE}--;
  }
  return $r;
}

sub CLEAR     {
  $log->write($tll, "trace: ");
  my $th = shift;
  #$log->write($sll, ": ", \@_ );
  @$th{qw(VALUE KEY INDEX STATS )} = ([], [], {}, {});
  return;
}

1;
__END__
=head1 NAME

Tie::Silk - Somewhat Intuitive List Knitter

=head1 SYNOPSIS

  use Tie::Silk;
  tie %h, 'Tie::Silk';

=head1 DESCRIPTION

 I wrote this module in order to manage several related lists that
were keyed off the same hash keys, but which store different data.
Therefore I can manage the available list elements by simply managing
the controlling hash (silk) and the results will cascade to all of the
content lists.

 this is a hash that also acts like a funny array. It preserves order
 like an array(akin to Tie::IxHash), but also has some other specific
 behavior that is described below ( the `===' I am using here to mean
 `equivalent to')
   where $x is an integer $x >= 0
        then $h{$x} === $h{$h{"-$x"}}

 here is a sample hash:
 $th = tie %h, 'Tie::Silk';
 %h = qw( _foo  bar
          _baz  fup
        );

 Tie::Silk; these are the behaviors we are after:
 1) when accessed with a negative number it returns the hash hey for
    the indicated pair(need to be careful with a `minus zero' key
    MUST be a string because perl compiler will convert an unquoted -0 to 0)
      $h{'-0'}   === _foo
      $h{-1}     === _baz

 2)  when accessed with a positive integer it returns the value for
     the associated key pair (same as fetching it with the normal
     hash key, but now we are accessing it with array-like indexing 
     using {} instead of [] notation)
      $h{0}      === bar  === $h{_foo} === $h{$h{'-0'}}
      $h{1}      === fup  === $h{_baz} === $h{$h{-1}}
      $h{_baz}   === fup
      $h{_foo}   === bar
 3) a normal hash key preceded by a `-' (minus sign) returns the
    index of that pair ( except when setting a value this way, see #4)
      $h{-_baz}  === 1
      $h{-_foo}  === 0

 4) when setting an element and preceding the hash key with a minus
    sign `-' this actually replaces the hash key with the value
    therefore we have:
      $h{-_foo}  = '_new_foo' === $h{'-0'}
      $h{_new_foo}  === bar
      $h{-_new_foo} === 0
      $h{'-0'}      === _new_foo


 5) you cannot set a new slot with an integer unless the integer
    matches the next open slot, otherwise confusion may ensue


=head2 EXPORT

None by default.


=head1 HISTORY

=over 8

=item 0.01

=back

=head1 TODO

  Better documentation, better examples

=back


=head1 AUTHOR

Theo Lengyel, E<lt>theo@taowebs.net<gt>

=head1 SEE ALSO

L<Tie::Strand>
L<perl> L<Tie::IxHash>

=cut
