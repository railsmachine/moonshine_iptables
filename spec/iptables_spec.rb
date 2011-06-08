require File.join(File.dirname(__FILE__), 'spec_helper.rb')

class IptablesManifest < Moonshine::Manifest
  include Iptables
  recipe :iptables
end

class IptablesWithRulesManifest < Moonshine::Manifest
  include Iptables
  rules = [
    '-A INPUT -p icmp -j ACCEPT',
    '-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT',
    '-A INPUT -p tcp -m tcp --dport 25 -j ACCEPT',
    '-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT',
    '-A INPUT -p udp -m udp --dport 123 -j ACCEPT',
    '-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT' ]
  configure(:iptables => { :rules => rules })
  recipe :iptables  
end

describe Iptables do

  describe 'generated puppet sources with passed in configuration' do
    before(:each) do
      @manifest = IptablesWithRulesManifest.new
      @manifest.send(:evaluate_recipes)
    end
    
    it "should write out the passes in rules to disk" do
      etc_rules = @manifest.files["/etc/iptables.rules"].content
      etc_rules.should =~ /^:INPUT DROP/
      etc_rules.should =~ /--dport 123/
    end
  end

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
        config = @manifest.send(:iptables_save)
        config.should =~ /^\*filter/
        config.should =~ /^:INPUT DROP/
        config.should =~ /^:FORWARD DROP/
        config.should =~ /^:OUTPUT ACCEPT/
        config.should =~ /^-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT/
        config.should =~ /^COMMIT/
      end
    end
    describe "with user provided chains and rules" do
      it "generates a iptables-restore compatible config with those chains and rules" do
        rules = [
          '-A INPUT -p icmp -j DROP'
        ]
        config = @manifest.send(:iptables_save, { :chains => { :input => :accept }, :rules => rules })
        config.should =~ /^:INPUT ACCEPT/
        config.should =~ /^-A INPUT -p icmp -j DROP/
        config.should_not =~ /-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT/
      end
    end
  end
end