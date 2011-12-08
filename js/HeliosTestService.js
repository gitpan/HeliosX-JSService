/*  This is a rough equivalent to Helios::TestService, but in JS
    All we do is log the job arguments and mark the job as completed

    HeliosX::JSService sets up the standard Helios variables for you
    HeliosService = Perl $self (the current service object)
    HeliosJob     = Perl $job (the current job object)
    It also provides a few more for convenience:
    HeliosJobArg  = Perl $args (a hash with the arguments of the current job)
    HeliosConfig  = Perl $config (a hash with the configuration for the 
              current service)
 */

  
    // log each of the job's arguments in the logging system
    for (var key in HeliosJobArgs) {
        HeliosService.logMsg(HeliosJob, "Argname: " + key + " Value: " + HeliosJobArgs[key]);
    }

    // mark the job as completed
    HeliosService.completedJob(Job);

    // done!


