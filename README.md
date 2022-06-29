# ANTs_scripts
Scripts for ANTs calls

A central repository that can be cloned or passed around that will organize my scripts for using ANTs in the Orger lab.

ants_registration.sh is the main script, and will be the one that drives the registrations locally and on htCondor.

ants_registration.sh expects a certain folder hierarchy in order to work correctly:

* myRegistrationFolder
  * commands
  * images
  * refbrain
  * logs
  * registration
  * masks (optional)

ants_registration.sh should be located in *myRegistrationFolder/commands* and should be run from *myRegistrationFolder*
as ./commands/ants_registration.sh. There are three compulsory arguments:

* -f (fixed/template brain)
* -m (image to be transformed)
* -a (antsCall file)

and quite a few other arguments that can be seen by invoking -h.

A second useful file lives in __ht_condor-submitFiles__: *make_submit.sh*

make_submit.sh should also be run from *myRegistrationFolder* and will use the images in the *images* folder as a reference
for making an htCondor submit script. It has two compulsory arguments:

* -f (fixed/template brain)
* -a (antsCall file)

and can also be passed -x (mask) if a mask of the template is necessary.

At the moment, ants_registration.sh supports bridging, but make_submit.sh does not, so auto-generated submit scripts for
bridging registrations is not yet possible, but can be arranged if enough people would like it.

Please feel free to make suggestions and fixes as necessary.
