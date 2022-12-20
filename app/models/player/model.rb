module Player
  class Model
    attr_reader :id, :health, :nickname
    attr_accessor :cards

    def initialize(id: nil, nickname: nil, cards:)
      @id = id
      @nickname = nickname || 'N/A'
      @cards = cards
      @health = 100
    end
  end
end