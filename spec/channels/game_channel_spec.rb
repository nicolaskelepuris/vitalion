# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ::GameChannel, type: :channel do
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
    let(:current_user) { SecureRandom.uuid }
    let(:player_2) { SecureRandom.uuid }
    let(:password) { 'any password' }

    before do
      Matches[password] = ::Match::Model.new(player_1_id: current_user, observers: [::GameChannel])
      Matches[password].join(player_id: player_2)
      Matches[password].start(current_user)
    end

    describe 'success' do
      subject(:subscribe_to_game) { subscribe password: 'any password' }

      context 'when subscribing as player 1' do
        before { stub_connection current_user: current_user }

        it 'subscribes' do
          subscribe_to_game
  
          expect(subscription).to be_confirmed
          expect(subscription).to have_stream_from("match_#{password}")
          expect(subscription).to have_stream_from("notifications_#{current_user}")
        end
      end

      context 'when subscribing as player 2' do
        before { stub_connection current_user: player_2 }
        
        it 'subscribes' do
          subscribe_to_game
  
          expect(subscription).to be_confirmed
          expect(subscription).to have_stream_from("match_#{password}")
          expect(subscription).to have_stream_from("notifications_#{player_2}")
        end
      end
    end

    describe 'failures' do
      subject(:subscribe_to_game) { subscribe password: 'any password' }

      context 'when subscribing as another player' do
        let(:another_player) { SecureRandom.uuid }

        before { stub_connection current_user: another_player }
        
        it 'subscribes' do
          subscribe_to_game
  
          expect(subscription).to be_rejected
        end
      end
    end
  end

  describe 'match_state' do
    describe 'success' do
      let(:password) { 'any password' }
      let(:current_user) { SecureRandom.uuid }
      let(:current_user_nickname) { 'a good player 1 nickname' }
      let(:second_player) { SecureRandom.uuid }
      let(:second_player_nickname) { 'player 2 nickname here' }

      before do
        Matches[password] = ::Match::Model.new(player_1_id: current_user, player_1_nickname: current_user_nickname, observers: [::GameChannel])
        Matches[password].join(player_id: second_player, player_nickname: second_player_nickname)
        Matches[password].start(current_user)
      end

      subject(:match_state) { perform :match_state, password: password }

      context 'when retrieving match state as player 1' do
        before do
          stub_connection current_user: current_user
          subscribe password: password
        end

        it 'returns match state' do
          expect { match_state }
            .to have_broadcasted_to("notifications_#{current_user}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('end_round')
                expect(payload[:data])
                  .to include(
                      player_1: include(
                      cards: be_a(::Array),
                      defense_turn: false,
                      health: 100,
                      nickname: current_user_nickname,
                      id: current_user
                    ),
                      player_2: include(
                      cards: nil,
                      defense_turn: false,
                      health: 100,
                      nickname: second_player_nickname,
                      id: second_player
                    )
                  )
                
                player_1 = payload[:data][:player_1]
                player_2 = payload[:data][:player_2]
                player_cards = player_1[:cards]
      
                expect(::Card::Record.pluck(:id)).to include(*player_cards.pluck(:id))
                expect(player_cards.length).to eq(5)
                expect(player_1[:attack_turn] ^ player_2[:attack_turn]).to eq(true)
              end
            )      
        end
      end

      context 'when retrieving match state as player 2' do
        before do
          stub_connection current_user: second_player
          subscribe password: password
        end

        it 'returns match state' do
          expect { match_state }
            .to have_broadcasted_to("notifications_#{second_player}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('end_round')
                expect(payload[:data])
                  .to include(
                    player_1: include(
                      cards: nil,
                      defense_turn: false,
                      health: 100,
                      nickname: current_user_nickname,
                      id: current_user
                    ),
                    player_2: include(
                      cards: be_a(::Array),
                      defense_turn: false,
                      health: 100,
                      nickname: second_player_nickname,
                      id: second_player
                    )
                  )
                
                player_1 = payload[:data][:player_1]
                player_2 = payload[:data][:player_2]
                player_cards = player_2[:cards]
      
                expect(::Card::Record.pluck(:id)).to include(*player_cards.pluck(:id))
                expect(player_cards.length).to eq(5)
                expect(player_1[:attack_turn] ^ player_2[:attack_turn]).to eq(true)
              end
            )      
        end
      end
    end
  end
end