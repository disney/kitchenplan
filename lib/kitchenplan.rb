# Copyright 2014 Disney Enterprises, Inc. All rights reserved
#  
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are
#  met:
#   
#   * Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#    
#   * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in
#   the documentation and/or other materials provided with the
#   distribution.
require 'json'
require 'ohai'
require 'kitchenplan/log'
require 'kitchenplan/config'
# platform-specificity
require 'kitchenplan/platform'
require 'kitchenplan/version'

# Top-level class for all Kitchenplan-y operations.
class Kitchenplan
    attr_accessor :platform
    attr_accessor :resolver
    # all Kitchenplans care about what platform they're on and what resolver they use to get their cookbooks.
    def initialize(ohai=nil)
	detect_platform(ohai)
	detect_resolver()
    end
    # invoke platform detection code - attempt to load the class that corresponds to the ohai platform name.
    # ohai platform name can be overridden by caller (i.e. for unit testing or by creative users)
    # 
    def detect_platform(ohai=nil)
	ohai = get_system_ohai() if ohai.nil?
	platform = ohai["platform_family"]
	klass = camelcase(platform)
	begin
	    require "kitchenplan/platform/#{platform}"
	rescue LoadError
	    raise "Unsupported platform or fatal error loading support for platform '#{platform}' (#{klass}) ..."
	end
	self.platform = eval("Kitchenplan::Platform::#{klass}.new(ohai=ohai)") unless defined?(self.platform) and self.platform.nil? == false
	self.platform.ohai = ohai unless defined?(self.platform.ohai) and self.platform.ohai.nil? == false
    end

    # return a usable Ohai object with only the plugins we need to get Kitchenplan going.
    def get_system_ohai(plugins=["os","platform"])
	o = Ohai::System.new
	o.load_plugins
	o.run_plugins(safe=false, attribute_filter=plugins)
	o
    end


    # invoke resolver detection code.  start with library resolvers and auto-load them.  then walk {Kitchenplan::Resolver} subclasses and take the first one that works.
    # TODO: may want to allow the user to specify a resolver preference.
    def detect_resolver(debug=false,config_dir=Dir.pwd)
	if defined?(self.resolver) and self.resolver.nil? == false
	    return self.resolver
	end
	Kitchenplan::Log.debug " detect_resolver(): self.resolver == #{self.resolver.class}"
	Kitchenplan::Log.debug " detect_resolver() params: debug = #{debug} , config_dir = #{config_dir}"
	# look for all resolvers in our lib directory and attempt to include them.
	begin
	    Dir.glob(File.expand_path("../kitchenplan/resolver/*.rb", __FILE__)).each do |file|
		Kitchenplan::Log.debug "Loading #{file}"
		require file
	    end
	rescue Exception => e
	    Kitchenplan::Log.error "Ack!  #{e.message}"
	end
	# loop through the resolver classes we just loaded and see which (if any) will load up for us.
	# this should catch plugins, too, if you cleverly load them somehow in the Ruby environment.
	Kitchenplan::Resolver.constants.each do |resolver_candidate|
	    Kitchenplan::Log.debug "resolver candidate: #{resolver_candidate.to_s}"
	    begin
		self.resolver = eval("Kitchenplan::Resolver::#{resolver_candidate.to_s}.new(debug=debug,config_dir=#{config_dir})") unless self.resolver.nil? == false
		# now that we've instantiated the new resolver, ask if it's present and happy.
		# if it's not ... back to the pit with it!
		if self.resolver.present?
		Kitchenplan::Log.debug "self.resolver == #{self.resolver.class}"
		break
		else
		    Kitchenplan::Log.debug "present? : #{self.resolver.present?}"
		    self.resolver = nil unless self.resolver.present?
		end
	    rescue Exception => e
		Kitchenplan::Log.debug "Resolver instantiation error: #{e.message} #{e.backtrace}"
	    end
	end
	if self.resolver.nil?
	    Kitchenplan::Log.warn "No resolvers loaded.  This could be a problem."
	end
    end


    private
    # "something_with_underscores" -> "SomethingWithUnderscores"
    def camelcase(string)
	string.downcase.split("_").each_with_index {|word, i| word.capitalize!}.join("")
    end
end
