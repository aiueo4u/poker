module Poker
  class Deck
    def initialize
      @cards = Card::MASTERS.map do |card_id|
        Card.new(card_id)
      end.shuffle
    end

    def draw
      @cards.shift
    end
  end
end
