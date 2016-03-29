require 'active_support'
require 'active_support/core_ext'
require 'socket'

class Seat
  attr_accessor :no, :player

  def initialize(no, player = nil)
    @no = no
    @player = player
  end
end

class Player
  attr_accessor :stack, :name

  def initialize(name, stack)
    @name = name
    @stack = stack
  end
end

class ActionManager
  attr_accessor  :pot_amount
  def initialize(agent_map, pot_amount)
    @agent_map = agent_map
    @pot_amount = pot_amount
    @plalyer_statuses = {}

    @history = []
  end

  def process_action(action)
    case action[:action]
    when 'bet'
      bet_amount = action[:amount]
      @pot_amount += bet_amount
      action[:agent].seat.player.stack -= bet_amount
    when 'call'
      bet_amount = action[:amount]
      @pot_amount += bet_amount
      action[:agent].seat.player.stack -= bet_amount
    when 'check'
    when 'raise'
      bet_amount = action[:amount]
      @pot_amount += bet_amount
      action[:agent].seat.player.stack -= bet_amount
    when 'fold'
    end
  end

  def result
    puts "HISTORY:"
    p @history
    puts "pot: #{@pot_amount}"
    puts "last actions: #{ @history.slice(@current_history_index..-1)}"
  end

  def hoge
    @current_history_index ||= 0
    @current_base_no = 0

    agents = @agent_map.values.slice(@current_base_no..-1)
    if @current_base_no > 0
      agents += @agent_map.values.slice(0..(@current_base_no-1))
    end

    while true
      unless each_action(agents)
        break
      end
      # current以外
      agents = @agent_map.values.slice((@current_base_no+1)..-1)
      if @current_base_no > 0
        agents += @agent_map.values.slice(0..(@current_base_no-1))
      end
      fold_numbers = @history.select { |h| h[:action] == 'fold' }.map { |h| h[:agent].seat.no }
      agents = agents.select { |a| !a.seat.no.in?(fold_numbers) }
    end 
  end

  # agent_map: bet or raiseしたプレイヤー以外　
  def each_action(agents)
    puts "ENTER: each_action, #{@current_history_index}, #{@current_base_no}"
    p agents.map(&:seat).map(&:no)

    prev_action = nil
    agents.each do |agent|
      action = one_action(agent, prev_action)
      @history << action
      prev_action = action
      puts "[Player] #{agent.seat.player.name}'s action: #{action[:action]}, amount: #{action[:amount]}"
      puts "Pot: #{@pot_amount}"
      if action[:action] == 'bet' || action[:action] == 'raise'
        @current_history_index = @history.size - 1
        @current_base_no = agent.seat.no
        return true
      end
    end
    # puts "LEAVE: each_action"
    false
  end

  def one_action(agent, prev_action)
    res = agent.comm(type: 'action', prev_action: prev_action)
    action = {}
    action[:agent] = agent
    action[:action] = res[:action]
    action[:amount] = res[:amount]
    process_action(action)
    action
  end
end

class Client < TCPSocket
  def puts(hash)
    # p hash
    super(JSON.generate(hash))
  end

  def gets
    resp = super
    JSON.parse(resp, symbolize_names: true)
  end
end

class PlayerManager
  attr_accessor :agent_map

  def initialize(agent_map)
    @agent_map = agent_map
  end

  def broadcast(hash)
    @agent_map.each do |no, agent|
      agent.comm(hash.merge(type: 'broadcast'))
    end
  end
end

class ServerAgent
  attr_accessor :seat

  def initialize(sock, seat)
    @sock = sock
    @seat = seat
  end

  def gets
    JSON.parse(@sock.gets, symbolize_names: true)
  end

  def puts(hash)
    # p hash
    @sock.puts(JSON.generate(hash))
  end

  def comm(hash)
    p hash
    @sock.puts(JSON.generate(hash))
    gets
  end
end

class PlayerAgent
  attr_accessor :player

  def initialize
    @sock = Client.new('localhost', 12345)
    res = @sock.gets
    player_name = "Player#{res[:no]}"
    @sock.puts(name: player_name)
    res = @sock.gets
    player_stack = res[:stack]
    @player = Player.new(player_name, player_stack)
  end

  def gets; @sock.gets; end
  def puts(hash); @sock.puts(hash); end
  def close; @sock.close; end

  def ping
    @sock.puts(cmd: 'ping')
  end

  def bet(amount)
    @sock.puts(cmd: 'bet', action: 'bet', amount: amount)
    @player.stack -= amount
  end

  def check
    @sock.puts(cmd: '', action: 'check')
  end

  def win(amount)
    @player.stack += amount
  end
end
