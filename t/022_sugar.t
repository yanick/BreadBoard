#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Bread::Board;

{
    package FileLogger;
    use Moose;
    has 'log_file' => (is => 'ro', required => 1);

    package MyApplication;
    use Moose;
    has 'logger' => (is => 'ro', isa => 'FileLogger', required => 1);
}


sub loggers {
    service 'log_file' => "logfile.log";

    service 'logger' => (
        class        => 'FileLogger',
        lifecycle    => 'Singleton',
        dependencies => {
            log_file => depends_on('log_file'),
        }
    );
}

my $c = container 'MyApp';

Bread::Board::set_root_container($c);

is exception { Bread::Board::set_root_container($c) }, undef,
   "setting the root container multiple times works";

is exception { Bread::Board::set_root_container(undef) }, undef,
   "setting the root container to undef works";

container $c => as {
    like exception { Bread::Board::set_root_container(undef) },
         qr/Can't set the root container when we're already in a container/,
         "can't set the root container from inside a container";
};

Bread::Board::set_root_container($c);

loggers(); # reuse baby !!!

service 'application' => (
    class        => 'MyApplication',
    dependencies => {
        logger => depends_on('logger'),
    }
);

my $logger = $c->resolve( service => 'logger' );
isa_ok($logger, 'FileLogger');

is($logger->log_file, 'logfile.log', '... got the right logfile dep');

is($c->fetch('logger/log_file')->service, $c->fetch('log_file'), '... got the right value');
is($c->fetch('logger/log_file')->get, 'logfile.log', '... got the right value');

my $app = $c->resolve( service => 'application' );
isa_ok($app, 'MyApplication');

isa_ok($app->logger, 'FileLogger');
is($app->logger, $logger, '... got the right logger (singleton)');

done_testing;
