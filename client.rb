require 'socket'
require 'json'
require './poker'

agent = PlayerAgent.new

while true
  puts "name: #{agent.player.name}, stack: #{agent.player.stack}"
  response = agent.gets
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
      puts "prev action: #{response[:prev_action]}"
      puts 'Your action:'
      puts '1: check'
      puts '2: bet'
      puts '3: call'
      puts '4: raise'
      puts '5: fold'
      res = gets.chomp
      case res
      when '1' # check
        puts "check"
        agent.puts(action: 'check')
      when '2' # bet
        puts "How much do you bet?"
        amount = gets.chomp.to_i
        puts "bet $#{amount}"
        agent.bet(amount)
      when '3' # call
      when '4' # raise
      when '5' # fold
        agent.puts(action: 'fold')
      else
        puts 'invalid command!'
        next
      end
      break
    end
  when 'deal'
    puts "dealed cards: #{response[:cards]}"
    agent.puts({})
  when 'close'
    agent.close
    break
  else
    puts response
    agent.puts({})
  end
end
