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

    agents.each do |agent|
      action = one_action(agent)
      @history << action
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

  def one_action(agent)
    res = agent.comm(type: 'action')
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

class Card
  # rank: 'A', '2', '3', ..., '9', 'T', 'J', 'Q', 'K'
  # suit: 's', 'c', 'h', 'd'
  # strength: 14, 2, 3, ..., 10, 11, 12, 13
  attr_accessor :id, :rank, :suit, :strength

  MASTERS = %w(
    As 2s 3s 4s 5s 6s 7s 8s 9s Ts Js Qs Ks
    Ah 2h 3h 4h 5h 6h 7h 8h 9h Th Jh Qh Kh
    Ac 2c 3c 4c 5c 6c 7c 8c 9c Tc Jc Qc Kc
    Ad 2d 3d 4d 5d 6d 7d 8d 9d Td Jd Qd Kd
  )

  # TODO: validation
  def initialize(id)
    @id = id
    @rank = id[0]
    @suit = id[1]
    @strength =
      case id[0]
      when 'A'
        14
      when 'T'
        10
      when 'J'
        11
      when 'Q'
        12
      when 'K'
        13
      else
        id[0].to_i
      end
  end
end

class Deck
  def initialize
    @cards = Card::MASTERS.map do |card_id|
      Card.new(card_id)
    end.shuffle
  end

  def draw
    @cards.shift
  end
end

class Hand
  HANDS_HIGH_CARD = 1
  HANDS_ONE_PAIR = 2
  HANDS_TWO_PAIR = 3
  HANDS_THREE_OF_A_KIND = 4
  HANDS_STRAIGHT = 5
  HANDS_FLUSH = 6
  HANDS_FULL_HOUSE = 7
  HANDS_FOUR_OF_A_KIND = 8
  HANDS_STRAIGHT_FLUSH = 9

  # NOTE: cards.size >= 5

  def self.detect_hands_one_pair(cards)
    grouped_cards_for_2 = cards.group_by(&:strength).select { |k, v| v.size == 2 }
    return nil unless grouped_cards_for_2.size >= 1
    grouped_cards_for_2.sort_by { |k,v| k }.slice(0,1).map { |m| m[1] }.flatten # TODO: refactor
  end

  def self.detect_hands_two_pair(cards)
    grouped_cards_for_2 = cards.group_by(&:strength).select { |k, v| v.size == 2 }
    return nil unless grouped_cards_for_2.size >= 2
    grouped_cards_for_2.sort_by { |k,v| k }.slice(0,2).map { |m| m[1] }.flatten # TODO: refactor
  end

  def self.detect_hands_three_of_a_kind(cards)
    grouped_cards = cards.group_by(&:strength).select { |k, v| v.size == 3 }
    return nil if grouped_cards.empty?
    four_cards = grouped_cards.max_by { |k,v| k }[1]
  end

  def self.detect_hands_straight(cards)
    highest_rank = cards.max_by(&:strength).rank
    if highest_rank == 'A'
      return nil unless [2,3,4,5,14] == cards.map(&:strength).sort # TODO
    else
      sorted_ranks = cards.map(&:strength).sort
      prev_rank = sorted_ranks[0] - 1
      sorted_ranks.each do |rank|
        return nil unless rank == prev_rank + 1
        prev_rank = rank
      end
    end
    cards
  end

  def self.detect_hands_flush(cards)
    return nil unless cards.map(&:suit).uniq.size == 1
    flush_cards = cards
  end

  def self.detect_hands_full_house(cards)
    grouped_cards = cards.group_by(&:rank)
    grouped_cards_for_3 = cards.group_by(&:rank).select { |k, v| v.size == 3 }
    grouped_cards_for_2 = cards.group_by(&:rank).select { |k, v| v.size == 2 }
    return nil if grouped_cards_for_3.empty?
    return nil if grouped_cards_for_2.empty?
    full_house_cards = grouped_cards_for_3.max_by { |k,v| k }[1] + grouped_cards_for_2.max_by { |k,v| k }[1]
  end

  def self.detect_hands_four_of_a_kind(cards)
    grouped_cards = cards.group_by(&:rank).select { |k, v| v.size == 4 }
    return nil if grouped_cards.empty?
    four_cards = grouped_cards.max_by { |k,v| k }[1]
  end

  def self.detect_hands_straight_flush(cards)
    return nil unless flush_cards = self.detect_hands_flush(cards)
    return nil unless straight_flush_cards = self.detect_hands_straight(flush_cards)
    straight_flush_cards
  end

  def self.evaluate_hands(cards)
    best_result = { hands: HANDS_HIGH_CARD }
    cards.combination(5).each do |cards_5|
      res = self.evaluate_hands_5(cards_5)
      if best_result[:hands] <= res[:hands]
        best_result = res
      end
    end
    best_result
  end

  def self.evaluate_hands_5(cards)
    result = {}

    hands = nil
    msg = cards.map do |card|
      "#{card.rank}#{card.suit}"
    end.join(" ") + ": "

    if cards_sf = detect_hands_straight_flush(cards)
      hands = HANDS_STRAIGHT_FLUSH
      if [2,3,4,5,14] == cards_sf.map(&:strength).sort
        msg += "straignt flush, 5"
      else
        msg += "straignt flush, #{cards_sf.max_by(&:strength).rank}"
      end
    elsif cards_4 = detect_hands_four_of_a_kind(cards)
      hands = HANDS_FOUR_OF_A_KIND
      msg += "four of a kind, #{cards_4.first.rank}"
    elsif cards_fh = detect_hands_full_house(cards)
      hands = HANDS_FULL_HOUSE
      msg += "full house, #{cards_fh.max_by(&:strength).rank} #{cards_fh.min_by(&:strength).rank}"
    elsif cards_f = detect_hands_flush(cards)
      hands = HANDS_FLUSH
      msg += "flush, '#{cards_f.first.suit}'"
    elsif cards_s = detect_hands_straight(cards)
      hands = HANDS_STRAIGHT
      if [2,3,4,5,14] == cards_s.map(&:strength).sort
        msg += "straignt, 5"
      else
        msg += "straignt, #{cards_s.max_by(&:strength).rank}"
      end
    elsif cards_3 = detect_hands_three_of_a_kind(cards)
      hands = HANDS_THREE_OF_A_KIND
      msg += "three of a kind, #{cards_3.first.rank}"
    elsif cards_2p = detect_hands_two_pair(cards)
      hands = HANDS_TWO_PAIR
      msg += "two pair, #{cards_2p.max_by(&:strength).rank} #{cards_2p.min_by(&:strength).rank}"
    elsif cards_p = detect_hands_one_pair(cards)
      hands = HANDS_ONE_PAIR
      msg += "one pair, #{cards_p.first.rank}"
    else
      hands = HANDS_HIGH_CARD
      highest_rank = cards.max_by(&:strength).rank
      msg += "high card, #{highest_rank}"
    end
    result[:hands] = hands
    result[:msg] = msg
    result
  end
end
