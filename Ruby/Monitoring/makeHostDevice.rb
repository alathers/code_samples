#!/usr/bin/env ruby

=begin
Adam Lathers
alathers@gmail.com

Simple tool to add new hosts to monitoring system.  The API is poorly exposed or documented, so this is all done with firebug, adn reversen engineering the API

Presently hosts of type TYPE1, TYPE2 and TYPE3 can be auto discovered and categorized.
    Support was added to manually define other parts of host definition to loosely handle "all" host types (ideally..tho untested)
try -h flag for usage info
9/11/2012


  License: This is for inspection only, no re-use allowed without written consent from author.



=end

require 'rubygems'
require 'restclient'
require 'json'
require 'optparse'


def createPost (device,options)
    # Define basic defaults
    loc= device.gsub(/[a-z0-9]+\./,'')
    location="/" + loc

    if options[:monhost] == "dev.site.com"
        options[:collector] = "dev.collector.site.com"
    elsif options[:collector] == false
        options[:collector] = "collector1.#{loc}"
    end

        # dev class selection, specific to Video/TYPE2
    if device =~ /^type1/      # IS TYPE1
        if device =~ /h1/
            options[:devClass]="/Server/Linux/video/vdc/head"
            elsif device =~ /h2/
            options[:devClass]="/Server/Linux/video/vdc/backup"
        elsif device =~ /node/
            options[:devClass]="/Server/Linux/video/vdc/node"
        else
            puts "device type #{device} unknown"
            puts
            return options,''
        end
        options[:groupPath]="/AppTeam"
        options[:systemPaths]="/Platform"

    elsif device =~ /^type2/   # IS TYPE2
        if device =~ /h1/
            options[:devClass]="/Server/Linux/video/type2/Head"
        elsif device =~ /h2/
            options[:devClass]="/Server/Linux/video/type2/Node"
        elsif device =~ /nd/
            options[:devClass]="/Server/Linux/video/type2/Node"
        else
            puts "device type #{device} unknown"
            return options,''
        end
        options[:groupPath]="/AppTeam"
        options[:systemPaths]="/Platform"
    elsif device =~ /^type3[0-9]/  # IS TYPE3ƒ
        options[:devClass]="/Server/Linux/type3"
        options[:groupPath]="/AppTeam"
        options[:systemPaths]="/Platform"
    else            # ELSE FAIL
        puts "device type #{device} unknown"
        return options,''
    end

    return options,JSON.generate(["action"=>"DeviceRouter", "method"=>"addDevice", "data" => ["deviceName"=>device,"deviceClass"=>options[:devClass],"collector"=>options[:collector],"locationPath"=>location,"model"=>true,"productionState"=>options[:state],"snmpPort"=>161,"groupPaths"=>[options[:groupPath]],"systemPaths"=>[options[:systemPaths]]],"type"=>"rpc","tid"=>"48"])
end



options = {}  # define an empty options hash, and then fill in all the defaults, and overrides.  Do it this way instead of
                # as one big defaults declaration just to make it easier to see, and expand
optparse = OptionParser.new do |opts|
    opts.banner = "Usage: newHost.rb [options] host1 host2 ..."

    options[:help] = false
    opts.on('-h', '--help', 'Display this screen') do
        puts opts
        exit
    end

    options[:username]="devuser"
    opts.on("-u user", "--username user", "user")do |user|
        options[:username]=user
    end

    options[:password]="devpass"
    opts.on("-p password","--password password","password") do |pass|
        options[:password]=pass
    end

    if !options[:groupPath] then options[:groupPath]=false end
    opts.on("-g groupPaths","--group groupPaths", "Required: Comma separated list of group paths, such as: '/groupPath1,/groupPath2'")do |path|
        options[:groupPath]=path
    end

    if !options[:systemPaths] then options[:systemPaths]=false end
    opts.on("-s systemPaths","--system systemPaths","Required: Comma separated list of system paths, such as: '/systemPath1,/systemPath2'")do |path|
        options[:systemPaths]=path
    end

    options[:collector]=false
    opts.on("-c collector","--collector collector", "collector (defaults to collect1 in appropriate DC)")do |col|
        options[:collector]=col
    end

    options[:monhost]="dev.collector.site.com"
    opts.on("-z monitoring.host.com","--monhost monitoring.host.com", "monitoring_host (defaults to dev.collector.site.com, always uses https)")do |monhost|
        options[:monhost]=monhost
    end

    options[:state]="300"
    opts.on("--state state", "Number production state, defaults to Maintenance: 300")do|prodState|
        options[:state]=prodState
    end

    options[:verify]=false
    opts.on('-v','--verify', "Verify that machine add was successful, and monitoring_host has 'built' the device") do
        options[:verify]=true
    end

    options[:live]=false
    opts.on("-l", "--live", "Log in to live system.  Auto set URI, Pass, and username") do |live|
        options[:live]=true
        options[:password]="prodpass"
        options[:username]="produser"
        options[:monhost]="prod.uri.com"
    end
end

optparse.parse!  #Parse and check for required fields

addpath="zport/dmd/device_router"                           # URI path when adding a device
adduri="https://" + options[:username] + ":" + options[:password] + "@" + options[:monhost] + "/" + addpath

ARGV.each do |device|   #Add hosts
    options,header = createPost(device,options)
    abort "please supply required field systemPaths" if options[:systemPaths] == false
    abort "please supply required field groupPaths" if options[:groupPath] == false
    abort "no hostname provided" if ARGV.length == 0
    res=RestClient.post adduri, header, :content_type => :json, :accept => :json

    if res !~ /"success": true/
        puts "Error while adding #{device}."
        if res =~ /already exists/
            puts "Host already exists in #{options[:monhost]}"
        else
            "Response:\n\n" + res
        end
    else
        puts "Add request for device #{device} on #{options[:monhost]} successful."
    end
    sleep 1
end

checkpath="zport/dmd/Devices/findDevicePath?devicename="    # URI path when checking if a device exists

if options[:verify] == true
    ARGV.each do |device|   #Verify that host add was success
        checkuri="https://" + options[:username] + ":" + options[:password] + "@" + options[:monhost] + "/" + checkpath + device
        check=RestClient.get checkuri
        if check.length == 0
            puts "  Waiting for 'device add' job to process"
        end
        count=0
        while check.length == 0  && count < 50  # Risky loop, but should
            sleep 5
            check=RestClient.get checkuri
            count+=1
        end
        if count == 10 && check.length == 0
            puts "It appears the host add job failed to process for #{device}.  Please verify and contact ops monitoring if issues persist"
        end
    end
end


