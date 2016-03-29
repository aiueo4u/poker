module Poker
  class Hand
    HANDS_HIGH_CARD = 1
    HANDS_ONE_PAIR = 2
    HANDS_TWO_PAIR = 3
    HANDS_THREE_OF_A_KIND = 4
    HANDS_STRAIGHT = 5
    HANDS_FLUSH = 6
    HANDS_FULL_HOUSE = 7
    HANDS_FOUR_OF_A_KIND = 8
    HANDS_STRAIGHT_FLUSH = 9

    def initialize(cards)
      raise 'invalid card num' unless cards.size >= 5
      raise 'invalid cards' unless cards.all? { |card| card.is_a?(Card) }
      @cards = cards
    end

    def self.detect_hands_one_pair(cards)
      grouped_cards_for_2 = cards.group_by(&:strength).select { |k, v| v.size == 2 }
      return nil unless grouped_cards_for_2.size >= 1
      grouped_cards_for_2.sort_by { |k,v| k }.slice(0,1).map { |m| m[1] }.flatten # TODO: refactor
    end

    def self.detect_hands_two_pair(cards)
      grouped_cards_for_2 = cards.group_by(&:strength).select { |k, v| v.size == 2 }
      return nil unless grouped_cards_for_2.size >= 2
      grouped_cards_for_2.sort_by { |k,v| k }.slice(0,2).map { |m| m[1] }.flatten # TODO: refactor
    end

    def self.detect_hands_three_of_a_kind(cards)
      grouped_cards = cards.group_by(&:strength).select { |k, v| v.size == 3 }
      return nil if grouped_cards.empty?
      four_cards = grouped_cards.max_by { |k,v| k }[1]
    end

    def self.detect_hands_straight(cards)
      highest_rank = cards.max_by(&:strength).rank
      if highest_rank == 'A'
        return nil unless [2,3,4,5,14] == cards.map(&:strength).sort # TODO
      else
        sorted_ranks = cards.map(&:strength).sort
        prev_rank = sorted_ranks[0] - 1
        sorted_ranks.each do |rank|
          return nil unless rank == prev_rank + 1
          prev_rank = rank
        end
      end
      cards
    end

    def self.detect_hands_flush(cards)
      return nil unless cards.map(&:suit).uniq.size == 1
      flush_cards = cards
    end

    def self.detect_hands_full_house(cards)
      grouped_cards = cards.group_by(&:rank)
      grouped_cards_for_3 = cards.group_by(&:rank).select { |k, v| v.size == 3 }
      grouped_cards_for_2 = cards.group_by(&:rank).select { |k, v| v.size == 2 }
      return nil if grouped_cards_for_3.empty?
      return nil if grouped_cards_for_2.empty?
      full_house_cards = grouped_cards_for_3.max_by { |k,v| k }[1] + grouped_cards_for_2.max_by { |k,v| k }[1]
    end

    def self.detect_hands_four_of_a_kind(cards)
      grouped_cards = cards.group_by(&:rank).select { |k, v| v.size == 4 }
      return nil if grouped_cards.empty?
      four_cards = grouped_cards.max_by { |k,v| k }[1]
    end

    def self.detect_hands_straight_flush(cards)
      return nil unless flush_cards = self.detect_hands_flush(cards)
      return nil unless straight_flush_cards = self.detect_hands_straight(flush_cards)
      straight_flush_cards
    end


    def detect_hands_one_pair
      self.class.detect_hands_one_pair(@cards)
    end
    def detect_hands_two_pair
      self.class.detect_hands_two_pair(@cards)
    end
    def detect_hands_three_of_a_kind
      self.class.detect_hands_three_of_a_kind(@cards)
    end
    def detect_hands_straight
      self.class.detect_hands_straight(@cards)
    end
    def detect_hands_straight
      self.class.detect_hands_straight(@cards)
    end
    def detect_hands_flush
      self.class.detect_hands_flush(@cards)
    end
    def detect_hands_full_house
      self.class.detect_hands_full_house(@cards)
    end
    def detect_hands_four_of_a_kind
      self.class.detect_hands_four_of_a_kind(@cards)
    end
    def detect_hands_straight_flush
      self.class.detect_hands_straight_flush(@cards)
    end

    def self.evaluate_cards(player_cards, board_cards)
      result = {}
      player_cards.each do |no, cards|
        best_hand = nil
        (cards + board_cards).combination(5).each do |cards_5|
          hand = new(cards_5)
          if best_hand.nil? ||  self.stronger?(hand, best_hand)
            best_hand = hand
          end
        end
        result[no] = { hand: best_hand }
      end
      result
    end

    def self.equal?(target, compared)
      target.hands == compared.hands && target.kickers == compared.kickers
    end

    def self.stronger?(target_hand, compared_hand)
      if target_hand.hands > compared_hand.hands
        return true
      elsif target_hand.hands == compared_hand.hands
        target_hand.kickers.each_with_index do |strength, i|
          if strength < compared_hand.kickers[i]
            return false
          elsif strength > compared_hand.kickers[i]
            return true
          else
            # next
          end
        end
      else
        return false
      end
      false
    end

    def hands
      evaluate[:hands]
    end

    def kickers
      evaluate[:kickers]
    end

    def evaluate
      return @result if @result.present?

      @result = {}

      hands = nil
      kickers = []
      msg = @cards.map(&:id).join(" ") + ": "

      if cards_sf = detect_hands_straight_flush
        hands = HANDS_STRAIGHT_FLUSH
        if [2,3,4,5,14] == cards_sf.map(&:strength).sort
          msg += "straignt flush, 5"
          kickers << 5
        else
          msg += "straignt flush, #{cards_sf.max_by(&:strength).rank}"
          kickers << cards_sf.map(&:strength).max
        end
      elsif cards_4 = detect_hands_four_of_a_kind
        hands = HANDS_FOUR_OF_A_KIND
        msg += "four of a kind, #{cards_4.first.rank}"
        kickers << cards_4.first.strength
        kickers << (@cards - cards_4).first.strength
      elsif cards_fh = detect_hands_full_house
        hands = HANDS_FULL_HOUSE
        higher_rank = cards_fh.max_by(&:strength).rank
        lower_rank = cards_fh.min_by(&:strength).rank
        msg += "full house, #{higher_rank} #{lower_rank}"
        kickers << higher_rank
        kickers << lower_rank
      elsif cards_f = detect_hands_flush
        hands = HANDS_FLUSH
        msg += "flush, '#{cards_f.first.suit}'"
        kickers = cards_f.map(&:strength).sort { |a,b| b <=> a }
      elsif cards_s = detect_hands_straight
        hands = HANDS_STRAIGHT
        if [2,3,4,5,14] == cards_s.map(&:strength).sort
          msg += "straignt, 5"
          kickers << 5
        else
          msg += "straignt, #{cards_s.max_by(&:strength).rank}"
          kickers << cards_s.map(&:strength).max
        end
      elsif cards_3 = detect_hands_three_of_a_kind
        hands = HANDS_THREE_OF_A_KIND
        msg += "three of a kind, #{cards_3.first.rank}"
        kickers << cards_3.first.strength
        kickers = kickers + (@cards - cards_3).map(&:strength).sort { |a,b| b <=> a }
      elsif cards_2p = detect_hands_two_pair
        hands = HANDS_TWO_PAIR
        msg += "two pair, #{cards_2p.max_by(&:strength).rank} #{cards_2p.min_by(&:strength).rank}"
        kickers = cards_2p.map(&:strength).sort { |a,b| b <=> a }.uniq
        kickers << (@cards - cards_2p).first.strength
      elsif cards_p = detect_hands_one_pair
        hands = HANDS_ONE_PAIR
        msg += "one pair, #{cards_p.first.rank}"
        kickers << cards_p.first.strength
        kickers = kickers + (@cards - cards_p).map(&:strength).sort { |a,b| b <=> a }
      else
        hands = HANDS_HIGH_CARD
        high_card = @cards.max_by(&:strength)
        msg += "high card, #{high_card.rank}"
        kickers = @cards.map(&:strength).sort { |a,b| b <=> a }
      end
      @result[:hands] = hands
      @result[:msg] = msg
      @result[:kickers] = kickers
      @result
    end
  end
end
