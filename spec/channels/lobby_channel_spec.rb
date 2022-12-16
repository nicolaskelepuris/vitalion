# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ::LobbyChannel, type: :channel do
  describe 'subscribe' do
    let(:current_user) { SecureRandom.uuid }

    before { stub_connection current_user: current_user }

    describe 'success' do
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
          expect(match.state(current_user))
            .to eq(
              player_1: {
                cards: [],
                attack_turn: false,
                defense_turn: false,
                health: 100,
                id: current_user
              },
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
end