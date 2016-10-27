module Poker
  class Card
    # id: 'As', '3h', ...
    # rank: 'A', '2', '3', ..., '9', 'T', 'J', 'Q', 'K'
    # suit: 's', 'c', 'h', 'd'
    # strength: 14, 2, 3, ..., 10, 11, 12, 13
    attr_accessor :id, :rank, :suit, :strength

    MASTERS = %w(
      As 2s 3s 4s 5s 6s 7s 8s 9s Ts Js Qs Ks
      Ah 2h 3h 4h 5h 6h 7h 8h 9h Th Jh Qh Kh
      Ac 2c 3c 4c 5c 6c 7c 8c 9c Tc Jc Qc Kc
      Ad 2d 3d 4d 5d 6d 7d 8d 9d Td Jd Qd Kd
    ).freeze

    # TODO: validation
    def initialize(id)
      unless id.in?(MASTERS)
        raise "invalid id: #{id}"
      end

      @id = id
      @rank = id[0]
      @suit = id[1]
      @strength =
        case id[0]
        when 'A'
          14
        when 'T'
          10
        when 'J'
          11
        when 'Q'
          12
        when 'K'
          13
        else
          id[0].to_i
        end
    end
  end
end
