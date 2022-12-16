# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ::LobbyChannel, type: :channel do
  before(:all) do
    Card::Record.create(name: 'card 1', attack: 2, defense: 0)
    Card::Record.create(name: 'card 2', attack: 5, defense: 0)
    Card::Record.create(name: 'card 3', attack: 15, defense: 0)
    Card::Record.create(name: 'card 4', attack: 0, defense: 1)
    Card::Record.create(name: 'card 5', attack: 0, defense: 4)
    Card::Record.create(name: 'card 6', attack: 0, defense: 1)
    Card::Record.create(name: 'card 7', attack: 0, defense: 4)
  end

  describe 'subscribe' do
    describe 'success' do
      let(:current_user) { SecureRandom.uuid }

      before { stub_connection current_user: current_user }

      let(:password) { 'any password' }

      subject(:subscribe_to_lobby) { subscribe password: 'any password' }

      context 'when no match with provided password exists' do
        it 'subscribes' do
          subscribe_to_lobby
  
          expect(subscription).to be_confirmed
          expect(subscription).to have_stream_from("notifications_#{current_user}")
          expect(subscription).to have_stream_from("match_#{password}")
        end

        it 'creates a match' do
          expect { subscribe_to_lobby  }.to change { Matches.length }.by(1)

          match = Matches[password]
          player_1_cards = match.state(current_user)[:player_1][:cards]
          expect(::Card::Record.pluck(:id)).to include(*player_1_cards.pluck(:id))
          expect(player_1_cards.length).to eq(5)
          expect(match.state(current_user))
            .to include(
              player_1: include(
                cards: be_a(::Array),
                attack_turn: false,
                defense_turn: false,
                health: 100,
                id: current_user
              ),
              player_2: {
                cards: nil,
                attack_turn: false,
                defense_turn: false,
                health: nil,
                id: nil
              }
            )
        end

        it 'created match contains player 1' do
          # When
          subscribe_to_lobby

          # Then
          match = Matches[password]
          player_1_cards = match.state(current_user)[:player_1][:cards]

          expect(::Card::Record.pluck(:id)).to include(*player_1_cards.pluck(:id))
          expect(player_1_cards.length).to eq(5)

          expect(match.state(current_user))
            .to include(
              player_1: include(
                cards: be_a(::Array),
                attack_turn: false,
                defense_turn: false,
                health: 100,
                id: current_user
              ),
              player_2: {
                cards: nil,
                attack_turn: false,
                defense_turn: false,
                health: nil,
                id: nil
              }
            )
        end

        it 'sends current user id to user' do
          expect { subscribe_to_lobby }
            .to have_broadcasted_to("notifications_#{current_user}")
            .with(data: { current_user_id: current_user })
        end
      end
    end
  end

  describe 'start_match' do
    describe 'success' do
      let(:password) { 'any password' }
      let(:current_user) { SecureRandom.uuid }
      let(:second_player) { SecureRandom.uuid }

      before do
        stub_connection current_user: current_user
        subscribe password: password

        stub_connection current_user: second_player
        subscribe password: password

        stub_connection current_user: current_user
        subscribe password: password
      end

      subject(:start_match) { perform :start_match }

      it 'starts the match' do
        # When
        start_match

        # Then
        match_state = Matches[password].state(current_user)
        player_1 = match_state[:player_1]
        player_2 = match_state[:player_2]

        expect(player_1[:defense_turn]).to eq(false)
        expect(player_2[:defense_turn]).to eq(false)

        expect(player_1[:attack_turn] ^ player_2[:attack_turn]).to eq(true)
      end

      it 'broadcasts to players that match started' do
        expect { start_match }
          .to have_broadcasted_to("match_#{password}")
          .with(data: { start_match: true })
      end
    end
  end
end