require 'rubygems/command'
require 'rubygems/local_remote_options'
require 'rubygems/version_option'
require 'rubygems/package'

class Gem::Commands::SpecificationCommand < Gem::Command

  include Gem::LocalRemoteOptions
  include Gem::VersionOption

  def initialize
    Gem.load_yaml

    super 'specification', 'Display gem specification (in yaml)',
          :domain => :local, :version => Gem::Requirement.default,
          :format => :yaml

    add_version_option('examine')
    add_platform_option
    add_prerelease_option

    add_option('--all', 'Output specifications for all versions of',
               'the gem') do |value, options|
      options[:all] = true
    end

    add_option('--ruby', 'Output ruby format') do |value, options|
      options[:format] = :ruby
    end

    add_option('--yaml', 'Output RUBY format') do |value, options|
      options[:format] = :yaml
    end

    add_option('--marshal', 'Output Marshal format') do |value, options|
      options[:format] = :marshal
    end

    add_local_remote_options
  end

  def arguments # :nodoc:
    <<-ARGS
GEMFILE       name of gem to show the gemspec for
FIELD         name of gemspec field to show
    ARGS
  end

  def defaults_str # :nodoc:
    "--local --version '#{Gem::Requirement.default}' --yaml"
  end

  def usage # :nodoc:
    "#{program_name} [GEMFILE] [FIELD]"
  end

  def execute
    specs = []
    gem = options[:args].shift

    unless gem then
      raise Gem::CommandLineError,
            "Please specify a gem name or file on the command line"
    end

    dep = Gem::Dependency.new gem, options[:version]

    field = get_one_optional_argument

    raise Gem::CommandLineError, "--ruby and FIELD are mutually exclusive" if
      field and options[:format] == :ruby

    if local? then
      if File.exist? gem then
        specs << Gem::Package.new(gem).spec rescue nil
      end

      if specs.empty? then
        specs.push(*dep.matching_specs)
      end
    end

    if remote? then
      if !options[:version] or options[:version].none?
        found = Gem::SpecFetcher.fetcher.fetch dep, false, false,
                                               options[:prerelease]
      else
        # .fetch is super weird. The last true is there so that
        # prerelease gems are included, otherwise the user can never
        # request them.
        found = Gem::SpecFetcher.fetcher.fetch dep, false, false, true
      end

      specs.push(*found.map { |spec,| spec })
    end

    if specs.empty? then
      alert_error "No gem matching '#{dep}' found"
      terminate_interaction 1
    end

    unless options[:all] then
      specs = [specs.sort_by { |s| s.version }.last]
    end

    specs.each do |s|
      s = s.send field if field

      say case options[:format]
          when :ruby then s.to_ruby
          when :marshal then Marshal.dump s
          else s.to_yaml
          end

      say "\n"
    end
  end
end
