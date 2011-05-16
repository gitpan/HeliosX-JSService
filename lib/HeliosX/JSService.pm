package HeliosX::JSService;

use 5.010;
use strict;
use warnings;
use parent qw(Helios::Service);
use File::Spec;

use Error qw(:try);
use JSPL;

use Helios::Error;
use Helios::LogEntry::Levels qw(:all);

our $VERSION = '0.01_1973';


=head1 NAME

HeliosX::JSService - Helios service base class to allow Helios services
written in JavaScript

=head1 SYNOPSIS

  In a Perl .pm file:
  # create a Perl stub for your JavaScript service
  package HeliosX::JSTestService;
  use parent qw(HeliosX::JSService);
  sub JSSource { '/path/to/script.js' };
  1;


  In a JavaScript .js file:
  // this is a rough equivalent to Helios::TestService, but in JS
  // all we do is log the job arguments and mark the job as completed
  
  // log each of the job's arguments in the logging system
  for (var key in Args) {
      Service.logMsg(Job, "Argname: " + key + " Value: " + Args[key]);
  }
  
  // mark the job as completed
  Service.completedJob(Job);


  On the command line, use the typical helios.pl service daemon start cmd:
  helios.pl HeliosApp::MyService


=head1 DESCRIPTION

HeliosX::JSService allows a developer to write Helios services in 
JavaScript.  By using the Mozilla Spidermonkey JavaScript engine and the 
JSPL Perl/Spidermonkey glue library, HeliosX::JSService can allow the 
JavaScript developer access to a huge portion of the vast Perl CPAN 
library from the JavaScript language with which they are familiar.  By 
allowing this access from the Helios environment, JavaScript developers 
now have access to this vast array of libraries inside a distributed, 
asynchronous processing environment.

#[] need more info here, it's still a development version


=head1 CONFIGURATION PARAMETERS

=head2 js_src_path

The path to your JavaScript source files.  If specified, your Helios 
service class will attempt to locate your .js files in that location.  
It is highly recommended you set this parameter in the [global] section 
of your helios.ini file so you can place all of your .js files in the 
same location.  Otherwise, you will need to set js_src_path for each 
service you create in the Panoptes Ctrl Panel, or specify a full path in
each of your service classes' JSSource() method.

=head1 METHODS YOU ARE LOOKING FOR

One or more of the following methods need to appear in the Perl stub 
for your Helios service.  The required JSSource() method tells Helios 
which JavaScript source file to load and run, while the optional 
configureJSContext() can be used to configure other Perl/CPAN libraries 
for use by your JavaScript code.

=head2 JSSource() REQUIRED

This is the only method you normally need to worry about in your Perl 
module stub.  It tells the Helios service instance the location of the 
JavaScript source file to load and run.

The Perl stub module for your Helios service can be as short as the 
following 4 statements:

  package HeliosApp::MyService;
  use parent qw(HeliosX::JSService);
  sub JSSource { '/path/to/script.js' };
  1;

(Don't worry about use strict, use warnings, etc.  They will be taken 
care of for you.)

So if you wanted to write a service called HeliosApp::IndexerService 
whose code you would put in the /usr/local/lib/js/IndexerService.js file,
your Perl stub would look like:

  package HeliosApp::IndexerService;
  use parent qw(HeliosX::JSService);
  sub JSSource { '/usr/local/lib/js/IndexerService.js' };
  1;

If you set the "js_src_path" configuration parameter to "/usr/local/lib/js" 
in the [global] section of your helios.ini, then your Perl stub would be
reduced:

  package HeliosApp::IndexerService;
  use parent qw(HeliosX::JSService);
  sub JSSource { 'IndexerService.js' };
  1;

Helios would automatically look in /usr/local/lib/js for any .js file, so 
the full path is no longer necessary in JSSource().


=cut

sub JSSource { return undef; }

=head2 configureJSContext(%params)

