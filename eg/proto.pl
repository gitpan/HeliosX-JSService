use 5.010;
require XML::Simple;
use Data::Dumper;


while(<DATA>) { $desc .= $_; }
say $desc;

$xs = XML::Simple->new(ForceArray => ['module', 'object', 'value'], );
$s = $xs->XMLin($desc);

say Dumper($s);


__DATA__


<hxjsDescription>
<servicename>HeliosApp::ExampleService</servicename>
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

