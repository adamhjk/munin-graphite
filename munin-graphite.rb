#!/usr/bin/env ruby
#
# munin-graphite.rb
# 
# A Munin-Node to Graphite bridge
#
# Author:: Adam Jacob (<adam@hjksolutions.com>)
# Copyright:: Copyright (c) 2008 HJK Solutions, LLC
# License:: GNU General Public License version 2 or later
# 
# This program and entire repository is free software; you can
# redistribute it and/or modify it under the terms of the GNU 
# General Public License as published by the Free Software 
# Foundation; either version 2 of the License, or any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
# 

require 'socket'

class Munin
  def initialize(host='localhost', port=4949)
    @munin = TCPSocket.new(host, port)
    @munin.gets
  end
  
  def get_response(cmd)
    @munin.puts(cmd)
    stop = false 
    response = Array.new
    while stop == false
      line = @munin.gets
      line.chomp!
      if line == '.'
        stop = true
      else
        response << line 
        stop = true if cmd == "list"
      end
    end
    response
  end
  
  def close
    @munin.close
  end
end

class Carbon
  def initialize(host='localhost', port=2003)
    @carbon = TCPSocket.new(host, port)
  end
  
  def send(msg)
    @carbon.puts(msg)
  end
  
  def close
    @carbon.close
  end
end

while true
  metric_base = "servers."
  all_metrics = Array.new

  munin = Munin.new(ARGV[0])
  munin.get_response("nodes").each do |node|
    metric_base << node.split(".").reverse.join(".")
    puts "Doing #{metric_base}"
    munin.get_response("list")[0].split(" ").each do |metric|
      puts "Grabbing #{metric}"
      mname = "#{metric_base}"
      has_category = false
      base = false
      munin.get_response("config #{metric}").each do |configline|
        if configline =~ /graph_category (.+)/
          mname << ".#{$1}"
          has_category = true
        end
        if configline =~ /graph_args.+--base (\d+)/
          base = $1
        end
      end
      mname << ".other" unless has_category
      munin.get_response("fetch #{metric}").each do |line|
        line =~ /^(.+)\.value\s+(.+)$/
        field = $1
        value = $2
        all_metrics << "#{mname}.#{metric}.#{field} #{value} #{Time.now.to_i}"
      end
    end
  end

  carbon = Carbon.new(ARGV[1])
  all_metrics.each do |m|
    puts "Sending #{m}"
    carbon.send(m)
  end
  sleep 60
end

