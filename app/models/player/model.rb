# frozen_string_literal: true

module Player
  class Model
    attr_reader :id, :health, :nickname

    def initialize(cards:, id: nil, nickname: nil)
      @id = id
      @nickname = nickname || 'N/A'
      @cards = cards
      @health = 25
      @using_cards = []
    end

    def dead?
      @health.zero?
    end

    def prepare_attack(cards:)
      @using_cards = get_valid_attack_cards(cards)
      @cards = remove_used_cards

      used_health_potion = @using_cards.any? { |c| c.is_a?(::Card::HealthPotion) }

      if used_health_potion
        @health = [@health + @using_cards.sum(&:value), 25].min
      end

      { skipped_attack: @using_cards.empty? || used_health_potion }
    end

    def defend(attacker:, defense_cards:)
      @using_cards = get_valid_defense_cards(defense_cards)
      @cards = remove_used_cards

      used_health_potion = @using_cards.any? { |c| c.is_a?(::Card::HealthPotion) }

      attack = attacker.using_cards.sum(&:value)
      defense = used_health_potion ? 0 : @using_cards.sum(&:value)

      @health += @using_cards.sum(&:value) if used_health_potion

      receive_damage(attack - defense)
    end

    def refill_cards(all_cards:, was_defense_turn: false)
      cards_to_add_if_empty_cards = was_defense_turn ? 0 : 1
      count_to_refill = [@using_cards.length, cards_to_add_if_empty_cards].max

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

    def get_valid_attack_cards(cards)
      valid_cards = @cards.select { |card| cards.include?(card.id) && (card.is_a?(::Card::Weapon) || card.is_a?(::Card::HealthPotion)) }.uniq

      return [get_max_health_potion(valid_cards)] if valid_cards.any? { |c| c.is_a?(::Card::HealthPotion) }

      non_stackables = valid_cards.reject(&:stackable)

      return valid_cards unless non_stackables.length > 1

      non_stackable = non_stackables.max_by(&:value)
      valid_cards.select(&:stackable) << non_stackable
    end

    def get_valid_defense_cards(cards)
      valid_cards = @cards.select { |card| cards.include?(card.id) && (card.is_a?(::Card::Armor) || card.is_a?(::Card::HealthPotion)) }.uniq

      return [get_max_health_potion(valid_cards)] if valid_cards.any? { |c| c.is_a?(::Card::HealthPotion) }

      valid_cards
    end

    def get_max_health_potion(cards)
      cards.select { |c| c.is_a?(::Card::HealthPotion) }.max_by(&:value)
    end

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

      @health = [[health - damage, 0].max, 25].min
    end
  end
end
