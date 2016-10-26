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
  attr_accessor :board_cards

  def initialize(agent_map, pot_amount, button_seat_no)
    @agent_map = agent_map
    @plalyer_statuses = {}

    # １ゲーム全ての履歴情報
    @current_phase_action_id = 0
    @game_data = {
      pot_amount: 0,
      players: [],
      board_cards: [],
      preflop_actions: [],
      flop_actions: [],
      turn_actions: [],
      river_actions: []
    }

    positions = (0..agent_map.keys.size - 1).to_a # 0: SB, 1: BB, 2: UTG, ...
    @game_data[:players] = agent_map.map do |seat_no, agent|
      {
        seat_no: seat_no,
        position: positions[(seat_no - button_seat_no) % positions.size],
        player_name: agent.seat.player.name,
        stack: agent.seat.player.stack,
        state: "active", # or "fold"
        phase_amount: 0,
      }
    end
    @button_seat_no = button_seat_no
    @current_blind = 10 # big blind amount
    @player_num = @agent_map.keys.size
    @deck = Poker::Deck.new
    @player_cards = Hash.new { |h, k| h[k] = [] }
    @board_cards = []
  end

  def deal_cards
    @agent_map.each do |seat_no, agent|
      @player_cards[seat_no] << @deck.draw
    end
    @agent_map.each do |seat_no, agent|
      @player_cards[seat_no] << @deck.draw
    end
    @agent_map.each do |seat_no, agent|
      agent.comm(type: 'deal', cards: @player_cards[seat_no].map(&:id))
    end
  end

  def active_player_cards
    @player_cards.select { |seat_no, cards| seat_no.in?(active_seat_nos) }
  end

  def pot_amount
    @game_data[:pot_amount]
  end

  def active_seat_nos
    @game_data[:players].select { |player| player[:state] != 'fold' }.map { |player| player[:seat_no] }
  end

  def next_agents(next_seat_no)
    agents = @agent_map.values.slice(next_seat_no..-1)
    if next_seat_no > 0
      agents += @agent_map.values.slice(0..(next_seat_no-1))
    end

    # アクティブなプレイヤーのみ
    agents = agents.select { |a| a.seat.no.in?(active_seat_nos) }
    agents
  end

  def process_phase(phase)
    @current_phase = phase

    if @current_phase == 'preflop'
      small_blind
      big_blind
    elsif @current_phase == 'flop'
      @board_cards = 3.times.map { @deck.draw }
      puts "[Board] #{@board_cards.map(&:id).join(' ')}"
    elsif @current_phase == 'turn'
      @board_cards << @deck.draw
      puts "[Board] #{@board_cards.map(&:id).join(' ')}"
    elsif @current_phase == 'river'
      @board_cards << @deck.draw
      puts "[Board] #{@board_cards.map(&:id).join(' ')}"
    end
    @game_data[:board_cards] = @board_cards.map(&:id).join(' ')

    # UTGのプレイヤーから
    agents = next_agents((@button_seat_no + 3) % @player_num)

    loop do
      break unless each_action(agents)

      # 最後にベット or レイズのアクションをした次のプレイヤーから
      agents = next_agents((@last_aggressive_action_seat_no + 1) % @player_num)
      agents.slice!(-1) # 最後の要素＝ベットプレイヤーを除外
    end 
  end

  # agent_map: bet or raiseしたプレイヤー以外　
  def each_action(agents)
    puts "nos: #{agents.map(&:seat).map(&:no).join(',')}"

    agents.each do |agent|
      # プレイヤーにアクションを促し処理する
      action = one_action(agent)

      notify_game_data

      puts "[Player] #{agent.seat.player.name}'s action: #{action[:action]}, amount: #{action[:amount]}"
      if action[:action] == 'bet' || action[:action] == 'raise'
        @last_aggressive_action_seat_no = agent.seat.no
        return true
      end
    end
    false
  end

  # プレイヤー全員に最新のゲームデータを配信
  def notify_game_data
    @agent_map.each { |_, agent| agent.comm(type: 'notify', game_data: @game_data) }
  end

  def one_action(agent)
    # クライアント通信: アクションを得る
    res = agent.comm(type: 'action', game_data: @game_data)
    action = {}
    action[:action] = res[:action]
    action[:amount] = res[:amount]
    process_action(agent, action)
    action
  end

  # クライアントからのアクションをサーバ側で処理する
  def process_action(agent, action)
    # ゲームデータのプレイヤー情報取り出す
    player_game_data = @game_data[:players].find { |player| player[:seat_no] == agent.seat.no }

    # 現在のフェーズでの最高ベット額
    largest_phase_amount = @game_data[:players].map { |player| player[:phase_amount] }.max

    # 今回のアクションでポットに追加される額
    bet_amount = 0

    case action[:action]
    when 'bet'
      bet_amount = action[:amount]
    when 'call'
      # 現在のフェーズで既にベットしてポットに入っている額
      phase_amount = player_game_data[:phase_amount] || 0

      # 現在のフェーズでの最高ベッド額から差し引いた分がコールに必要な額
      bet_amount = largest_phase_amount - phase_amount
    when 'check'
      # 何もしない
    when 'raise'
      # 現在のフェーズで既にベットしてポットに入っている額
      phase_amount = player_game_data[:phase_amount] || 0

      # 現在のフェーズで既にベットしてポットに入っている額をレイズ額（絶対値）から差し引いた額が追加分
      bet_amount = action[:amount] - phase_amount
    when 'fold'
      # 何もしない
    when 'small_blind'
      bet_amount = @current_blind / 2
    when 'big_blind'
      bet_amount = @current_blind
    end

    # ゲームデータのプレイヤー情報を更新
    player_game_data[:phase_amount] += bet_amount
    player_game_data[:stack] -= bet_amount
    player_game_data[:state] = action[:action]

    # ゲームデータのアクション履歴更新
    @current_phase_action_id += 1
    @game_data[:pot_amount] += bet_amount
    @game_data["#{@current_phase}_actions".to_sym] << {
        "id": @current_phase_action_id,
        "seat_no": agent.seat.no,
        "action": action[:action],
        "amount": bet_amount
    }
    # puts "[GAME_DATA] #{JSON.pretty_generate(@game_data)}"

    # サーバ側のプレイヤーデータを更新
    agent.seat.player.stack -= bet_amount
  end

  private

  def small_blind
    seat_no = (@button_seat_no + 1) % @player_num
    agent = @agent_map[seat_no]
    process_action(agent, action: 'small_blind')
    res = agent.comm(type: 'info', msg: "You paid small blind.")
    notify_game_data
  end

  def big_blind
    seat_no = (@button_seat_no + 2) % @player_num
    agent = @agent_map[seat_no]
    process_action(agent, action: 'big_blind')
    res = agent.comm(type: 'info', msg: "You paid big blind.")
    notify_game_data
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

  def comm(hash)
    # puts "From server to client: #{hash.to_s}"
    @sock.puts(JSON.generate(hash))
    res = gets
    # puts "From client: #{res}"
    res
  end
end
