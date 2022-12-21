# frozen_string_literal: true

module Match
  class StateMachine
    include AASM

    aasm whiny_transitions: false do
      state :waiting_second_player, initial: true
      state :waiting_to_start
      state :player_1_attack_turn
      state :player_1_defense_turn
      state :player_2_attack_turn
      state :player_2_defense_turn
      state :finished

      event :second_player_join do
        transitions from: :waiting_second_player, to: :waiting_to_start
      end

      event :start_match do
        transitions from: :waiting_to_start, to: %i[player_1_attack_turn player_2_attack_turn].sample
      end

      event :player_1_attack do
        transitions from: :player_1_attack_turn, to: :player_2_defense_turn
      end

      event :player_1_skip_attack do
        transitions from: :player_1_attack_turn, to: :player_2_attack_turn
      end

      event :player_2_defend do
        transitions from: :player_2_defense_turn, to: :player_1_attack_turn
      end

      event :player_2_attack do
        transitions from: :player_2_attack_turn, to: :player_1_defense_turn
      end

      event :player_2_skip_attack do
        transitions from: :player_2_attack_turn, to: :player_1_attack_turn
      end

      event :player_1_defend do
        transitions from: :player_1_defense_turn, to: :player_2_attack_turn
      end

      event :finish do
        transitions to: :finished
      end
    end
  end
end
