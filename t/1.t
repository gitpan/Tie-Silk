# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 13*13 + 1;
BEGIN {
  $ENV{BIG_WARN_ON_CRIT} = 0;
  $ENV{BIG_WARN_ON_ERROR} = 0;
}
BEGIN { use_ok('Log::Easy') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use Log::Easy qw(:all);
$log->prefix('');
my $test_log = new Log::Easy;
$test_log->handle_fatals(0);
$test_log->log_file("/dev/null") unless $ENV{TEST_SHOW_LOG_OUTPUT};
#$test_log->{EVIL} = 1;
my ( $msg, $status );

$log->write(CLEAN, "");
my $log_codes = $test_log->LOG_CODE();
foreach my $set_level ( $log->LOG_LEVELS() ) {
  $test_log->log_level( $set_level );
  foreach my $try_level ( $log->LOG_LEVELS() ) {
    my $set_try = "$set_level:$try_level";
    #$log->write(ALWAYS, "\n\$test_log->write($try_level, \"ACTUAL ATTEMPT::: \", $set_try);");
    ( $msg, $status ) = $test_log->write($try_level, "ACTUAL ATTEMPT::: ", $set_try);
    my ( $_set_level, $_try_level ) = ( $log_codes->{$set_level}, $log_codes->{$try_level} );
    my $expected = ( $_set_level <= $_try_level ) ? 1 : 0;
    $msg =~ s/\n//mg;
    ok( ($expected == $status),  $set_try );
    if (not ($expected == $status)) {
      $log->write(ALWAYS, "TRYING: $set_try ::: $_set_level:$_try_level");
      $log->write(ALWAYS, "GOT: $msg -> STATUS: $status, EXPECTED: $expected");
      $log->write(ALWAYS, " ...");
    }
  }
}
