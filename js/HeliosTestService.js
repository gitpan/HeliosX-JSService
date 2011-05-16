/*  This is a rough equivalent to Helios::TestService, but in JS
    All we do is log the job arguments and mark the job as completed

    HeliosX::JSService sets up the standard Helios variables for you
    Service = Perl $self (the current service object)
    Job     = Perl $job (the current job object)
    It also provides a few more for convenience:
    Args    = Perl $args (a hash with the arguments of the current job)
    Config  = Perl $config (a hash with the configuration for the 
              current service)
 */

  
    // log each of the job's arguments in the logging system
    for (var key in Args) {
        Service.logMsg(Job, "Argname: " + key + " Value: " + Args[key]);
    }

    // mark the job as completed
    Service.completedJob(Job);

    // done!


