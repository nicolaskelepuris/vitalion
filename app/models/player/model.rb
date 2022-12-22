# frozen_string_literal: true

module Player
  class Model
    attr_reader :id, :health, :nickname
    attr_accessor :cards, :current_attack, :current_defense

    def initialize(cards:, id: nil, nickname: nil)
      @id = id
      @nickname = nickname || 'N/A'
      @cards = cards
      @health = 100
      @current_attack = []
      @current_defense = []
    end
  end
end
