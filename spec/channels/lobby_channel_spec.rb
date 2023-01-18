# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ::LobbyChannel, type: :channel do
  before do
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
      let(:current_user) { ::ApplicationCable::User.new }

      before { stub_connection current_user: }

      let(:password) { 'any password' }

      subject(:subscribe_to_lobby) { subscribe password: 'any password' }

      it 'subscribes' do
        subscribe_to_lobby

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_from("notifications_#{current_user.id}")
      end
    end
  end

  describe 'join_lobby' do
    describe 'success' do
      let(:current_user) { ::ApplicationCable::User.new }
      let(:password) { 'any password' }
      let(:nickname) { 'a good nickname' }

      before do
        stub_connection(current_user:)
        subscribe password:
      end

      subject(:join_lobby) { perform :join_lobby, password:, nickname: }

      context 'when no match with provided password exists' do
        context 'when player is first player' do
          it 'joins match' do
            join_lobby

            expect(subscription).to be_confirmed
            expect(subscription).to have_stream_from("notifications_#{current_user.id}")
          end

          it 'created match contains player 1' do
            # When
            join_lobby

            # Then
            match = Matches[password]
            player_1_cards = match.state(current_user.id)[:player_1][:cards]

            expect(::Card::Record.pluck(:id)).to include(*player_1_cards.pluck(:id))
            expect(player_1_cards.length).to eq(5)

            expect(match.state(current_user.id))
              .to include(
                player_1: include(
                  cards: be_a(::Array),
                  attack_turn: false,
                  defense_turn: false,
                  health: 25,
                  id: current_user.id,
                  nickname: nickname,
                  using_cards: []
                ),
                player_2: {
                  cards: nil,
                  attack_turn: false,
                  defense_turn: false,
                  health: nil,
                  id: nil,
                  nickname: nil,
                  using_cards: []
                }
              )
          end

          it 'sends current user id to user' do
            expect { join_lobby }
              .to have_broadcasted_to("notifications_#{current_user.id}")
              .with(method: 'joined_lobby', data: { current_user_id: current_user.id, share_url: "https://localhost?password=any%20password" })
          end
        end

        context 'when player is second player' do
          let(:first_player) { ::ApplicationCable::User.new }
          let(:first_player_nickname) { 'a good first player nickname' }

          before do
            stub_connection current_user: first_player
            subscribe(password:)
            perform(:join_lobby, password:, nickname: first_player_nickname)

            stub_connection(current_user:)
            subscribe password:
          end

          it 'created match contains players' do
            # When
            join_lobby

            # Then
            match = Matches[password]
            player_2_cards = match.state(current_user.id)[:player_2][:cards]

            expect(::Card::Record.pluck(:id)).to include(*player_2_cards.pluck(:id))
            expect(player_2_cards.length).to eq(5)

            expect(match.state(current_user.id))
              .to include(
                player_1: eq(
                  cards: nil,
                  attack_turn: false,
                  defense_turn: false,
                  health: 25,
                  id: first_player.id,
                  nickname: first_player_nickname,
                  using_cards: []
                ),
                player_2: include(
                  cards: be_a(::Array),
                  attack_turn: false,
                  defense_turn: false,
                  health: 25,
                  id: current_user.id,
                  nickname:,
                  using_cards: []
                )
              )
          end

          it 'sends current user id to second player' do
            expect { join_lobby }
              .to have_broadcasted_to("notifications_#{current_user.id}")
              .with(method: 'joined_lobby', data: { current_user_id: current_user.id, share_url: "https://localhost?password=any%20password" })
              .and have_broadcasted_to("notifications_#{first_player.id}")
              .with(
                method: 'waiting_to_start_match',
                data: {
                  is_player_1: true,
                  enemy_nickname: nickname,
                  enemy_id: current_user.id
                }
              )
              .and have_broadcasted_to("notifications_#{current_user.id}")
              .with(
                method: 'waiting_to_start_match',
                data: {
                  is_player_1: false,
                  enemy_nickname: first_player_nickname,
                  enemy_id: first_player.id
                }
              )
          end
        end
      end
    end
  end

  describe 'start_match' do
    describe 'success' do
      let(:password) { 'any password' }
      let(:current_user) { ::ApplicationCable::User.new }
      let(:second_player) { ::ApplicationCable::User.new }

      before do
        stub_connection(current_user:)
        subscribe(password:)
        perform(:join_lobby, password:)

        stub_connection current_user: second_player
        subscribe(password:)
        perform(:join_lobby, password:)

        stub_connection(current_user:)
        subscribe password:
      end

      subject(:start_match) { perform :start_match, password: }

      it 'starts the match' do
        # When
        start_match

        # Then
        match_state = Matches[password].state(current_user.id)
        player_1 = match_state[:player_1]
        player_2 = match_state[:player_2]

        expect(player_1[:defense_turn]).to eq(false)
        expect(player_2[:defense_turn]).to eq(false)

        expect(player_1[:attack_turn] ^ player_2[:attack_turn]).to eq(true)
      end

      it 'broadcasts to players that match started' do
        expect { start_match }
          .to have_broadcasted_to("notifications_#{current_user.id}")
          .with(method: 'match_started')
          .and have_broadcasted_to("notifications_#{second_player.id}")
          .with(method: 'match_started')
      end
    end
  end
end
