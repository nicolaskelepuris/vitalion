# frozen_string_literal: true

module Match
  class Model
    attr_reader :password

    def initialize(player_1_id:, player_1_nickname: nil, observers: [], password: nil)
      @state_machine = StateMachine.new

      @cards = ::Card::List.call
      @player_1 = ::Player::Model.new(id: player_1_id, nickname: player_1_nickname, cards: @cards.sample(5))
      @observers = observers
      @password = password
    end

    def join(player_id:, player_nickname: nil)
      raise StandardError, 'The match is full' unless @state_machine.may_second_player_join?

      @player_2 = ::Player::Model.new(id: player_id, nickname: player_nickname, cards: @cards.sample(5))
      @state_machine.second_player_join
    end

    def start
      raise StandardError, "Can't start the match" unless @state_machine.may_start_match?

      @state_machine.start_match
    end

    def attack(player_id:, cards:)
      cards ||= []

      return player_1_attack(cards) if player_id == @player_1.id

      player_2_attack(cards)
    end

    def defend(player_id:, cards:)
      cards ||= []

      return player_1_defend(cards) if player_id == @player_1.id

      player_2_defend(cards)
    end

    def disconnect(player_id:)
      @state_machine.finish

      return @player_1 if player_id == @player_2&.id

      @player_2
    end

    def players_ids
      return [@player_1.id] if @player_2.nil?

      [@player_1.id, @player_2.id]
    end

    def enemy_nickname(id)
      return @player_2.nickname if @player_1.id == id
      return @player_1.nickname if @player_2.id == id

      raise StandardError, "Can't find player"
    end

    def state(id)
      player_1_cards = id == @player_1.id ? @player_1.cards.map { |c| ::Card::Serializer.call(c) } : nil

      player_2_cards = id == @player_2&.id ? @player_2.cards.map { |c| ::Card::Serializer.call(c) } : nil

      player_1_skip_count = id == @player_1.id ? @player_1.remaining_skips_with_attack_cards : nil

      player_2_skip_count = id == @player_2&.id ? @player_2.remaining_skips_with_attack_cards : nil

      {
        player_1: {
          id: @player_1.id,
          nickname: @player_1.nickname,
          health: @player_1.health,
          attack_turn: @state_machine.player_1_attack_turn?,
          defense_turn: @state_machine.player_1_defense_turn?,
          cards: player_1_cards,
          using_cards: @player_1.using_cards.map { |c| ::Card::Serializer.call(c) },
          remaining_skips_with_attack_cards: player_1_skip_count
        },
        player_2: {
          id: @player_2&.id,
          nickname: @player_2&.nickname,
          health: @player_2&.health,
          attack_turn: @state_machine.player_2_attack_turn?,
          defense_turn: @state_machine.player_2_defense_turn?,
          cards: player_2_cards,
          using_cards: @player_2&.using_cards&.map { |c| ::Card::Serializer.call(c) } || [],
          remaining_skips_with_attack_cards: player_2_skip_count
        }
      }
    end

    def finished?
      @state_machine.finished?
    end

    def started?
      !@state_machine.waiting_second_player? && !@state_machine.waiting_to_start?
    end

    def winner
      return unless @state_machine.finished?

      return @player_1 if @player_2.dead?

      @player_2
    end

    def restart
      raise StandardError, "Can't restart the match" unless @state_machine.finished?

      @state_machine = StateMachine.new
      @player_1 = ::Player::Model.new(id: @player_1.id, nickname: @player_1.nickname, cards: @cards.sample(5))
      @player_2 = ::Player::Model.new(id: @player_2.id, nickname: @player_2.nickname, cards: @cards.sample(5))
      @state_machine.second_player_join
      @state_machine.start_match
    end

    private

    def player_attack(player:, cards:, can_attack:, state_machine_skip_attack:, state_machine_attack:)
      raise StandardError, "Can't attack now" unless can_attack

      prepare_attack_result = player.prepare_attack(cards:, all_cards: @cards)

      if prepare_attack_result[:skipped_attack].present?
        state_machine_skip_attack.call

        skip_turn(prepare_attack_result[:skipped_attack])
        return
      end

      state_machine_attack.call
      end_attack_turn
    end

    def player_1_attack(cards)
      player_attack(
        player: @player_1,
        cards: cards,
        can_attack: @state_machine.may_player_1_attack?,
        state_machine_skip_attack: -> { @state_machine.player_1_skip_attack },
        state_machine_attack: -> { @state_machine.player_1_attack }
      )
    end

    def player_2_attack(cards)
      player_attack(
        player: @player_2,
        cards: cards,
        can_attack: @state_machine.may_player_2_attack?,
        state_machine_skip_attack: -> { @state_machine.player_2_skip_attack },
        state_machine_attack: -> { @state_machine.player_2_attack }
      )
    end

    def end_attack_turn
      @observers.each { |o| o.end_attack_turn(self) }
    end

    def end_defense_turn(was_attack_successful:)
      @observers.each { |o| o.end_defense_turn(self, was_attack_successful) }
    end

    def skip_turn(reason)
      @observers.each { |o| o.end_round(self, reason) }
    end

    def player_defend(defender:, defender_cards:, attacker:, can_defend:, state_machine_defend:)
      raise StandardError, "Can't defend now" unless can_defend

      defender_health_before_attack = defender.health
      defender.defend(attacker: attacker, defense_cards: defender_cards)

      if defender.dead?
        @state_machine.finish

        end_defense_turn(was_attack_successful: true)
      else
        end_defense_turn(was_attack_successful: defender_health_before_attack > defender.health)

        state_machine_defend.call

        end_round(defender: defender, attacker: attacker)
      end
    end

    def player_1_defend(cards)
      player_defend(
        defender: @player_1,
        defender_cards: cards,
        attacker: @player_2,
        can_defend: @state_machine.may_player_1_defend?,
        state_machine_defend: -> { @state_machine.player_1_defend }
      )
    end

    def player_2_defend(cards)
      player_defend(
        defender: @player_2,
        defender_cards: cards,
        attacker: @player_1,
        can_defend: @state_machine.may_player_2_defend?,
        state_machine_defend: -> { @state_machine.player_2_defend }
      )
    end

    def end_round(defender:, attacker:)
      defender.refill_cards(all_cards: @cards, was_defense_turn: true)
      attacker.refill_cards(all_cards: @cards, was_defense_turn: false)
    end
  end
end
