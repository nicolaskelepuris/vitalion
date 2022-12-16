module Player
  class Model
    attr_reader :id, :health
    attr_accessor :cards

    def initialize(id: nil, cards:)
      @id = id
      @cards = cards
      @health = 100
    end
  end
end