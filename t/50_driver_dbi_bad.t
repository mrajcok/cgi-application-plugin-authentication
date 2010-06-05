#!/usr/bin/perl
use Test::More;
use Test::Exception;
use lib qw(t);
eval "use DBD::SQLite";
plan skip_all => "DBD::SQLite required for this test" if $@;

plan tests => 4;

use strict;
use warnings;

our $DBNAME = 't/sqlite.db';

unlink $DBNAME if -e $DBNAME;
my $dbh = DBI->connect( "dbi:SQLite:dbname=$DBNAME", "", "" );

$dbh->do(<<"");
CREATE TABLE user (
    name VARCHAR(20),
    password VARCHAR(50)
)

$dbh->do(<<"");
INSERT INTO user VALUES ('user1', '123');

$dbh->do(<<"");
INSERT INTO user VALUES ('user2', 'mQPVY1HNg8SJ2');  # crypt("123", "mQ")

my %options = (
    DRIVER => [
        'DBI',
        DBH         => $dbh,
        TABLE       => 'user',
    ],
    STORE => 'Store::Dummy',
);

{

    package TestAppDriverDBISimple;

    use base qw(TestAppDriver);

    sub setup {
        my $self = shift;
        $self->authen->config(%options);
    }

}

{
    local $options{DRIVER}->[4] = undef;
    throws_ok {TestAppDriverDBISimple->run_authen_tests(
        [ 'authen_username', 'authen_password' ],
        [ 'user1', '123' ],
        [ 'user2', '123' ],
    );}
   qr/Error executing class callback in prerun stage: No TABLE parameter defined/,
   "no TABLE";
}

{
    my @opts = @{$options{DRIVER}};
    local $options{DRIVER} = [@opts, 'COLUMNS', 'bad column'];
    throws_ok {TestAppDriverDBISimple->run_authen_tests(
        [ 'authen_username', 'authen_password' ],
        [ 'user1', '123' ],
        [ 'user2', '123' ],
    );}
   qr/Error executing class callback in prerun stage: COLUMNS must be a hashref/,
   "COLUMNS not a hashref";
}

{
    my @opts = @{$options{DRIVER}};
    local $options{DRIVER} = [@opts, 'CONSTRAINTS', 'bad constraints'];
    throws_ok {TestAppDriverDBISimple->run_authen_tests(
        [ 'authen_username', 'authen_password' ],
        [ 'user1', '123' ],
        [ 'user2', '123' ],
    );}
   qr/Error executing class callback in prerun stage: CONSTRAINTS must be a hashref/,
   "CONSTRAINTS not a hashref";
}

{
    my @opts = @{$options{DRIVER}};
    local $options{DRIVER} = [@opts, 'CONSTRAINTS', '0'];
    throws_ok {TestAppDriverDBISimple->run_authen_tests(
        [ 'authen_username', 'authen_password' ],
        [ 'user1', '123' ],
        [ 'user2', '123' ],
    );}
   qr/Error executing class callback in prerun stage: Failed to prepare SQL statement:  near " "/,
   "DBI syntax error";
}



$dbh->do(<<"");
DROP TABLE user;


undef $dbh;

unlink $DBNAME if -e $DBNAME;



