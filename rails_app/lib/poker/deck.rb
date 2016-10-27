module Poker
  class Deck
    def initialize
      @cards = Card::MASTERS.map do |card_id|
        Card.new(card_id)
      end.shuffle
    end

    def draw
      drawn_card = @cards.shift
      if drawn_card.nil?
        raise 'deck is empty. cannot draw any more'
      end
      drawn_card
    end
  end
end