The configureJSContext() method allows the Helios JavaScript developer 
access to the JavaScript context created by Helios and JSPL (the glue 
module between the Perl interpreter and the Mozilla Spidermonkey 
JavaScript engine).  While HeliosX::JSService provides the JavaScript 
context with access to the necessary Helios objects and variables, the 
developer needing access to other CPAN modules such as DBI will need to 
override this method and add Perl code to bind the needed classes into 
the JSPL context.

#[] need more docs here: what's given and what needs to happen to get it 
working

See L<JSPL::Controller> for more information on binding Perl classes into 
your JSPL context.

=cut

sub configureJSContext {
	my $self = shift;
	my %params = @_;
	return $params{CONTEXT};
}

=head1 METHODS YOU ARE NOT LOOKING FOR

The following methods work behind the scenes to setup the Helios 
service instance and initialize the Spidermonkey JS context.  Unless you 
are trying to muck about extending HeliosX::JSService itself, you 
shouldn't need to pay attention to these.  JavaScript developer, these 
are not the methods you are looking for...

=head2 run($job)

This is the typical run() method required by all Helios service classes.  
It actually doesn't do anything special from a Perl or Helios perspective:  
it sets up parameters, calls some methods, catches some errors.

=cut

sub run {
	my $self = shift;
	my $job = shift;
	my $config = $self->getConfig();
	my $args = $self->getJobArgs($job);

	try {
		# setup JavaScript context
		my $ctx = $self->createJSContext(CONFIG => $config, ARGS => $args, JOB => $job);
		my $js = $self->getJS();

		$ctx->eval($js);		

	} catch Helios::Error::Warning with {
		my $e = shift;
		$self->logMsg($job, LOG_WARNING, "WARNING: ".$e->text);
		$self->completedJob($job);
	} catch Helios::Error::Fatal with {
		my $e = shift;
		$self->logMsg($job, LOG_ERR, "FAILED: ".$e->text);
		$self->failedJob($job, $e->text);
	} otherwise {
		my $e = shift;
		$self->logMsg($job, LOG_ERR, "FAILED with unexpected error: ".$e->text);
		$self->failedJob($job, $e->text);
	};

}


=head2 getJS()

This method determines where the JavaScript source file is located,  
loads it into memory, and returns it to the calling routine (most likely 
the run() method).

The getJS() method will look for the .js file in the location defined by
the "js_src_path" config parameter, if it is defined.

=cut

sub getJS {
	my $self = shift;
	my $config = $self->getConfig();
	my $js;

	# read in the JavaScript source
	my $js_file = File::Spec->catfile($config->{js_src_path}, $self->JSSource());
	{
		local $/ = undef;
		open(my $fh, "<", $js_file) or throw Helios::Error::Fatal("Source file '".$js_file."' not found");
		$js = <$fh>;
		close($fh);
	}
	return $js;
}


=head2 createJSContext(%params)

Given a set of Helios-relevant variables, createJSContext() actually 
creates the JSPL JavaScript context, makes the Helios variables available 
by binding them to JavaScript variables in the JSPL context, and then 
calls the configureJSContext() method for any further configuration, 
returning the resulting context to the calling routine.

The %params variable includes the typical Helios information:
  CONFIG  the service class configuration (hashref)
  JOB     the current job to be processed (Helios::Job object)
  ARGS    the current job's arguments (hashref)

This method is phase 1 of a two phase JSPL context creation process.  
Splitting context creation into two methods allows the service developer 
access to the JSPL context without dumping the whole thing in their lap.

=cut

sub createJSContext {
	my $self = shift;
	my %params = @_;

	my $ctx = JSPL->stock_context();
	$ctx->bind_value('Config' => $params{CONFIG});
	$ctx->bind_value('Args' => $params{ARGS});
	$ctx->bind_object('Service' => $self);
	$ctx->bind_object('Job' => $params{JOB});

	$params{CONTEXT} = $ctx;

	return $self->configureJSContext(%params);
}



1;
__END__


=head1 SEE ALSO

L<Helios>, L<JSPL>, L<JSPL::Controller>

=head1 AUTHOR

Andrew Johnson, E<lt>lajandy at cpan dot orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Andrew Johnson

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
