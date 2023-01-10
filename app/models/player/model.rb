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

    def dead?
      @health.zero?
    end

    def prepare_attack(cards:)
      @current_attack = @cards.select { |card| cards.include?(card.id) && card.attack.positive? }.uniq
      @cards -= @current_attack

      { skipped_attack: @current_attack.empty? }
    end

    def defend(attacker:, defense_cards:)
      @current_defense = @cards.select { |card| defense_cards.include?(card.id) && card.defense.positive? }.uniq
      @cards -= @current_defense

      attack = attacker.current_attack.sum(&:attack)
      defense = @current_defense.sum(&:defense)

      receive_damage(attack - defense)
    end

    private

    def receive_damage(damage)
      return if damage.nil?
      return unless damage.positive?

      @health = [health - damage, 0].max
    end
  end
end
