#!/usr/bin/env ruby

# installation script modeled after homebrew
# see https://raw.github.com/mxcl/homebrew/go
#
# script is re-runnable and will automatically update an existing installation
# with the latest changes before installing new recipes.
#
# example execution:
#   $ ruby -e "$(curl -fsSL https://raw.github.com/kitchenplan/kitchenplan/master/go)"
#
# execution can be customized by the following environmental variables:
# KITCHENPLAN_PATH - kitchenplan installation path (defaults to /opt/kitchenplan)
# KITCHENPLAN_REPO - repository to use for recipes/cookbooks (defaults to https://github.com/kitchenplan/kitchenplan)

KITCHENPLAN_PATH = ENV.fetch("KITCHENPLAN_PATH", "/opt/kitchenplan")
KITCHENPLAN_REPO = ENV.fetch("KITCHENPLAN_REPO", "https://github.com/kitchenplan/kitchenplan.git")

# execute a shell command and raise an error if non-zero exit code is returned
def run_cmd(cmd, options = {})
  puts "$ #{cmd}"
  success = system(cmd)
  fail "#{cmd} failed" unless success || options[:allow_failure]
end

# check if xcode command line tools are installed
def xcode_cli_installed?
  xcode_path = `xcode-select -p`
  xcode_cli_installed = $?.to_i == 0
end

def normaldo *args
  ohai *args
  system *args
end

def getc  # NOTE only tested on OS X
  system "/bin/stty raw -echo"
  if RUBY_VERSION >= '1.8.7'
    STDIN.getbyte
  else
    STDIN.getc
  end
ensure
  system "/bin/stty -raw echo"
end

def wait_for_user
  puts
  puts "Press ENTER to continue or any other key to abort"
  puts
  c = getc
  # we test for \r and \n because some stuff does \r instead
  abort unless c == 13 or c == 10
end

def macos_version
  @macos_version ||= `/usr/bin/sw_vers -productVersion`.chomp[/10\.\d+/]
end

######################################################

ohai "Kitchenplan is only tested on 10.8 and 10.9, proceed on your own risk." if macos_version < "10.8"
wait_for_user if macos_version < "10.8"
#abort "OSX too old, you need at least Mountain Lion" if macos_version < "10.8"

abort "Don't run this as root!" if Process.uid == 0
abort <<-EOABORT unless `groups`.split.include? "admin"
This script requires the user #{ENV['USER']} to be an Administrator.
EOABORT

if macos_version < "10.9" and macos_version > "10.6"
  `/usr/bin/cc --version 2> /dev/null` =~ %r[clang-(\d{2,})]
  version = $1.to_i
  warnandexit %{Install the "Command Line Tools for Xcode": https://developer.apple.com/downloads/} if version < 425
else
  warnandexit "Install Xcode: https://developer.apple.com/xcode/" unless File.exist? "/usr/bin/cc"
end

ohai "This script will install:"
puts "  - Command Line Tools if they are not installed"
puts "  - Chef"
puts "  - All applications configured in <yourusername>.yml or if not available roderik.yml"
puts ""
warn "Unless by chance your user is also named Roderik, and you want exactly the same applications as I, use the KITCHENPLAN_REPO env to point to a fork with a config file named for your username."
puts ""

wait_for_user if options[:interaction]

if macos_version > "10.8"
  unless File.exist? "/Library/Developer/CommandLineTools/usr/bin/clang"
    ohai "Installing the Command Line Tools (expect a GUI popup):"
    sudo "/usr/bin/xcode-select", "--install"
    puts "Press any key when the installation has completed."
    getc
  end
end

if File.directory?(KITCHENPLAN_PATH)
  puts "Updating existing kitchenplan installation..."
  Dir.chdir KITCHENPLAN_PATH
  run_cmd "git pull"
else
  ohai "Setting up the Kitchenplan installation..."
  sudo "mkdir -p #{KITCHENPLAN_PATH}"
  sudo "chown -R #{ENV["USER"]} #{KITCHENPLAN_PATH}"
  normaldo "git clone -q #{KITCHENPLAN_REPO} #{KITCHENPLAN_PATH}"
  Dir.chdir KITCHENPLAN_PATH
  normaldo "git checkout version2"
end

normaldo "./kitchenplan #{options[:interaction] ? '': '-d'}"
