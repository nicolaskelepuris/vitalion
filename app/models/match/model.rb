# frozen_string_literal: true

module Match
  class Model
    def initialize(player_1_id:, player_1_nickname: nil, observers: [])
      @state_machine = StateMachine.new

      @cards = ::Card::List.call
      @player_1 = ::Player::Model.new(id: player_1_id, nickname: player_1_nickname, cards: @cards.sample(5))
      @observers = observers
    end

    def join(player_id:, player_nickname: nil)
      raise StandardError, 'The match is full' unless @state_machine.may_second_player_join?

      @player_2 = ::Player::Model.new(id: player_id, nickname: player_nickname, cards: @cards.sample(5))
      @state_machine.second_player_join
    end

    def start(id)
      raise StandardError, "Can't start the match" unless @state_machine.may_start_match? && id == @player_1.id

      @state_machine.start_match
    end

    def attack(player_id:, cards:)
      return player_1_attack(cards) if player_id == @player_1.id

      player_2_attack(cards)
    end

    def defend(player_id:, cards:)
      return player_1_defend(cards) if player_id == @player_1.id

      player_2_defend(cards)
    end

    def disconnect(player_id:)
      @state_machine.finish

      return @player_1 if player_id == @player_2&.id

      @player_2
    end

    def players_ids
      [@player_1.id, @player_2.id]
    end

    def enemy_nickname(id)
      return @player_2.nickname if @player_1.id == id
      return @player_1.nickname if @player_2.id == id

      raise StandardError, "Can't find player"
    end

    def state(id)
      {
        player_1: {
          id: @player_1.id,
          nickname: @player_1.nickname,
          health: @player_1.health,
          attack_turn: @state_machine.player_1_attack_turn?,
          defense_turn: @state_machine.player_1_defense_turn?,
          cards: id == @player_1.id ? @player_1.cards : nil
        },
        player_2: {
          id: @player_2&.id,
          nickname: @player_2&.nickname,
          health: @player_2&.health,
          attack_turn: @state_machine.player_2_attack_turn?,
          defense_turn: @state_machine.player_2_defense_turn?,
          cards: id == @player_2&.id ? @player_2.cards : nil
        }
      }
    end

    private

    def player_1_attack(cards)
      raise StandardError, "Can't attack now" unless @state_machine.may_player_1_attack?

      create_attack(player: @player_1, cards:)

      if @player_1.current_attack.empty?
        end_round

        @state_machine.player_1_skip_attack
      else
        end_turn

        @state_machine.player_1_attack
      end
    end

    def player_2_attack(cards)
      raise StandardError, "Can't attack now" unless @state_machine.may_player_2_attack?

      create_attack(player: @player_2, cards:)

      if @player_2.current_attack.empty?
        end_round

        @state_machine.player_2_skip_attack
      else
        end_turn

        @state_machine.player_2_attack
      end
    end

    def create_attack(player:, cards:)
      player.current_attack = player.cards.select { |card| cards.include?(card.id) && card.attack.positive? }.uniq
    end

    def end_turn
      @observers.each { |o| o.end_turn(self) }
    end

    def player_1_defend(cards)
      raise StandardError, "Can't defend now" unless @state_machine.may_player_1_defend?

      create_defense(player: @player_1, cards:)

      process_damage(attacker: @player_2, defender: @player_1)

      if @player_1.dead?
        @state_machine.finish
      else
        @state_machine.player_1_defend
      end

      end_round
    end

    def player_2_defend(cards)
      raise StandardError, "Can't defend now" unless @state_machine.may_player_2_defend?

      create_defense(player: @player_2, cards:)

      process_damage(attacker: @player_1, defender: @player_2)

      if @player_2.dead?
        @state_machine.finish
      else
        @state_machine.player_2_defend
      end

      end_round
    end

    def create_defense(player:, cards:)
      player.current_defense = player.cards.select { |card| cards.include?(card.id) && card.defense.positive? }.uniq
    end

    def process_damage(attacker:, defender:)
      attack = attacker.current_attack.sum(&:attack)
      defense = defender.current_defense.sum(&:defense)

      defender.receive_damage(attack - defense)
    end

    def end_round
      refill_cards
      @observers.each { |o| o.end_round(self) }
      clear_turn
    end

    def refill_cards
      if @state_machine.player_1_defense_turn?
        @player1.cards -= @player_1.current_defense
        player_1_cards_count = @player_1.current_defense

        @player2.cards -= @player_2.current_attack
        player_2_cards_count = [@player_2.current_attack.count, 1].max
      else
        @player1.cards -= @player_1.current_attack
        player_1_cards_count = [@player_1.current_attack.count, 1].max

        @player2.cards -= @player_2.current_defense
        player_2_cards_count = @player_2.current_defense.count
      end

      @player_1.cards.push(*@cards.sample(player_1_cards_count))
      @player_2.cards.push(*@cards.sample(player_2_cards_count))
    end

    def clear_turn
      @player_1.current_defense = []
      @player_1.current_attack = []

      @player_2.current_defense = []
      @player_2.current_attack = []
    end
  end
end
