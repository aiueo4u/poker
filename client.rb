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
    puts 'action?[bc]'
    res = gets.chomp
    case res
    when 'b'
      puts "How much do you bet?"
      agent.bet(gets.chomp.to_i)
    when 'c'
      puts "check"
      agent.puts(action: 'check')
    else
      agent.puts(action: 'fold')
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
