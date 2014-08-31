require 'kitchenplan'

class Kitchenplan
  class Application
    attr_accessor :options, :platform, :config
    include Kitchenplan::Mixin::Display
    include Kitchenplan::Mixin::Commands
    include Kitchenplan::Mixin::Optparse
    # Main point of entry for kitchenplan binary.  #run starts the app.
    def initialize
      super
      configure_logging
      detect_platform()
      load_config()
    end
    # Ensure that we can gracefully and quickly terminate.  People love that.
    def trap_signals
      trap("TERM") do
	self.fatal!("TERM received",1)
      end

      trap("INT") do
	self.fatal!("Interrupt signal received.", 2)
      end
    end
    def detect_platform
      self.platform = eval("Kitchenplan::Platform::#{Kitchenplan::Platform.constants.first.to_s}.new()") unless defined?(self.platform) and self.platform.nil? == false
    end
    # set up the admittedly Chef-style logger facility
    # Except that we don't log anywhere but STDOUT right now.
    def configure_logging(loglevel=:debug)
      Kitchenplan::Log.init(Logger.new(STDOUT))
      Kitchenplan::Log.level = loglevel
    end
    def load_config()
      self.config = Kitchenplan::Config.new().config
    end
    # Generate Chef configs based on the merged Kitchenplan config hints and run lists.
    def generate_chef_config()
      Kitchenplan::Log.info 'Generating the Chef configs'
      #$: << File.join((File.expand_path("../", Pathname.new(__FILE__).realpath)), "/lib")
      File.open("kitchenplan-attributes.json", 'w') do |out|
	out.write(::JSON.pretty_generate(self.config['attributes']))
      end
      File.open("solo.rb", 'w') do |out|
	out.write("cookbook_path      [ \"#{Dir.pwd}/cookbooks\" ]")
      end
    end
    def update_cookbooks_librarian()
      unless File.exists?("cookbooks")
	Kitchenplan::Log.info "No cookbooks directory found.  Running Librarian to download necessary cookbooks."
	self.normaldo "bin/librarian-chef install --clean #{(self.options[:debug] ? '--verbose' : '--quiet')}"
      end
      if self.options[:update_cookbooks]
	Kitchenplan::Log.info "Telling Librarian to update cookbooks."
	self.normaldo "bin/librarian-chef update #{(self.options[:debug] ? '--verbose' : '--quiet')}"
      end
    end
    def ping_google_analytics()
      # Trying to get some metrics for usage, just comment out if you don't want it.
      Kitchenplan::Log.info 'Sending a ping to Google Analytics to count usage'
      require 'Gabba'
      Gabba::Gabba.new("UA-46288146-1", "github.com").event("Kitchenplan", "Run", ENV['USER'])
    end
    def run
      Kitchenplan::Log.info "Kitchenplan starting up."
      # get options.  This function comes from {Kitchenplan::Mixin::Optparse}.
      self.options = parse_commandline()
      Kitchenplan::Log.debug "Started with options: #{options.inspect}"
      Kitchenplan::Log.info "Gathering prerequisites..."
      self.platform.prerequisites()
      Kitchenplan::Log.info "Generating Chef configs..."
      generate_chef_config()
      Kitchenplan::Log.info "Verifying cookbook dependencies..."
      ping_google_analytics() if 0 == 1
      update_cookbooks_librarian()
      self.platform.run_chef(use_solo=true,log_level="debug",recipes=self.config['recipes'])
      self.exit!("Chef run complete.  Exiting normally.")
    end
    # class method for executing a command as superuser.
    def self.sudo *args
      detect_platform
      Kitchenplan::Log.info self.platform.run_privileged(*args)
      system self.platform.run_privileged(*args)
    end
    # class method for executing a regular command.
    def self.normaldo *args
      detect_platform
      Kitchenplan::Log.info *args
      system *args
    end
    # In a Chef-like manner, log a fatal message to stderr/logger and exit with this error code.
    def self.fatal!(msg, err = -1)
      Kitchenplan::Log.fatal(msg)
      Process.exit err
    end
    # In a Chef-like manner, log a debug message to the logger and exit with this error code.
    def self.exit!(msg, err = -1)
      Kitchenplan::Log.debug(msg)
      Process.exit err
    end
  end
end
