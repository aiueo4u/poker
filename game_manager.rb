require 'socket'
require 'json'
require_relative 'poker'
require_relative 'lib/poker'

class GameManager
  attr_accessor :max_players

  def initialize(args = {})
    @max_players = args[:max_players] || 3
    @port = 12345

    @seats = []
    @max_players.times.each do |i|
      @seats << {
        no: i,
        player: nil,
      }
    end
  end

  def broadcast(socks, hash)
    hash = hash.merge(type: 'broadcast')
    socks.each do |no, sock|
      sock.puts(hash)
    end
    socks.each do |no, sock|
      sock.gets
    end
  end

  def run
    server = TCPServer.new(@port)
    @listening_sockets = [server]

    # TODO: 3 players
    puts "waiting 4 players..."
    player_socks = {}
    4.times.each do |no|
      sock = server.accept
      sock.puts({ status: 200, no: no}.to_json)
      req = JSON.parse(sock.gets, symbolize_names: true)
      player_name = req[:name] # TODO: JWT
      player_stack = Random.rand(400).to_i + 800
      puts "Player '#{player_name}' joined with $#{player_stack}"
      player = Player.new(player_name, player_stack)

      seat = Seat.new(no, player)
      player_socks[no] = ServerAgent.new(sock, seat)
      sock.puts({ stack: player_stack }.to_json)
    end

    player_manager = PlayerManager.new(player_socks)

    count = 0
    button_seat_no = 0 # 最初ボタンのプレイヤーのシート番号

    while true
      puts "---------------------------------"
      puts "The game #{count} start"
      puts "---------------------------------"
      puts ""

      pot_amount = 0
      deck = Poker::Deck.new

      action_manager = ActionManager.new(player_manager.agent_map, pot_amount, button_seat_no)

      # 各プレイヤーにカードを配る
      action_manager.deal_cards

      loop do
        # Phase: プリフロップ
        action_manager.process_phase('preflop')
        break if action_manager.active_seat_nos.size == 1

        # Phase: フロップ
        action_manager.process_phase('flop')
        break if action_manager.active_seat_nos.size == 1

        # Phase: ターン
        action_manager.process_phase('turn')
        break if action_manager.active_seat_nos.size == 1

        # Phase: リバー
        action_manager.process_phase('river')
        break
      end

      #
      # 結果
      #
      puts "---------- result ----------"
      pot_amount = action_manager.pot_amount

      if action_manager.active_seat_nos.size > 1
        results = Poker::Hand.evaluate_cards(action_manager.active_player_cards, action_manager.board_cards)
        # 各プレイヤーの最終ハンド
        results.each do |no, result|
          puts "[Seat #{no + 1}] #{result[:hand].evaluate[:msg]}"
        end

        # ベストハンドのプレイヤーを計算
        best_hands_by_seat_no = Poker::Hand.select_best_hands(results)
        best_hand_seat_nos = best_hands_by_seat_no.keys
      else
        # ショウダウンまで行かずに全員フォールドした場合
        best_hand_seat_nos = action_manager.active_seat_nos
      end

      # ベストハンドプレイヤーにポットを分配
      best_hand_seat_nos.each do |no|
        agent = player_manager.agent_map[no]
        agent.seat.player.stack += pot_amount / best_hand_seat_nos.size
        agent.comm(type: 'win', amount: pot_amount / best_hand_seat_nos.size)
      end

      puts "Win Players: #{best_hand_seat_nos.map { |no| no + 1 }.join(',')}"
      puts "Prize: $#{pot_amount / best_hand_seat_nos.size}"
      puts "----------------------------"

      count += 1
      break if count >= 6
      button_seat_no = (button_seat_no + 1) % player_manager.agent_map.keys.size
      puts "next game..."
      gets # push enter to next game...
    end

    player_manager.agent_map.each do |no, agent|
      agent.comm(type: 'close')
    end
    puts "shutdown..."


    return

    while true
      nsock = select(@listening_sockets)
      puts "ready!"
      next if nsock == nil

      for s in nsock[0]
        if s == @server
          # 新規接続
          accepted_sock = s.accept
          puts "accepted #{s}"
          on_accepted(accepted_sock)
        else
          if s.eof?
            puts "#{s} is gone"
            s.close
            @listening_sockets.delete(s)
          else
            str = s.gets
            sleep 2
            s.write(str)
          end
        end
      end
    end
  end

  # 新規接続を受け付けた時の処理
  def on_accepted(sock)
    # 席が開いているか確認
    empty_seat = @seats.select { |seat| seat[:player] == nil }.first
    if empty_seat
      # 席が開いていた場合
      # empty_seat[:player] = Player.new
      @listening_sockets.push(sock)
    else
      # 開いていなかった場合
      sock.puts "Sorry, no empty seat"
      sock.close
    end
  end
end

manager = GameManager.new
manager.run
