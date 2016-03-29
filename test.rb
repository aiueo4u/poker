require './poker'

=begin
cards = []
[
  '9X8sTc2d3c', # high card
  '3s3c9hThKd', # one pair
  '8h4s8sKs4c', # two pair
  'Ac8cAh9hAd', # three of a kind
  '8h9hTsJsQd', # straight
  'Ah2s5c4d3h', # straight(A-5)
  '2s3s7s8sKs', # flush
  '8s5s8c5c8d', # full house
  '8s8d2c8c8h', # four of a kind
  '6s7s8s9sTs', # straight flush
  'Ac5c4c3c2c', # straight flush(A-5)
].each do |hand_string|
  cards = []
  hand_string.scan(/.{1,2}/).each do |card_id|
    cards << Card.new(card_id)
  end
  res = Hand.evaluate_hands(cards)
  puts res[:msg]
end
=end

class Statistics
  def initialize
    @history = []
  end

  def log(res)
    @history << res
  end

  def show
    puts "------------------------------------------------"
    puts "  show statisticw       "
    puts "------------------------------------------------"
    puts " trials: #{@history.size} "

    counts_hands_high_card = @history.select { |h| h[:hands] == Hand::HANDS_HIGH_CARD }.size
    puts " Hands of high card: #{counts_hands_high_card} (#{counts_hands_high_card * 100.0 / @history.size} %)"
    counts_hands_one_pair = @history.select { |h| h[:hands] == Hand::HANDS_ONE_PAIR }.size
    puts " Hands of one pair: #{counts_hands_one_pair}"
    counts_hands_two_pair = @history.select { |h| h[:hands] == Hand::HANDS_TWO_PAIR }.size
    puts " Hands of one pair: #{counts_hands_two_pair}"
    counts_hands_three_of_a_kind = @history.select { |h| h[:hands] == Hand::HANDS_THREE_OF_A_KIND }.size
    puts " Hands of three of a kind: #{counts_hands_three_of_a_kind}"
  end
end

stat = Statistics.new
0.times.each do
  deck = Deck.new
  cards = 7.times.map { deck.draw }
  res = Hand.evaluate_hands(cards)
  puts "Result of [ #{cards.map { |c| "#{c.rank}#{c.suit}" }.join(' ')} ] --->>> #{res[:msg]}"
  stat.log res
end

count = 0
while true
  count += 1
  puts "---------------------------------"
  puts "The game #{count} start"
  puts "---------------------------------"
  puts ""

  deck = Deck.new
  player_cards = 2.times.map { deck.draw }
  puts "Your cards: #{player_cards.map(&:id).join(' ')}"
  other_player_cards_1 = 2.times.map { deck.draw }
  other_player_cards_2 = 2.times.map { deck.draw }
  other_player_cards_3 = 2.times.map { deck.draw }

  gets # wait

  # flop
  board_cards = 3.times.map { deck.draw }
  puts "Board cards: #{board_cards.map(&:id).join(' ')}"

  gets # wait

  # turn
  board_cards << deck.draw
  puts "Board cards: #{board_cards.map(&:id).join(' ')}"
  gets # wait

  # river
  board_cards << deck.draw
  puts "Board cards: #{board_cards.map(&:id).join(' ')}"

  gets # wait

  res = Hand.evaluate_hands(player_cards + board_cards)
  puts "You\t#{player_cards.map(&:id).join(' ')}\t#{res[:msg]}"
  res = Hand.evaluate_hands(other_player_cards_1 + board_cards)
  puts "Other_1\t#{other_player_cards_1.map(&:id).join(' ')}\t#{res[:msg]}"
  res = Hand.evaluate_hands(other_player_cards_2 + board_cards)
  puts "Other_2\t#{other_player_cards_2.map(&:id).join(' ')}\t#{res[:msg]}"
  res = Hand.evaluate_hands(other_player_cards_3 + board_cards)
  puts "Other_3\t#{other_player_cards_3.map(&:id).join(' ')}\t#{res[:msg]}"

  gets
end


# stat.show

=begin
cards = []
[
  '5c 6c 9s 8s Tc 2d 3c', # high card, T
  'Ac 2c 3s 3c 9h Th Kd', # one pair, 3
  'Ac 2c 8h 4s 8s Ks 4c', # two pair, 8 4
  '2s 3d Ac 8c Ah 9h Ad', # three of a kind, A
  'Ac 2c 8h 9h Ts Js Qd', # straight, Q
  'Js Ks Ah 2s 5c 4d 3h', # straight, 5
  'Jc Kc 2s 3s 7s 8s Ks', # flush, 's'
  '2s 5d 8s 5s 8c 5c 8d', # full house, 8 5
  '3c 4c 8s 8d 2c 8c 8h', # four of a kind, 8
  '2c 3c 6s 7s 8s 9s Ts', # straight flush, 's' T
  '8s 9s Ac 5c 4c 3c 2c', # straight flush, 'c' 5
].each do |hand_string|
  cards = []
  hand_string.gsub(' ', '').scan(/.{1,2}/).each do |card_id|
    cards << Card.new(card_id)
  end
  res = Hand.evaluate_hands(cards)
  puts "Result of [ #{hand_string} ] --->>> #{res[:msg]}"
end
=end
