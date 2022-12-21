# frozen_string_literal: true

module Player
  class Model
    attr_reader :id, :health, :nickname
    attr_accessor :cards

    def initialize(cards:, id: nil, nickname: nil)
      @id = id
      @nickname = nickname || 'N/A'
      @cards = cards
      @health = 100
    end
  end
end
