require File.join(File.dirname(__FILE__), '..', 'spec_helper.rb')

class IptablesManifest < Moonshine::Manifest
  include Moonshine::Iptables
end

describe Moonshine::Iptables do

  describe 'the generated puppet resources' do
    before(:each) do
      @manifest = IptablesManifest.new
      @manifest.iptables
    end

    it "ensures iptables is installed" do
      @manifest.packages.keys.should include('iptables')
    end

    it "creates the iptables rules" do
      @manifest.files.keys.should include('/etc/iptables.rules')
    end

    it "creates a script to load them on interface init" do
      @manifest.files.keys.should include('/etc/network/if-pre-up.d/iptables-restore')
    end

    it "loads the new iptables rules whenever they've been changed" do
      @manifest.execs.keys.should include('iptables-restore < /etc/iptables.rules')
      @manifest.execs['iptables-restore < /etc/iptables.rules'].refreshonly.should be_true
    end
  end

  describe "the generated iptables configuration string" do
    before(:each) do
      @manifest = IptablesManifest.new
    end

    describe "with no configuration" do
      it "generates a default iptables-restore compatible config" do
        @manifest.iptables
        @manifest.files['/etc/iptables.rules'].content.should =~ /^\*filter/
        @manifest.files['/etc/iptables.rules'].content.should =~ /^:INPUT DROP/
        @manifest.files['/etc/iptables.rules'].content.should =~ /^:FORWARD DROP/
        @manifest.files['/etc/iptables.rules'].content.should =~ /^:OUTPUT ACCEPT/
        @manifest.files['/etc/iptables.rules'].content.should =~ /^-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT/
        @manifest.files['/etc/iptables.rules'].content.should =~ /^COMMIT/
      end
    end
    describe "with user provided chains and rules" do
      it "generates a iptables-restore compatible config with those chains and rules" do
        rules = [
          '-A INPUT -p icmp -j DROP'
        ]
        @manifest.iptables({
          :chains => {
            :forward  => :drop,
            :input    => :accept,
            :output   => :accept
          },
          :rules => [
            '-A INPUT -s 65.54.241.206 -j DROP'
          ]
        })

        @manifest.files['/etc/iptables.rules'].content.should =~ /^:INPUT ACCEPT/
        @manifest.files['/etc/iptables.rules'].content.should =~ /-A INPUT -s 65.54.241.206 -j DROP/
        @manifest.files['/etc/iptables.rules'].content.should_not =~ /-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT/
      end
    end
  end
end