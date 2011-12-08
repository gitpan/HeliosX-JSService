#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use File::Spec;
use Getopt::Long;
use ExtUtils::Manifest;

use Error qw(:try);
require XML::Simple;

use Helios::Service;

our $VERSION = '0.01_4703';

our $args;				# cmd line args
our $config;			# config from args
our $serviceDesc;		# parsed service description
our $templates;			# templates for module stubs

=head1 NAME

hxjs_make_project.pl - create a project to generate the Perl side of a HeliosX::JSService-based service

=head1 SYNOPSIS

 # create all the Perl boilerplate for a HeliosX::JSService class
 # allowing the developer to focus on JavaScript code
 hxjs_make_project.pl --conf=service_desc.xml

 # just prints version info
 hxjs_make_project.pl --version

=head1 DESCRIPTION

Rather than leave the JavaScript developer to figure out the complexities of 
Perl, Makefiles, and, ExtUtils::MakeMaker on their own, hxjs_make_project.pl 
can be used to setup all of the Perl side of a HeliosX::JSService-based Helios 
service, allowing the JavaScript developer to focus on JavaScript code.  
Developers can create an XML file describing the service class they wish to 
make and any needed CPAN modules, then run this program to create the project 
and all the Perl boilerplate.

=head1 SERVICE DESCRIPTION XML

Here is an example service descriptor for a Helios::JSService called ExampleService:

 <hxjsDescription>
 	<servicename>ExampleService</servicename>
 	<jssource>example.js</jssource>
 	<PerlModules> 
		<module>DBI</module>
		<module>Solr::Client</module>
 	</PerlModules>
 	<bindVariables>
 		<object>
			<jsvar>DBI</jsvar>
			<perlvar>DBI</perlvar>
		</object>
		<object>
			<jsvar>SolrClient</jsvar>
			<perlvar>Solr::Client</perlvar>
		</object>
 	</bindVariables>

 </hxjsDescription>

Several points: (expand on this before production!) #[]

=over 4

=item *

The whole service description should be wrapped in a <hxjsDescription> block.  

=item *

<servicename> is the name of the Perl class and thus, the service's name as it 
will appear in your Helios collective.

=item * 

<jssource> is the name of the main JavaScript source file for your service

=item *

The <PerlModules> section lists the name of all of the Perl modules your 
JavaScript service will need access to.  The generated Perl will load the 
modules listed here for you. 

=item * 

The <bindVariables> section lists the Perl-side variables that your JavaScript 
code will need access to.  #[] woefully inadequate documentation here!

=back

=cut

# main prog

# parse cmdline input
$args = parseArgs(@ARGV);

# parse some config
$serviceDesc = parseServiceConfig($args->{conf});

# read stub templates
$templates = parseTemplates();

# replace vars in template to create stub
my $modstub = createModuleStub($serviceDesc, $templates);
say $modstub;

# derive project paths
my $projectdir = $serviceDesc->{servicename};
$projectdir =~ s/::/\-/g;
my @nameparts = split(/::/,$serviceDesc->{servicename});
my $modname = pop @nameparts;
my $modfullpath = File::Spec->catfile(($projectdir,'lib', @nameparts), $modname.'.pm');
say $modfullpath;
my $jsdir = File::Spec->catdir($projectdir,'js');
my $jsfullpath = File::Spec->catfile($projectdir,'js',$serviceDesc->{jssource});
say $jsfullpath;

# create MakeMaker project
createMakeMakerProject($serviceDesc->{servicename});

# write Perl module stub
writeModuleStub($modstub, $modfullpath);

# write JS source stub
writeJSStub($templates->{JS}, $jsdir, $jsfullpath);

#? update manifest
my $oridir = File::Spec->curdir();
chdir($projectdir);
ExtUtils::Manifest->mkmanifest();
chdir($oridir);

say "Project for Helios service ".$serviceDesc->{servicename}.' created.';


=head1 FUNCTIONS

=head2 parseArgs()

=cut

sub parseArgs {
	my $conf;
	GetOptions(
		"conf=s" => \$conf,
	);
	
	return {'conf' => $conf};
}


=head2 parseServiceConfig()

=cut

sub parseServiceConfig {
	my $conf = shift;
	my $xs = XML::Simple->new(ForceArray => ['module', 'object', 'value'] );
	my $c = $xs->XMLin($conf);
	my $d;
	$d->{jssource}    = $c->{jssource};
	$d->{servicename} = $c->{servicename};
	$d->{modules}     = $c->{PerlModules}->{module};
	$d->{bindObjects} = $c->{bindVariables}->{object};
	$d->{bindValues}  = $c->{bindVariables}->{values};
	return $d;
}


