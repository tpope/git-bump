* I'm the commit message guy, so you sure as shooting better have a [well
  formatted commit message][] if you're submitting a patch.

* Don't be shy about submitting bugs, especially those of the form, "I did
  something wrong, but rather than getting a helpful error message, I got a
  Ruby stack trace."

* I'm open to supporting alternative conventions (e.g. omitting the `v` from
  the tag), but this should generally be achieved by automatic detection
  rather than command line arguments or configuration.

* I'd love to make it possible to install as a standalone script.  The main
  impediment to this is the dependence on Thor.

[well formatted commit message]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
