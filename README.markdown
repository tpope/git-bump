# git bump

Here's a popular set of best practices for doing releases for code bases
stored in Git:

* Update version-related minutiae in the code base.
* Commit with a message like `projectname 1.2.3`.
* Create a signed, annotated tag with the same message with a name like
  `v1.2.3`.

I like these practices.  They're the ones used by Git itself for its own
source code.  You might quibble over details (why is there a `v` at the
beginning of the tag?), but I think this is a place consistency should
outshine bikeshedding.

There's one more practice that I'd like to add:

* Include release notes in the release commit.

This isn't always a good fit, but for smaller projects, I find this to be a
great alternative to maintaining a formal document inside the repository.  You
can easily scrape the information out of the commits later if your needs
change.

I made git bump to encapsulate these practices.

## Installation

Assuming you want to install with your system's Ruby:

    sudo gem install git-bump

## Usage

The primary interface is `git bump`.  Here's how you would use it for a new
project.

### Initial release

Stage the changes needed to create the release (this could be the entire
repository if it's an initial commit), and run `git bump <version>`, where
`<version>` is the version you want to release (try `1.0.0`).  You'll be
greeted with a familiar sight:

    spline-reticulator 1.0.0

    # Please enter the commit message for your changes. Lines starting
    # with '#' will be ignored, and an empty message aborts the commit.

Adjust the project name if necessary, and save and quit the editor.  Your
commit and tag will be created, and you'll be shown instructions for pushing
once you're sure everything is okay.

### Second release

This is where the fun begins.  Stage the changes necessary for release, and
run one of the following commands:

* `git bump` -- bump the rightmost number in the previous version.
* `git bump point` -- bump the third number in the previous version, and
  reset everything afterwards to zero.
* `git bump minor` -- bump the second number in the previous version, and
  reset everything afterwards to zero.
* `git bump major` -- bump the first number in the previous version, and
  reset everything afterwards to zero.
* `git bump <version>` -- bump to an exact version.

The commit message body will be pre-populated with a bulleted list of commit
messages since the previous release.  My practice is to heavily edit this into
a higher level list of changes by discarding worthless messages like typo
fixes and making related commits into a single bullet point.  If you aren't
interested in this practice, delete the body and `git bump` won't bother you
with it again.

### Subsequent releases

On subsequent releases, if no changes are staged, `git bump` will replay the
previous release commit, replacing the appropriate version numbers.  This
works fine as long as your version numbers are committed as literal strings.
If you're doing something more clever like `MAJOR = 1` and `MINOR = 2`, you'll
have to do the edit by hand and stage it.

### Existing projects

You'll need to create one existing release commit and tag in the proper format
by hand, if your project doesn't already have one.  After that you can use
`git bump` normally.
