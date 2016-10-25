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
  def initialize(agent_map, pot_amount, button_seat_no)
    @agent_map = agent_map
    @plalyer_statuses = {}

    # １ゲーム全ての履歴情報
    @current_phase_action_id = 0
    @game_data = {
      pot_amount: 0,
      players: [],
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
        state: "active",
        phase_amount: 0,
      }
    end
    @current_base_no = button_seat_no

    @history = []
  end

  def pot_amount
    @game_data[:pot_amount]
  end

  def result
    puts "HISTORY:"
    p @history
    puts "last actions: #{ @history.slice(@current_history_index..-1)}"
  end

  def hoge(phase)
    @current_history_index ||= 0
    @current_phase = phase

    # TODO: UTGのプレイヤーから
    agents = @agent_map.values.slice(@current_base_no..-1)
    if @current_base_no > 0
      agents += @agent_map.values.slice(0..(@current_base_no-1))
    end

    while true
      unless each_action(agents)
        break
      end
      agents = []
      # ベット or レイズのアクションをした次のプレイヤーから
      if @current_base_no + 1 < @agent_map.keys.size # 最後じゃない場合
        next_seat_no = (@current_base_no + 1) % @agent_map.keys.size
        agents += @agent_map.values.slice(next_seat_no..-1)
      end

      # ベット or レイズのアクションをした手前のプレイヤーまで
      if @current_base_no > 0 # 先頭じゃない場合
        prev_seat_no = (@current_base_no - 1) % @agent_map.keys.size
        agents += @agent_map.values.slice(0..prev_seat_no)
      end

      # フォールド済みのプレイヤーを除外
      folded_seat_nos = @game_data[:players].select { |player| player[:state] == 'fold' }.map { |player| player[:seat_no] }
      agents = agents.select { |a| !a.seat.no.in?(folded_seat_nos) }
    end 
  end

  # agent_map: bet or raiseしたプレイヤー以外　
  def each_action(agents)
    puts "ENTER: each_action, current_history_index: #{@current_history_index}, current_base_no: #{@current_base_no}"
    puts "nos: #{agents.map(&:seat).map(&:no).join(',')}"

    agents.each do |agent|
      # プレイヤーにアクションを促し処理する
      action = one_action(agent)

      # プレイヤー全員に最新のゲームデータを配信
      @agent_map.each { |_, a| a.comm(type: 'refresh', game_data: @game_data) }

      @history << action
      puts "[Player] #{agent.seat.player.name}'s action: #{action[:action]}, amount: #{action[:amount]}"
      if action[:action] == 'bet' || action[:action] == 'raise'
        @current_history_index = @history.size - 1
        @current_base_no = agent.seat.no
        return true
      end
    end
    false
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
    puts "[GAME_DATA] #{JSON.pretty_generate(@game_data)}"

    # サーバ側のプレイヤーデータを更新
    agent.seat.player.stack -= bet_amount
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
    puts "From server to client: #{hash.to_s}"
    @sock.puts(JSON.generate(hash))
    res = gets
    puts "From client: #{res}"
    res
  end
end
