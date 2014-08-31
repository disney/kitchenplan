require 'spec_helper'
require 'ohai'
require 'kitchenplan'

describe Kitchenplan do
	describe "#detect_platform" do
		let(:system_ohai) { Ohai::System.new() }
		it "uses system ohai if the passed ohai param is nil" do
			system_ohai.require_plugin("os")
			system_ohai.require_plugin("platform")
			kp = Kitchenplan.new(ohai=nil)
			kp.detect_platform(ohai=nil)
			expect(kp.platform.ohai).to match system_ohai
		end
	end
	describe "#detect_platform" do
		platforms = {
			'mac_os_x' => ['10.8.2','10.7.4'],
			'redhat' => ['6.3','5.8'],
			'ubuntu' => ['12.04'],
			'windows' => ['2008R2']

		}
		platforms.each do |platform, versions|
			versions.each do |version|
				context "On #{platform} #{version}" do
					let(:config) { Kitchenplan::Config.new(parse_configs=false,ohai=Fauxhai.mock(platform:platform, version:version).data)}
					it 'should load the corresponding Kitchenplan platform class' do
						case platform
						when /redhat|amazon|centos|xenserver|oracle/
							my_platform = "rhel"
						when /debian|ubuntu/
							my_platform = "debian"
						else
							my_platform = platform
						end
						expect(config.platform.name).to eq(my_platform)
					end
				end
			end
		end

		it 'should raise an exception on an unsupported platform' do
			# sorry, FBSD'ers.  :D
			# TODO: Replace FreeBSD with a locally-distributed and wholly fictitious fixture
			expect { Kitchenplan::Config.new(parse_configs=false,ohai=Fauxhai.mock(platform:'freebsd', version:'9.1').data) }.to raise_error
		end
	end
	describe "#detect_resolver" do
		pending
	end
end
