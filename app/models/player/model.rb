# frozen_string_literal: true

module Player
  class Model
    attr_reader :id, :health, :nickname

    def initialize(cards:, id: nil, nickname: nil)
      @id = id
      @nickname = nickname || 'N/A'
      @cards = cards
      @health = 40
      @using_cards = []
    end

    def dead?
      @health.zero?
    end

    def prepare_attack(cards:)
      @using_cards = @cards.select { |card| cards.include?(card.id) && card.attack.positive? }.uniq
      @cards = remove_used_cards

      { skipped_attack: @using_cards.empty? }
    end

    def defend(attacker:, defense_cards:)
      @using_cards = @cards.select { |card| defense_cards.include?(card.id) && card.defense.positive? }.uniq
      @cards = remove_used_cards

      attack = attacker.using_cards.sum(&:attack)
      defense = @using_cards.sum(&:defense)

      receive_damage(attack - defense)
    end

    def refill_cards(all_cards:)
      count_to_refill = [@using_cards.length, 1].max

      @cards.push(*all_cards.sample(count_to_refill))

      @using_cards = []
    end

    def cards
      @cards.dup
    end

    def using_cards
      @using_cards.dup
    end

    private

    def remove_used_cards
      seen = {}
      @cards.reject do |card|
        should_remove = @using_cards.include?(card) && !seen.include?(card)
        seen[card] = true if should_remove

        should_remove
      end
    end

    def receive_damage(damage)
      return if damage.nil?
      return unless damage.positive?

      @health = [health - damage, 0].max
    end
  end
end
