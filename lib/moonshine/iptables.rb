module Moonshine
  module Iptables
    def iptables(options = {})
      package 'iptables', :ensure => :installed
      file '/etc/iptables.rules',
        :ensure   => :present,
        :mode     => 744,
        :owner    => 'root',
        :require  => package('iptables'),
        :content  => iptables_save(options)

      file '/etc/network/if-pre-up.d/iptables-restore',
        :ensure   => :present,
        :mode     => 755,
        :owner    => 'root',
        :require  => [
          package('iptables'),
          file('/etc/iptables.rules')
        ],
        :content  => """#!/bin/sh
  iptables-restore < /etc/iptables.rules
  exit 0"""

      exec 'iptables-restore < /etc/iptables.rules',
        :refreshonly => true,
        :subscribe   => file('/etc/iptables.rules')
    end

  private

    def iptables_save(options = {})
      options[:chains] = HashWithIndifferentAccess.new({
        :forward  => :drop,
        :input    => :drop,
        :output   => :accept
      }).merge(options[:chains] || {})

      options[:rules] ||= [
        '-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT',
        '-A INPUT -p icmp -j ACCEPT',
        '-A INPUT -p tcp -m tcp --dport 25 -j ACCEPT',
        '-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT',
        '-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT',
        '-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT',
        '-A INPUT -s 127.0.0.1 -j ACCEPT',
        '-A INPUT -p tcp -m tcp --dport 8000:10000 -j ACCEPT',
        '-A INPUT -p udp -m udp --dport 8000:10000 -j ACCEPT'
      ]

      content = <<-CONTENT
  # Generated by Iptables plugin for Moonshine.\n
  # It is STRONGLY suggested to make changes in\n
  # your application manifest rather than here.\n
  CONTENT
      content << "*filter\n"
      options[:chains].each do |chain, policy|
        content << ":#{chain.to_s.upcase} #{policy.to_s.upcase} [0:0]\n"
      end
      options[:rules].each do |rule|
        content << rule
        content << "\n"
      end
      content << "COMMIT\n"
      content << "#Completed"
      content
    end

  end
end