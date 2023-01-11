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
      [@player_1.id, @player_2.id]
    end

    def enemy_nickname(id)
      return @player_2.nickname if @player_1.id == id
      return @player_1.nickname if @player_2.id == id

      raise StandardError, "Can't find player"
    end

    def state(id)
      player_1_cards = id == @player_1.id ? @player_1.cards : nil

      player_2_cards = id == @player_2&.id ? @player_2.cards : nil

      {
        player_1: {
          id: @player_1.id,
          nickname: @player_1.nickname,
          health: @player_1.health,
          attack_turn: @state_machine.player_1_attack_turn?,
          defense_turn: @state_machine.player_1_defense_turn?,
          cards: player_1_cards,
          using_cards: @player_1.using_cards
        },
        player_2: {
          id: @player_2&.id,
          nickname: @player_2&.nickname,
          health: @player_2&.health,
          attack_turn: @state_machine.player_2_attack_turn?,
          defense_turn: @state_machine.player_2_defense_turn?,
          cards: player_2_cards,
          using_cards: @player_2&.using_cards || []
        }
      }
    end

    def finished?
      @state_machine.finished?
    end

    def winner
      return unless @state_machine.finished?

      return @player_1.nickname if @player_2.dead?

      @player_2.nickname
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

      prepare_attack_result = player.prepare_attack(cards:)

      if prepare_attack_result[:skipped_attack]
        state_machine_skip_attack.call

        player.refill_cards(all_cards: @cards)
        skip_turn
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

    def end_defense_turn
      @observers.each { |o| o.end_defense_turn(self) }
    end

    def skip_turn
      @observers.each { |o| o.end_round(self) }
    end

    def player_defend(defender:, defender_cards:, attacker:, can_defend:, state_machine_defend:)
      raise StandardError, "Can't defend now" unless can_defend

      defender.defend(attacker: attacker, defense_cards: defender_cards)

      if defender.dead?
        @state_machine.finish
      else
        state_machine_defend.call
      end

      end_defense_turn
      end_round
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

    def end_round
      [@player_1, @player_2].each { |player| player.refill_cards(all_cards: @cards) }
    end
  end
end
