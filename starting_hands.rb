require_relative 'poker'
require_relative 'lib/poker'

TRIAL = 1000 * 1000

statistics = {}

pocket_count = 0
suited_count = 0

TRIAL.times.each do |i|
  deck = Poker::Deck.new
  cards = 2.times.map { deck.draw }
  is_suited = cards.map(&:suit).uniq.size == 1
  is_pocket = cards.map(&:rank).uniq.size == 1 ? true : false
  msg = ''
  msg += cards.map(&:rank).sort.join('')
  msg += is_suited ? 's' : 'o'
  strength = cards.map(&:strength).sum
  statistics[msg] ||= {}
  statistics[msg]['count'] ||= 0
  statistics[msg]['count'] += 1
  statistics[msg]['is_poket'] ||= is_pocket
  statistics[msg]['strength'] ||= strength
  pocket_count += 1 if is_pocket
  suited_count += 1 if is_suited
end

statistics.sort_by { |k,v| v['strength'] }.each do |ids,s|
  print "#{ids}: #{s['count']}\t#{s['count'] * 10000.0 / (TRIAL * 100)}%\n"
end
puts "trial: #{TRIAL}"
puts "pocket: #{pocket_count}(#{pocket_count * 10000.0 / (TRIAL * 100)}%)"
puts "suited: #{suited_count}(#{suited_count * 10000.0 / (TRIAL * 100)}%)"
