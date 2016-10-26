require './player_agent'

agent = PlayerAgent.new

loop do
  puts "waiting....."
  response = agent.gets

  # puts "From Server: #{response}"

  if response[:game_data]
    puts "----- Current Status -----"
    response[:game_data][:players].each do |player|
      puts "[#{player[:seat_no]}] state:#{player[:state]}\tphase_amount:#{player[:phase_amount]}\tstack:#{player[:stack]}"
    end
    puts "--------------------------"
  end

  case response[:type]
  when 'win'
    puts "you win!"
    agent.win(response[:amount])
    agent.ping
  when 'broadcast'
    puts "broadcast received"
    p response
    agent.ping
  when 'action'
    while true
      puts "Board cards: #{response[:game_data][:board_cards]}"
      puts "Your cards: #{@cards}"
      puts 'Your action:'
      puts '1: check'
      puts '2: bet'
      puts '3: call'
      puts '4: raise'
      puts '5: fold'

      player_input = gets.chomp

      case player_input
      when '1' # check
        puts "check"
        agent.puts(action: 'check')
      when '2' # bet
        puts "How much do you bet?"
        amount = gets.chomp.to_i
        puts "bet $#{amount}"
        agent.bet(amount)
      when '3' # call
        puts "call"
        agent.call
      when '4' # raise
        puts "How much do you raise?"
        amount = gets.chomp.to_i
        puts "raise $#{amount}"
        agent.raise(amount)
      when '5' # fold
        agent.puts(action: 'fold')
      else
        puts 'invalid command!'
        next
      end
      break
    end
  when 'deal'
    @cards = response[:cards]
    puts "dealed cards: #{@cards}"
    agent.puts({})
  when 'info'
    puts "#{response[:msg]}"
    agent.puts({})
  when 'close'
    agent.puts({})
    agent.close
    break
  else
    # puts response
    agent.puts({})
  end
end
