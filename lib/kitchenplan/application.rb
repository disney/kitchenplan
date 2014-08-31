require 'kitchenplan'

class Kitchenplan
  # application class is the class invoked by bin/kitchenplan.  this is where almost all of the
  # heavy lifting for the app happens.
  class Application < Kitchenplan
    attr_accessor :options, :config
    include Kitchenplan::Mixin::Display
    include Kitchenplan::Mixin::Optparse
    # Main point of entry for kitchenplan binary.  #run starts the app.
    def initialize
      # get options.  This function comes from {Kitchenplan::Mixin::Optparse}.
      self.options = parse_commandline()
      super
      configure_logging
      detect_platform()
      detect_resolver()
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
    # set up the admittedly Chef-style logger facility
    # Except that we don't log anywhere but STDOUT right now.
    def configure_logging(loglevel=:debug)
      Kitchenplan::Log.init(Logger.new(STDOUT))
      Kitchenplan::Log.level = loglevel
    end
    # load our application config and make it available elsewhere.
    def load_config()
      if self.options[:config_dir]
	config = Kitchenplan::Config.new(parse_configs=false)
	config.config_path = self.options[:config_dir]
	config.do_parse_configs()
	self.config = config.config()
      else
      self.config = Kitchenplan::Config.new().config
      end
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
    # using our chosen resolver, ensure that our cookbooks/ directory is up-to-date before we run Chef.
    def update_cookbooks()
      self.resolver.debug = self.options[:debug]
      unless File.exists?("cookbooks")
	Kitchenplan::Log.info "No cookbooks directory found.  Running Librarian to download necessary cookbooks."
	self.platform.normaldo self.resolver.fetch_dependencies()
	#self.normaldo "bin/librarian-chef install --clean #{(self.options[:debug] ? '--verbose' : '--quiet')}"
      end
      if self.options[:update_cookbooks]
	Kitchenplan::Log.info "Updating cookbooks with #{self.resolver.name}"
	self.platform.normaldo self.resolver.update_dependencies()
	#self.normaldo "bin/librarian-chef update #{(self.options[:debug] ? '--verbose' : '--quiet')}"
      end
    end
    # let us know who's running Kitchenplan.
    def ping_google_analytics()
      # Trying to get some metrics for usage, just comment out if you don't want it.
      Kitchenplan::Log.info 'Sending a ping to Google Analytics to count usage'
      require 'Gabba'
      Gabba::Gabba.new("UA-46288146-1", "github.com").event("Kitchenplan", "Run", ENV['USER'])
    end
    # main point of entry for the class.
    def run
      Kitchenplan::Log.info "Kitchenplan starting up."
      # get options.  This function comes from {Kitchenplan::Mixin::Optparse}.
      Kitchenplan::Log.debug "Started with options: #{options.inspect}"
      Kitchenplan::Log.info "Gathering prerequisites..."
      self.platform.prerequisites()
      Kitchenplan::Log.info "Generating Chef configs..."
      generate_chef_config()
      Kitchenplan::Log.info "Verifying cookbook dependencies with #{self.resolver.name}..."
      ping_google_analytics() if 0 == 1
      update_cookbooks()
      self.platform.sudo(self.platform.run_chef(use_solo=true,log_level="debug",recipes=self.config['recipes']))
      self.exit!("Chef run complete.  Exiting normally.")
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
