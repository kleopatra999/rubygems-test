require 'rubygems/version_option'
require 'rubygems/source_index'
require 'rubygems/specification'
require 'rubygems/dependency_installer'
require 'rubygems/user_interaction'
require 'fileutils'
require 'pathname'
require 'rbconfig'
require 'yaml'
require 'open3'

class Gem::TestError < Gem::Exception; end
class Gem::RakeNotFoundError < Gem::Exception; end

class Gem::Commands::TestCommand < Gem::Command
  include Gem::VersionOption
  include Gem::DefaultUserInteraction

  def description
    'Run the tests for a specific gem'
  end

  def arguments
    "GEM: name of gem"
  end
  
  def usage
    "#{program_name} GEM -v VERSION"
  end
  
  def initialize(spec=nil, on_install=false)
    options = { } 

    if spec
      options[:name] = spec.name
      options[:version] = spec.version
    end

    @on_install = on_install

    super 'test', description, options
    add_version_option
  end

  #
  # Retrieve the source index
  #
  def source_index 
    @gsi ||= Gem::SourceIndex.from_gems_in(*Gem::SourceIndex.installed_spec_directories)
  end
 
  #
  # Get the config in our namespace
  #
  def config 
    @config ||= Gem.configuration["test_options"] || { }
  end

  #
  # find a gem given a name and version
  #
  def find_gem(name, version)
    spec = source_index.find_name(name, version).last
    unless spec
      alert_error "Could not find gem #{name} (#{version})"
      raise Gem::GemNotFoundException
    end

    return spec
  end

  #
  # Locate the rakefile for a gem name and version
  #
  def find_rakefile(spec)
    rakefile = File.join(spec.full_gem_path, 'Rakefile')

    unless File.exist?(rakefile)
      alert_error "Couldn't find rakefile -- this gem cannot be tested. Aborting." 
      raise Gem::RakeNotFoundError
    end
  end

  #
  # Locate rake itself, prefer gems version.
  #
  def find_rake
    rake_path = [Gem.bindir, Config::CONFIG["bindir"]].find { |x| File.exist?(File.join(x, "rake")) }

    unless rake_path
      alert_error "Couldn't find rake; rubygems-test will not work without it. Aborting."
      raise Gem::RakeNotFoundError
    end

    return rake_path
  end

  #
  # Install development dependencies for the gem we're about to test.
  #
  def install_dependencies(spec)
    di = Gem::DependencyInstaller.new

    spec.development_dependencies.each do |dep|
      unless source_index.search(dep).last
        if config["install_development_dependencies"]
          say "Installing test dependency #{dep.name} (#{dep.requirement})"
          di.install(dep) 
        else
          if ask_yes_no("Install development dependency #{dep.name} (#{dep.requirement})?")
            say "Installing test dependency #{dep.name} (#{dep.requirement})"
            di.install(dep) 
          else
            alert_error "Failed to install dependencies required to run tests. Aborting."
            raise Gem::TestError
          end
        end
      end
    end
  end
  
  def upload_results(yaml)
    puts yaml
  end

  def gather_results(spec, output, result)
    {
      :arch         => Config::CONFIG["arch"],
      :vendor       => Config::CONFIG["target_vendor"],
      :os           => Config::CONFIG["target_os"],
      :machine_arch => Config::CONFIG["target_cpu"],
      :name         => spec.name,
      :version      => spec.version,
      :result       => result,
      :test_output  => output
    }.to_yaml
  end

  def run_tests(spec, rake_path)
    FileUtils.chdir(spec.full_gem_path)

    path = File.join(rake_path, "rake")
    command = "gemtest"
    output = ""
    exit_status = nil

    if config["use_rake_test"]
      command = "test"
    end

    Open3.popen3(path, command) do |stdin, stdout, stderr, thr|
      loop do
        if stdout.eof? and stderr.eof?
          break
        end

        buf = ""

        handles, _, _ = IO.select([stdout, stderr].reject { |x| x.closed? || x.eof? }, nil, nil, 0.1)

        begin
          handles.each { |io| io.readpartial(10000, buf) } if handles
        rescue EOFError, IOError
          next
        end

        output += buf
        
        print buf
      end

      exit_status = thr.value
    end

    if config["upload_results"] or
        ask_yes_no "Upload these results to rubyforge?"

      upload_results(gather_results(spec, output, exit_status.exitstatus == 0))
    end
      
    if exit_status.exitstatus != 0
      alert_error "Tests did not pass. Examine the output and report it to the author!"
      raise Gem::TestError
    end
  end

  #
  # Execute routine. This is where the magic happens.
  #
  def execute
    begin
      version = options[:version] || Gem::Requirement.default

      (get_all_gem_names rescue [options[:name]]).each do |name|
        spec = find_gem(name, version)

        # we find rake and the rakefile first to eliminate needlessly installing
        # dependencies.
        find_rakefile(spec)
        rake_path = find_rake

        install_dependencies(spec)

        run_tests(spec, rake_path)
      end
    rescue Exception => e 
      if @on_install
        raise e
      else
        terminate_interaction 1
      end
    end
  end
end
