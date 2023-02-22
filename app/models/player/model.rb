# frozen_string_literal: true

module Player
  INITIAL_HEALTH = 25

  class Model
    attr_reader :id, :health, :nickname, :remaining_skips_with_attack_cards

    def initialize(cards:, id: nil, nickname: nil)
      @id = id
      @nickname = nickname || 'N/A'
      @cards = cards
      @health = INITIAL_HEALTH
      @using_cards = []
      @remaining_skips_with_attack_cards = 2
    end

    def dead?
      @health.zero?
    end

    def prepare_attack(cards:, all_cards:)
      @using_cards = get_valid_attack_cards(cards)
      @cards = remove_used_cards     

      has_attack_cards = @cards.any? { |c| attack_cards_types.has_key?(c.type) }

      if @using_cards.empty?      
        @cards.push(all_cards.sample) if !has_attack_cards

        if has_attack_cards && @remaining_skips_with_attack_cards.positive?
          @remaining_skips_with_attack_cards -= 1
          @cards.push(all_cards.sample)
        end

        return { skipped_attack: 'skipped_attack' }
      end

      used_health_potion = @using_cards.any? { |c| c.is_a?(::Card::HealthPotion) }

      if used_health_potion
        @health += @using_cards.sum(&:value)
        @using_cards = []
        @cards.push(all_cards.sample)

        return { skipped_attack: 'used_health_potion' }
      end

      {}
    end

    def defend(attacker:, defense_cards:)
      @using_cards = get_valid_defense_cards(defense_cards)
      @cards = remove_used_cards

      attack = attacker.using_cards.sum(&:value)
      defense = @using_cards.sum(&:value)

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

    def attack_cards_types
      [::Card::Weapon, ::Card::StackableWeapon].to_h { |type| [type.to_s, true] }
    end

    def get_valid_attack_cards(cards)
      valid_cards = @cards.select { |card| cards.include?(card.id) && valid_attack_turn_cards_types.has_key?(card.type) }.uniq

      return [get_max_health_potion(valid_cards)] if valid_cards.any? { |c| c.is_a?(::Card::HealthPotion) }

      non_stackables = valid_cards.select { |c| c.is_a?(::Card::Weapon) }

      return valid_cards unless non_stackables.length > 1

      non_stackable = non_stackables.max_by(&:value)
      valid_cards.select { |c| c.is_a?(::Card::StackableWeapon) } << non_stackable
    end

    def valid_attack_turn_cards_types
      [::Card::Weapon, ::Card::StackableWeapon, ::Card::HealthPotion].to_h { |type| [type.to_s, true] }
    end

    def get_valid_defense_cards(cards)
      @cards.select { |card| cards.include?(card.id) && valid_defense_cards_types.has_key?(card.type) }.uniq
    end

    def valid_defense_cards_types
      [::Card::Armor].to_h { |type| [type.to_s, true] }
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

      @health = [health - damage, 0].max
    end
  end
end
