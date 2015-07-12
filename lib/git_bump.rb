# encoding: utf-8

require 'thor'

class GitBump < Thor

  INITIAL = <<-EOS
Looks like this is your first release.  Please add the version number to the
work tree (e.g., in your Makefile), stage your changes, and run git bump again.

If this isn't your first release, tag your most recent prior release so that
git bump can find it:

        git tag -s v1.2.3 8675309
  EOS

  def self.start
    ARGV.unshift('release') if ARGV.first =~ /^v?\d/ || %w(major minor point).include?(ARGV.first)
    super
  end

  class Release
    attr_reader :tag, :sha1, :name, :version

    def initialize(tag, sha1, name, version)
      @tag, @sha1, @name, @version = tag, sha1, name, Version.new(version)
    end

    def tag_type
      @tag_type ||= %x{git cat-file -t #{tag}}.chomp
    end

    def tag_message
      if tag_type == 'tag'
        @tag_message ||= %x{git cat-file tag #{tag}}.split("\n\n", 2).last
      end
    end

    def tag_signed?
      tag_message.to_s.include?("\n-----BEGIN PGP")
    end

    def tag_body?
      tag_message.to_s.sub(/\n-----BEGIN PGP.*/m, '').include?("\n\n")
    end

    def body
      @body ||= %x{git log -1 --pretty=format:%b #{sha1}}
    end

    def format
      body[/(?:\n  |.)*/].sub(/\A([-* ]*)(.*?)(\.?)\z/m, '\1%s\3') unless body.empty?
    end

    def inverse_diff(context = 1)
      unless defined?(@inverse_diff)
        @inverse_diff =
          if !%x{git rev-parse --verify -q #{sha1}^}.empty?
            %x{git diff -U#{context} #{sha1}..#{sha1}^}
          end
      end
      @inverse_diff
    end

  end

  class Version
    def initialize(string)
      @components = string.split('.')
    end

    def to_s
      @components.join('.')
    end

    def to_a
      @components.dup
    end
  end

  no_tasks do
    def releases
      @releases ||=
        begin
          out = %x{git for-each-ref "refs/tags/v[0-9]*" --sort="*committerdate" --format="%(refname:short) %(*objectname) %(subject)"}
          exit 1 unless $?.success?
          out.scan(/^(\S+) (\w+) (.*) (\d\S*)\s*$/).map do |args|
            Release.new(*args)
          end
        end
    end

    def latest
      @latest ||= releases.reverse.detect do |release|
        %x{git merge-base #{release.sha1} HEAD}.chomp == release.sha1
      end
    end

    def increment(pos, components)
      components[pos].sub!(/^(\d+).*/, '\1')
      components[pos].succ!
      (components.size-1).downto(pos+1) do |i|
        if components[i] =~ /^\d/
          components[i] = '0'
        else
          components.delete_at(i)
        end
      end
    end

    def generate_version(request)
      if request =~ /^v?(\d.*)/
        $1
      elsif latest
        components = latest.version.to_s.split('.')
        case request
        when 'major' then increment(0, components)
        when 'minor' then increment(1, components)
        when 'point' then increment(2, components)
        when nil     then components.last.succ!
        else
          abort "Unrecognized version increment #{request}."
        end
        components.join('.')
      else
        abort "Appears to be initial release.  Version number required."
      end
    end

    def name
      if latest
        latest.name
      else
        File.basename(Dir.getwd)
      end
    end

    def patch(version, force = false)
      diff = latest.inverse_diff(force ? 0 : 1)
      return unless diff
      deletion = /^-(.*)(#{Regexp.escape(latest.version.to_s)})(.*)\n/
      patch = diff.gsub(/#{deletion}\+\1(.*)\3\n/) do
        "-#$1#$2#$3\n+#$1#{version}#$3\n"
      end.gsub(/^(@@ -\d+,\d+ \+\d+,)(\d+) @@\n( .*\n)?#{deletion}(?![+-])/) do
        "#$1#{$2.succ} @@\n#$3-#$4#$5#$6\n+#$4#{version}#$6\n "
      end.scan(/^[d@].*\n(?:[^d@].*\n)+/).reject do |v|
        v[0] == ?@ && !v.include?(version)
      end.join.gsub(/^diff.*\n([^+-].*\n)*---.*\n\+\+\+.*\n(\Z|diff)/, '\1')
      patch unless patch =~ /\Aindex.*\Z/
    end

    def logs
      if (releases.size < 2 || latest.format) && !@logs
        @logs = %x{git log --no-merges --reverse --pretty=format:"#{latest.format || '* %s.'}" #{latest.sha1}..}
        abort unless $?.success?
      end
      @logs
    end

    def tag!(name)
      annote = if latest && !latest.tag_signed? then '-a' else '-s' end
      format = if releases.size < 2 || latest.tag_body? then '%B' else '%s' end
      body = %x{git log -1 --pretty=format:#{format}}
      if system('git', 'tag', '-f', annote, name, '-m', body)
        puts <<-EOS
Successfully created #{name}.  If you made a mistake, use `git bump redo` to
try again.  Once you are satisfied with the result, run

        git push origin master #{name}
        EOS
      else
        abort "Tag failed.  Create it by hand or use git reset --soft HEAD^ to try again."
      end
    end

    def system!(*args)
      system(*args)
      abort "Error running Git." unless $?.success?
    end
  end

  def self.basename
    'git bump'
  end

  default_task 'release'
  desc '[version]', 'Create and tag a release for the given version'
  method_options %w(force -f) => :boolean
  def release(request=nil)
    version = generate_version(request)
    unless %x{git rev-parse --verify -q v#{version}}.empty? || options[:force]
      abort "Tag already exists.  If it hasn't been pushed yet, use --force to override."
    end
    initial_commit = %x{git rev-parse --verify -q HEAD}.empty?
    if !initial_commit && %x{git diff HEAD}.empty?
      abort INITIAL unless latest
      failure = "Couldn't patch.  Update the version number in the work tree and try again."
      abort failure unless patch = patch(version, options[:force])
      IO.popen(['git', 'apply', '--unidiff-zero', '--index'], 'w') do |o|
        o.write patch
      end
      abort failure unless $?.success?
      hard = true
    elsif %x{git diff --cached}.empty?
      # TODO: what happens on initial with some unstaged changes?
      abort "Discard or stage your changes."
    end
    require 'tempfile'
    Tempfile.open('git-commit') do |f|
      f.puts [name, version].join(' ')
      f.puts
      f.write logs if latest
      f.flush
      system('git', 'commit', '--file', f.path, '--edit', * initial_commit ? [] : ['--verbose'])
      unless $?.success?
        system('git', 'reset', '-q', '--hard', 'HEAD') if hard
        abort
      end
    end
    tag!("v#{version}")
  end

  desc 'redo', 'amend the previous release and retag'
  method_options %w(force -f) => :boolean
  def redo
    unless %x{git diff}.empty?
      abort "Discard or stage your changes."
    end
    unless latest && latest.sha1 == %x{git rev-parse HEAD}.chomp
      abort "Can only amend the top-most commit."
    end
    system!('git', 'commit', '--amend', '--verbose', '--reset-author')
    tag!(latest.tag)
  end

  desc 'log', 'Show the git log since the last release'
  def log(*args)
    if latest
      exec('git', 'log', "#{latest.sha1}..", *args)
    else
      exec('git', 'log', *args)
    end
  end

  desc 'show [version]', 'Show the most recent or given release'
  method_options :version_only => :boolean
  def show(version = latest ? latest.version.to_s : nil)
    release = releases.detect do |r|
      r.version.to_s == version || r.tag == version
    end
    if release
      if options[:version_only]
        puts release.version
      else
        exec('git', 'log', '-1', '--pretty=format:%B', release.sha1)
      end
    else
      exit 1
    end
  end

  desc 'next', 'Show the version number that would be released'
  def next(specifier = nil)
    puts generate_version(specifier)
  end

  def self.help(shell, *)
    super
    shell.say <<-EOS
With no arguments, git bump defaults to creating a release with the least
significant component of the version number incremented.  For example,
1.2.3-rc4 becomes 1.2.3-rc5, while 6.7 becomes 6.8.  To override, provide a
version number argument, or one of the following keywords:

major: bump the most significant component
minor: bump the second most significant component
point: bump the third most significant component
    EOS
  end
end
