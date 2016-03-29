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
    server = TCPServer.open(0, @port)
    @listening_sockets = [server]

    # TODO: 3 players
    puts "waiting 3 players..."
    player_socks = {}
    hoge = {}
    3.times.each do |no|
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
    while true
      puts "---------------------------------"
      puts "The game #{count} start"
      puts "---------------------------------"
      puts ""

      deck = Poker::Deck.new
      player_cards = Hash.new { |h,k| h[k] = [] }
      pot_amount = 0

      # deal cards to players
      player_manager.agent_map.each do |no, agent|
        player_cards[no] << deck.draw
      end
      player_manager.agent_map.each do |no, agent|
        player_cards[no] << deck.draw
      end
      player_manager.agent_map.each do |no, agent|
        agent.comm(type: 'deal', cards: player_cards[no].map(&:id))
      end

      preflop_player_actions = {}

      # SB

      # BB

      # [ Preflop ]
      action_manager = ActionManager.new(player_manager.agent_map, pot_amount)
      action_manager.hoge
      # action_manager.result
      pot_amount = action_manager.pot_amount

      # broadcast(player_socks, msg: 'hogehogehoge')

      # flop
      board_cards = [deck.draw, deck.draw, deck.draw]
      puts "Flop cards: #{board_cards.map(&:id).join(' ')}"

      # turn
      board_cards << deck.draw
      puts "Turn cards: #{board_cards.map(&:id).join(' ')}"

      # river
      board_cards << deck.draw
      puts "River cards: #{board_cards.map(&:id).join(' ')}"

      # show result
      results = Poker::Hand.evaluate_cards(player_cards, board_cards)
      results.each do |no, result|
        puts result[:hand].evaluate[:msg]
      end

      strongest_numbers = []
      results.each do |no, result|
        if strongest_numbers.empty?
          strongest_numbers << no
          next
        end

        strongest_number = strongest_numbers.first
        strongest_hand = results[strongest_number][:hand]
        if Poker::Hand.equal?(result[:hand], strongest_hand)
          strongest_numbers << no
        elsif Poker::Hand.stronger?(result[:hand], strongest_hand)
          strongest_numbers = [no]
        end
      end

      puts "win: #{strongest_numbers.join(',')}"
      puts "got: #{pot_amount / strongest_numbers.size}"

      strongest_numbers.each do |no|
        agent = player_manager.agent_map[no]
        agent.seat.player.stack += pot_amount / strongest_numbers.size
        agent.comm(type: 'win', amount: pot_amount / strongest_numbers.size)
      end

      count += 1
      break if count > 5
      puts "next game..."
      gets # push enter to next game...
    end

    player_socks.each do |no, sock|
      sock.puts(type: 'close')
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
