#!/usr/bin/env ruby

# We use old ruby 1.8.7
# rubocop:disable Style/HashSyntax

# We match all exceptions except SystemExit to redefine exit status for nagios
# rubocop:disable Lint/RescueException

# Other disables
# rubocop:disable Metrics/AbcSize, Metrics/LineLength, Metrics/MethodLength, Metrics/ClassLength

# Nagios exit codes
module NagiosStatus
  OK = 0
  WARNING = 1
  CRITICAL = 2
end

# Top level module
module CheckGluster
  require 'optparse'

  PARAMS = {
    # gluster command
    :gluster_command => '/usr/sbin/gluster',
    :glusterd_pid_path => '/var/run/glusterd.pid',
    # Daemons to check with gluster volume status
    :check_running_daemons => {
      'bitrot' => ['Bitrot Daemon', 'Scrubber Daemon'],
      'heal' => ['Self-heal Daemon'],
      'nfs' => ['NFS Server']
    },
    # Parameters to re-run failed command
    :rerun => { :times => 10, :delay => 0.5 },
    # persistent state file
    :state_file => '/var/run/check_gluster_state.yaml',
    :state_ttl => 1200,
    :self_name => '127.0.0.1'
  }.freeze

  # Parse command line options
  class OptionsParser
    attr_reader :checks, :state_file, :state_ttl, :self_name

    def initialize
      @checks = PARAMS[:check_running_daemons].keys
      @state_file = PARAMS[:state_file]
      @state_ttl = PARAMS[:state_ttl]
      @self_name = PARAMS[:self_name]
    end

    def parse!
      option_parser = OptionParser.new

      option_parser.on(
        '-c',
        '--checks ' + @checks.join(','),
        Array,
        'Checks to run. Default is ' + @checks.join(',')
      ) do |list|
        list.each do |check|
          raise OptionParser::InvalidOption, check.to_s unless @checks.include? check
        end
        @checks = list
      end

      option_parser.on(
        '-s',
        '--state-file /path/to/file',
        String,
        'State storage file. Default is ' + @state_file
      ) do |x|
        @state_file = x.to_s
      end

      option_parser.on(
        '-n',
        '--self-name address',
        String,
        'IP of self as far as glusterd know. Default is ' + @self_name
      ) do |x|
        @self_name = x.to_s
      end

      option_parser.on(
        '-t',
        '--ttl seconds',
        Integer,
        'State storage TTL. Default is ' + @state_ttl.to_s
      ) do |x|
        @state_ttl = x.to_i
      end

      begin
        option_parser.parse!
        @checks
      rescue OptionParser::InvalidOption, OptionParser::MissingArgument, OptionParser::InvalidArgument => ex
        puts "Error: #{ex.message}"
        puts option_parser.help
        exit(NagiosStatus::CRITICAL)
      end
    end
  end

  # Actual check class
  class Check
    begin
      require 'open3'
      require 'rubygems'
      $VERBOSE = nil
      require 'crack'
      $VERBOSE = true
      require 'socket'
      require 'yaml'
    rescue Exception => ex
      puts ex.message
      exit(NagiosStatus::CRITICAL)
    end

    def initialize(*var)
      var = var.shift
      @state_file = var.nil? && var[:state_file].nil? ? PARAMS[:state_file] : var[:state_file]
      @state_ttl  = var.nil? && var[:state_ttl].nil?  ? PARAMS[:state_ttl] : var[:state_ttl]
    end

    def check_glusterd
      pid = File.open(PARAMS[:glusterd_pid_path], &:readline).to_i
      Process.kill('CHLD', pid)
    rescue Errno::ESRCH
      raise 'Glusterd is not running'
    end

    def get_services_from_checks(checks)
      services = []
      checks.each do |check|
        PARAMS[:check_running_daemons][check].each do |service|
          services.concat(any_to_array(service))
        end
      end
      services
    end

    def gluster(command, xml = true)
      data = { 'stdout' => '', 'error' => '', 'status' => 1 }
      command = '--xml ' + command if xml
      Open3.popen3(PARAMS[:gluster_command] + ' ' + command) do |stdin, stdout, stderr, wait_thr|
        stdin.close
        data['stdout'] = stdout.read
        data['sterr'] = stderr.read
        data['status'] = wait_thr.value
      end
      raise data['status'].to_s + ' : ' + data['stdout'] unless data['status'].success?
      return data['stdout'] unless xml
      data = Crack::XML.parse(data['stdout'])
      if data['cliOutput']['opRet'].to_i != 0 || data['cliOutput']['opErrno'].to_i != 0
        raise "Error on #{command} : #{data['cliOutput']['opErrstr']}"
      end
      data['cliOutput']
    end

    def peer_status
      peers = gluster('peer status')['peerStatus']['peer']
      peers = any_to_array(peers)
      peers.each do |peer|
        raise "#{peer['hostname']} is disconnected" unless peer['connected'].to_i == 1
        raise "#{peer['hostname']} has wrong state #{peer['state']}" unless peer['state'].to_i == 3
      end
    end

    def pool_list
      peers = gluster('pool list')['peerStatus']['peer']
      peers = any_to_array(peers)
      peers.each do |peer|
        raise "#{peer['hostname']} is disconnected" unless peer['connected'].to_i == 1
        raise "#{peer['hostname']} has wrong state #{peer['state']}" if peer['hostname'] != 'localhost' && peer['state'].to_i != 3
      end
    end

    def volume_list
      volumes = gluster('volume list')['volList']['volume']
      any_to_array(volumes)
    end

    def volume_info(volume)
      volume = gluster("volume info #{volume}")['volInfo']['volumes']['volume']
      raise "volume #{volume['name']} is stopped" unless volume['status'].to_i == 1
      # volume info is not well formated XML
      volume['bricks']['brick'].map { |s| s.gsub(/<name>.*/, '').split(':') }
    end

    def volume_status(volume, bricks, checks, self_name)
      nodes = gluster("volume status #{volume}")['volStatus']['volumes']['volume']['node']
      nodes = any_to_array(nodes)
      # Check that all bricks are running
      bricks.each do |brick|
        raise "volume #{brick[0]}:#{brick[1]} is not running" unless check_running(nodes, brick[0], brick[1])
        # Check that processes are running
        get_services_from_checks(checks).each do |daemon|
          brick_to_check = brick[0]
          if brick[0] == self_name
            brick_to_check = 'localhost'
          end
          raise "Daemon #{brick[0]}:\"#{daemon}\" is not started" unless check_running(nodes, daemon, brick_to_check)
        end
      end
    end

    def check_running(nodes, hostname, path)
      nodes.each do |node|
        return true if node['hostname'] == hostname && node['path'] == path && node['status'].to_i == 1
      end
      false
    end

    def volume_heal_info(volume)
      info = gluster("volume heal #{volume} info", false).split("\n")
      info = parse_heal(info)
      if @state_ttl > 0
        info = merge_heal(load_state(@state_file), info)
        store_state(@state_file, info)
      end
      split_entries = []
      time = Time.now.to_i
      info.each do |brick, data|
        raise "Brick #{brick} is disconnected" unless data['status']
        data['content'].each do |line, saved_time|
          if @state_ttl == 0
            split_entries.push(brick + line)
          elsif time - saved_time >= @state_ttl
            split_entries.push(brick + line + '=' + (time - saved_time).to_s + 's')
          end
        end
      end
      raise 'Files are split-brained : ' + split_entries.join(' ') unless split_entries.empty?
    end

    def parse_heal(info)
      bricks = {}
      brick = ''
      time = Time.now.to_i
      info.each do |line|
        if line =~ /^Brick /
          brick = line.gsub(/^Brick /, '')
          bricks[brick] = { 'content' => {} }
        elsif line =~ /^Status: Connected/
          bricks[brick]['status'] = true
        elsif line =~ /^Status.*/
          bricks[brick]['status'] = false
        elsif line =~ /^Number of entries: /
          bricks[brick]['entries'] = line.gsub(/^Number of entries: /, '').to_i
        else
          line.gsub!(/\s+$/, '')
          bricks[brick]['content'][line] = time if line != ''
        end
      end
      bricks
    end

    def merge_heal(old, new)
      old.each do |brick, data|
        data['content'].each do |line, time|
          new[brick]['content'][line] = time if new.key?(brick) && new[brick]['content'].key?(line)
        end
      end
      new
    end

    def store_state(file, data)
      fh = File.open(file, File::WRONLY | File::CREAT | File::TRUNC, 0600)
      fh.flock(File::LOCK_EX)
      fh.write(data.to_yaml)
      fh.close
    end

    def load_state(file)
      return {} unless File.exist?(file)
      fh = File.open(file, File::RDONLY)
      fh.flock(File::LOCK_EX)
      data = fh.read
      fh.close
      begin
        data = YAML.load(data)
        raise LoadError if data.class.to_s != 'Hash'
      rescue Psych::SyntaxError, LoadError
        raise 'file ' + file.to_s + ' has incorrect format'
      end
      data
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def volume_bitrot_scrub_status(volume)
      info = []
      i = 0
      # Try to run bitrot scrub status not more than 10 times
      while info.empty?
        i += 1
        begin
          info = gluster("volume bitrot #{volume} scrub status", false).split("\n")
        rescue ArgumentError => ex
          raise ex if ex.message != 'invalid byte sequence in UTF-8' || i > PARAMS[:rerun][:times]
          sleep PARAMS[:rerun][:delay]
        end
      end
      status = parse_bitrot_status(info)
      raise 'BitRot is not enabled' unless status['state']
      status['nodes'].each do |node, _v|
        raise "BitRot error on #{node}" unless status['nodes'][node]['errors'] == 0
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def parse_bitrot_status(info)
      info.map! { |s| s.gsub(/localhost/, Socket.gethostname) }
      status = { 'state' => false, 'nodes' => {} }
      node = ''
      info.each do |line|
        if line =~ /^State of scrub: Active/
          status['state'] = true
        elsif line =~ /^Node: /
          node = line.gsub(/^Node: /, '')
          status['nodes'][node] = {}
        elsif line =~ /^Error count: /
          status['nodes'][node]['errors'] = line.gsub(/^Error count: /, '').to_i
        end
      end
      status
    end

    def any_to_array(any)
      return [any] if any.class.to_s != 'Array'
      any
    end

    private :get_services_from_checks, :gluster, :any_to_array
    private :check_running, :parse_heal, :parse_bitrot_status
    private :merge_heal, :store_state, :load_state
  end
end

begin
  # Parse parameters
  option_parser = CheckGluster::OptionsParser.new
  option_parser.parse!
  checks = option_parser.checks
  self_name = option_parser.self_name

  # Run gluster checks
  gluster_check = CheckGluster::Check.new(:state_file => option_parser.state_file, :state_ttl => option_parser.state_ttl)
  gluster_check.check_glusterd
  gluster_check.peer_status
  gluster_check.pool_list
  gluster_check.volume_list.each do |volume|
    bricks = gluster_check.volume_info(volume)
    gluster_check.volume_status(volume, bricks, checks, self_name)
    gluster_check.volume_heal_info(volume) if checks.include? 'heal'
    gluster_check.volume_bitrot_scrub_status(volume) if checks.include? 'bitrot'
  end

  puts 'OK: Gluster cluster is healthy'
  exit(NagiosStatus::OK)
# Normal exit
rescue SystemExit => ex
  raise ex
# Anything else goes to nagios error with critial status
rescue Exception => ex
  puts "Error: #{ex.message}"
  exit(NagiosStatus::CRITICAL)
end

# rubocop:enable all