=head2 parseTemplates

=cut

sub parseTemplates {
	my $t;
	my %tmpls;
	while(<DATA>) { $t .= $_; }		
	my @ts = split(/____________________/, $t);
	$tmpls{MODULE} = $ts[0];
	$tmpls{CJSC} = $ts[1];
	$tmpls{JS} = $ts[2];
	return \%tmpls;		
}


=head2 createModuleStub(SERVICENAME => $servicename, SCRIPTNAME => $scriptname)

=cut

sub createModuleStub {
	my $sd = shift;
	my $tmpls = shift;

	my $servicename = $sd->{servicename};
	my $jssource = $sd->{jssource};
	my $modules = $sd->{modules};
	
	my $t = $tmpls->{MODULE};
	my $cjsc = createCJSC($sd, $tmpls);

	# create module use statements
	my $usestmts;
	foreach (@$modules) {
		$usestmts .= 'use '.$_.";\n";
	}
	
	# fill in template
	$t =~ s/<SERVICENAME>/$servicename/g;
	$t =~ s/<SCRIPTNAME>/$jssource/g;
	$t =~ s/<USEPACKAGES>/$usestmts/g;
	$t =~ s/<CONFIGUREJSCONTEXT>/$cjsc/g;
	
	return $t;
}


=head2 createCJSC

=cut

sub createCJSC {
	my $sd = shift;
	my $tmpls = shift;
	my $tmpl = $tmpls->{CJSC};
	# bind values
	my $bindVars;
	foreach ( @{ $sd->{bindValues} } ) {
		my $s = '$ctx->bind_value(\'';
		$s .= $_->{jsvar};
		$s .= '\' => ';
		$s .= $_->{perlvar};
		$s .= ");\n";
		$bindVars .= $s;
	}
	# bind objects
	foreach ( @{ $sd->{bindObjects} } ) {
		my $s = '$ctx->bind_object(\'';
		$s .= $_->{jsvar};
		$s .= '\' => ';
		$s .= $_->{perlvar};
		$s .= ");\n";
		$bindVars .= $s;
	}
	$tmpl =~ s/\<BINDVARS\>/$bindVars/g;
	return $tmpl;
}


=head2 createMakeMakerProject($servicename)

=cut

sub createMakeMakerProject {
	my $servicename = shift;
	my @sysargs = ('h2xs','-XA',$servicename);
	my $es = system(@sysargs);
	if ($es) { throw Error::Simple($!); }
	return 1;	
}


=head2 writeModuleStub

=cut

sub writeModuleStub {
	my $modstub = shift;
	my $modfullpath = shift;	
	
	open(my $fh, '>', $modfullpath) or throw Error::Simple($!);
	print $fh $modstub;
	close($fh);
	
	return 1;
}


=head2 writeJSStub 

=cut

sub writeJSStub {
	my $js = shift;
	my $jsdir = shift;
	my $jsfullpath = shift;

	mkdir($jsdir) or throw Error::Simple($!);

	open(my $fh, '>', $jsfullpath) or throw Error::Simple($!);
	print $fh $js;
	close($fh);
	
	return 1;
}


1;

=head1 AUTHOR

Andrew Johnson, E<lt>lajandy at cpan dot orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Andrew Johnson

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut



__DATA__
package <SERVICENAME>;
use parent qw(HeliosX::JSService);
<USEPACKAGES>

sub JSSource { '<SCRIPTNAME>' };


<CONFIGUREJSCONTEXT>

1;

____________________


sub configureJSContext {
	my $self = shift;
	my %params = @_;
	my $ctx = $params{CONTEXT};

	<BINDVARS>

	return $ctx;
}

____________________

/*  This is the main JavaScript source file for your service
    The following Helios objects and variables are available to you:

    HeliosService  the current service (object)
    HeliosJob      the current job (object)
    HeliosJobArg   a hash with the arguments of the current job
    HeliosConfig   a hash with the configuration for the current service
                   
    As with Helios services in Perl, the last statement in your service
    should mark the job as completed or failed
    
    HeliosService.completedJob(Job);
    OR
    HeliosService.failedJob(Job,'error message')
    
 */
 
 
HeliosService.completedJob(Job);

