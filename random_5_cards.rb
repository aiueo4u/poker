require_relative 'poker'
require_relative 'lib/poker'

pattern_num = 0
statistics = {}

all_instances = Poker::Card::MASTERS.each_with_object({}) do |master, result|
  result[master] = Poker::Card.new(master)
end

Poker::Card::MASTERS.combination(5).each do |cards|
  card_map = {
    1 => cards.map { |card| all_instances[card] }
  }
  result = Poker::Hand.evaluate_cards(card_map, [])
  statistics[result[1][:hand].hands] ||= 0
  statistics[result[1][:hand].hands] += 1
  pattern_num += 1
  # break if pattern_num > 10000000
end
puts "Pattern num: #{pattern_num}"

statistics.sort_by{ |k,v| k }.each do |strength, count|
  case strength
  when Poker::Hand::HANDS_HIGH_CARD
    puts "High card:\t#{count}\t#{count * 1000000 / pattern_num / 10000.0} %\t#{pattern_num/count}"
  when Poker::Hand::HANDS_ONE_PAIR
    puts "One pair:\t#{count}\t#{count * 1000000 / pattern_num / 10000.0} %\t#{pattern_num/count}"
  when Poker::Hand::HANDS_TWO_PAIR
    puts "Two pair:\t#{count}\t#{count * 1000000 / pattern_num / 10000.0} %\t#{pattern_num/count}"
  when Poker::Hand::HANDS_THREE_OF_A_KIND
    puts "Three of a kind:\t#{count}\t#{count * 1000000 / pattern_num / 10000.0} %\t#{pattern_num/count}"
  when Poker::Hand::HANDS_STRAIGHT
    puts "Straight:\t#{count}\t#{count * 1000000 / pattern_num / 10000.0} %\t#{pattern_num/count}"
  when Poker::Hand::HANDS_FLUSH
    puts "Flush:\t#{count}\t#{count * 1000000 / pattern_num / 10000.0} %\t#{pattern_num/count}"
  when Poker::Hand::HANDS_FULL_HOUSE
    puts "Full house:\t#{count}\t#{count * 1000000 / pattern_num / 10000.0} %\t#{pattern_num/count}"
  when Poker::Hand::HANDS_FOUR_OF_A_KIND
    puts "Four of a kind:\t#{count}\t#{count * 1000000 / pattern_num / 10000.0} %\t#{pattern_num/count}"
  when Poker::Hand::HANDS_STRAIGHT_FLUSH
    puts "Straight flush:\t#{count}\t#{count * 1000000 / pattern_num / 10000.0} %\t#{pattern_num/count}"
  end
end
