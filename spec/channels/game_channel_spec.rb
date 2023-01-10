# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ::GameChannel, type: :channel do
  let!(:attack_cards) do
    [
      Card::Record.create(name: 'card 1', attack: 2, defense: 0),
      Card::Record.create(name: 'card 2', attack: 5, defense: 0),
      Card::Record.create(name: 'card 3', attack: 15, defense: 0)
    ]
  end

  let!(:defense_cards) do
    [
      Card::Record.create(name: 'card 4', attack: 0, defense: 1),
      Card::Record.create(name: 'card 5', attack: 0, defense: 4)
    ]
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
        before { stub_connection current_user: }

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

  describe 'start_round' do
    describe 'success' do
      let(:password) { 'any password' }
      let(:current_user) { SecureRandom.uuid }
      let(:current_user_nickname) { 'a good player 1 nickname' }
      let(:second_player) { SecureRandom.uuid }
      let(:second_player_nickname) { 'player 2 nickname here' }

      before do
        Matches[password] =
          ::Match::Model.new(player_1_id: current_user, player_1_nickname: current_user_nickname,
                             observers: [::GameChannel])
        Matches[password].join(player_id: second_player, player_nickname: second_player_nickname)
        Matches[password].start(current_user)
      end

      subject(:start_round) { perform :start_round, password: }

      context 'when retrieving match state as player 1' do
        before do
          stub_connection(current_user:)
          subscribe password:
        end

        it 'returns match state' do
          expect { start_round }
            .to have_broadcasted_to("notifications_#{current_user}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('start_round')
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
          subscribe password:
        end

        it 'returns match state' do
          expect { start_round }
            .to have_broadcasted_to("notifications_#{second_player}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('start_round')
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

  describe 'attack' do
    describe 'success' do
      let(:password) { 'any password' }
      let(:current_user) { SecureRandom.uuid }
      let(:current_user_nickname) { 'a good player 1 nickname' }
      let(:second_player) { SecureRandom.uuid }
      let(:second_player_nickname) { 'player 2 nickname here' }
      let(:is_player_1_attack_turn) do
        Matches[password] =
          ::Match::Model.new(player_1_id: current_user,
                             player_1_nickname: current_user_nickname,
                             observers: [::GameChannel])

        Matches[password].join(player_id: second_player, player_nickname: second_player_nickname)
        Matches[password].start(current_user)

        is_player_1_attack_turn = Matches[password].state(current_user)[:player_1][:attack_turn]
        is_player_2_attack_turn = Matches[password].state(current_user)[:player_2][:attack_turn]
        raise unless is_player_1_attack_turn || is_player_2_attack_turn

        is_player_1_attack_turn
      end

      let(:choosed_attack_cards_ids) { attack_cards.sample(2).pluck(:id) }
      let(:choosed_defense_cards_ids) { defense_cards.sample(2).pluck(:id) }
      let(:used_cards) { attack_cards.select { |c| choosed_attack_cards_ids.include? c.id }.map(&:as_json) }

      before do
        stub_connection(current_user: is_player_1_attack_turn ? current_user : second_player)
        subscribe password:
      end

      subject(:attack) { perform :attack, cards: choosed_cards }

      context 'when player attacks using 1 or more attack cards' do
        let(:choosed_cards) { [choosed_attack_cards_ids, choosed_attack_cards_ids + choosed_defense_cards_ids].sample }

        it 'returns match state to player one' do
          expect { attack }
            .to have_broadcasted_to("notifications_#{current_user}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('end_attack_turn')
                expect(payload[:data])
                  .to include(
                    player_1: include(
                      cards: be_a(::Array),
                      attack_turn: false,
                      defense_turn: is_player_1_attack_turn ? false : true,
                      health: 100,
                      nickname: current_user_nickname,
                      id: current_user,
                      using_cards: match_array(is_player_1_attack_turn ? used_cards : [])
                    ),
                    player_2: include(
                      cards: nil,
                      attack_turn: false,
                      defense_turn: is_player_1_attack_turn ? true : false,
                      health: 100,
                      nickname: second_player_nickname,
                      id: second_player,
                      using_cards: match_array(is_player_1_attack_turn ? [] : used_cards)
                    )
                  )
  
                player_cards = payload[:data][:player_1][:cards]
                
                if is_player_1_attack_turn
                  expect(player_cards.pluck(:id)).to match_array(::Card::Record.pluck(:id) - choosed_attack_cards_ids)
                  expect(player_cards.length).to eq(5 - choosed_attack_cards_ids.length)
                else
                  expect(player_cards.pluck(:id)).to match_array(::Card::Record.pluck(:id))
                  expect(player_cards.length).to eq(5)
                end
              end
            )
        end
  
        it 'returns match state to player two' do
          expect { attack }
            .to have_broadcasted_to("notifications_#{second_player}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('end_attack_turn')
                expect(payload[:data])
                  .to include(
                    player_1: include(
                      cards: nil,
                      attack_turn: false,
                      defense_turn: is_player_1_attack_turn ? false : true,
                      health: 100,
                      nickname: current_user_nickname,
                      id: current_user,
                      using_cards: match_array(is_player_1_attack_turn ? used_cards : [])
                    ),
                    player_2: include(
                      cards: be_a(::Array),
                      attack_turn: false,
                      defense_turn: is_player_1_attack_turn ? true : false,
                      health: 100,
                      nickname: second_player_nickname,
                      id: second_player,
                      using_cards: match_array(is_player_1_attack_turn ? [] : used_cards)
                    )
                  )
  
                player_cards = payload[:data][:player_2][:cards]

                if is_player_1_attack_turn
                  expect(player_cards.pluck(:id)).to match_array(::Card::Record.pluck(:id))
                  expect(player_cards.length).to eq(5)
                else
                  expect(player_cards.pluck(:id)).to match_array(::Card::Record.pluck(:id) - choosed_attack_cards_ids)
                  expect(player_cards.length).to eq(5 - choosed_attack_cards_ids.length)
                end
              end
            )
        end
      end
      
      context 'when player attacks using 0 attack cards' do
        let(:choosed_cards) { [choosed_defense_cards_ids, []].sample }

        it 'returns match state to player one' do
          expect { attack }
            .to have_broadcasted_to("notifications_#{current_user}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('start_round')
                expect(payload[:data])
                  .to include(
                    player_1: include(
                      attack_turn: is_player_1_attack_turn ? false : true,
                      defense_turn: false,
                      health: 100,
                      nickname: current_user_nickname,
                      id: current_user,
                      using_cards: match_array([]),
                      cards: be_a(::Array)
                    ),
                    player_2: include(
                      attack_turn: is_player_1_attack_turn ? true : false,
                      defense_turn: false,
                      health: 100,
                      nickname: second_player_nickname,
                      id: second_player,
                      using_cards: match_array([]),
                      cards: nil
                    )
                  )
  
                player_cards = payload[:data][:player_1][:cards]  
                expect(::Card::Record.pluck(:id)).to include(*player_cards.pluck(:id))

                expected_cards_count = is_player_1_attack_turn ? 6 : 5
                expect(player_cards.length).to eq(expected_cards_count)
              end
            )
        end
  
        it 'returns match state to player two' do
          expect { attack }
            .to have_broadcasted_to("notifications_#{second_player}")
            .with(
              lambda do |payload|
                expect(payload[:method]).to eq('start_round')
                expect(payload[:data])
                  .to include(
                    player_1: include(
                      attack_turn: is_player_1_attack_turn ? false : true,
                      defense_turn: false,
                      health: 100,
                      nickname: current_user_nickname,
                      id: current_user,
                      using_cards: match_array([]),
                      cards: nil
                    ),
                    player_2: include(
                      attack_turn: is_player_1_attack_turn ? true : false,
                      defense_turn: false,
                      health: 100,
                      nickname: second_player_nickname,
                      id: second_player,
                      using_cards: match_array([]),
                      cards: be_a(::Array)
                    )
                  )
  
                  player_cards = payload[:data][:player_2][:cards]  
                  expect(::Card::Record.pluck(:id)).to include(*player_cards.pluck(:id))
  
                  expected_cards_count = is_player_1_attack_turn ? 5 : 6
                  expect(player_cards.length).to eq(expected_cards_count)
              end
            )
        end
      end
    end
  end

  describe 'defend' do
    describe 'success' do
      let(:password) { 'any password' }
      let(:current_user) { SecureRandom.uuid }
      let(:current_user_nickname) { 'a good player 1 nickname' }
      let(:second_player) { SecureRandom.uuid }
      let(:second_player_nickname) { 'player 2 nickname here' }
      let(:first_attack_cards) { attack_cards }
      let(:first_attack_cards_ids) { first_attack_cards.pluck(:id) }
      let(:is_player_1_defense_turn) do
        Matches[password] =
          ::Match::Model.new(player_1_id: current_user,
                             player_1_nickname: current_user_nickname,
                             observers: [::GameChannel])

        Matches[password].join(player_id: second_player, player_nickname: second_player_nickname)
        Matches[password].start(current_user)

        is_player_1_attack_turn = Matches[password].state(current_user)[:player_1][:attack_turn]
        Matches[password].attack(
          player_id: is_player_1_attack_turn ? current_user : second_player,
          cards: first_attack_cards_ids
        )

        if is_player_1_attack_turn && Matches[password].state(current_user)[:player_1][:defense_turn]
          raise StandardError, 'after player 1 attack should be player 2 defense turn'
        end
        if !is_player_1_attack_turn && Matches[password].state(current_user)[:player_2][:defense_turn]
          raise StandardError, 'after player 2 attack should be player 1 defense turn'
        end

        !is_player_1_attack_turn
      end

      let(:choosed_attack_cards_ids) { attack_cards.sample(2).pluck(:id) }
      let(:choosed_defense_cards_ids) { defense_cards.sample(2).pluck(:id) }
      let(:used_cards) { defense_cards.select { |c| choosed_defense_cards_ids.include? c.id }.map(&:as_json) }

      before do
        stub_connection(current_user: is_player_1_defense_turn ? current_user : second_player)
        subscribe password:
      end

      let(:turn_damage) { first_attack_cards.sum(&:attack) - defense_cards.select { |c| choosed_defense_cards_ids.include? c.id }.sum(&:defense) }
      let(:health_after_defense) { 100 - turn_damage }

      subject(:defend) { perform :defend, cards: choosed_attack_cards_ids + choosed_defense_cards_ids }

      it 'returns match state to player one' do
        expect { defend }
          .to have_broadcasted_to("notifications_#{current_user}")
          .with(
            lambda do |payload|
              expect(payload[:method]).to eq('end_defense_turn')
              expect(payload[:data])
                .to include(
                  player_1: include(
                    attack_turn: is_player_1_defense_turn ? true : false,
                    defense_turn: false,
                    health: is_player_1_defense_turn ? health_after_defense : 100,
                    nickname: current_user_nickname,
                    id: current_user,
                    using_cards: match_array(is_player_1_defense_turn ? used_cards : first_attack_cards.map(&:as_json)),
                    cards: be_a(::Array)
                  ),
                  player_2: include(
                    attack_turn: is_player_1_defense_turn ? false : true,
                    defense_turn: false,
                    health: is_player_1_defense_turn ? 100 : health_after_defense,
                    nickname: second_player_nickname,
                    id: second_player,
                    using_cards: match_array(is_player_1_defense_turn ? first_attack_cards.map(&:as_json) : used_cards),
                    cards: nil
                  )
                )

              player_cards = payload[:data][:player_1][:cards]

              if is_player_1_defense_turn
                expect(player_cards.pluck(:id)).to match_array(::Card::Record.pluck(:id) - choosed_defense_cards_ids)
                expect(player_cards.length).to eq(5 - choosed_defense_cards_ids.length)
              else
                expect(player_cards.pluck(:id)).to match_array(::Card::Record.pluck(:id) - first_attack_cards_ids)
                expect(player_cards.length).to eq(5 - first_attack_cards_ids.length)
              end
            end
          )

        expect(Matches[password].state(current_user)[:player_1][:cards].length).to eq(5)
        expect(Matches[password].state(second_player)[:player_2][:cards].length).to eq(5)
      end

      it 'returns match state to player two' do
        expect { defend }
          .to have_broadcasted_to("notifications_#{second_player}")
          .with(
            lambda do |payload|
              expect(payload[:method]).to eq('end_defense_turn')
              expect(payload[:data])
                .to include(
                  player_1: include(
                    attack_turn: is_player_1_defense_turn ? true : false,
                    defense_turn: false,
                    health: is_player_1_defense_turn ? health_after_defense : 100,
                    nickname: current_user_nickname,
                    id: current_user,
                    using_cards: match_array(is_player_1_defense_turn ? used_cards : first_attack_cards.map(&:as_json)),
                    cards: nil
                  ),
                  player_2: include(
                    attack_turn: is_player_1_defense_turn ? false : true,
                    defense_turn: false,
                    health: is_player_1_defense_turn ? 100 : health_after_defense,
                    nickname: second_player_nickname,
                    id: second_player,
                    using_cards: match_array(is_player_1_defense_turn ? first_attack_cards.map(&:as_json) : used_cards),
                    cards: be_a(::Array)
                  )
                )

              player_cards = payload[:data][:player_2][:cards]

              if is_player_1_defense_turn
                expect(player_cards.pluck(:id)).to match_array(::Card::Record.pluck(:id) - first_attack_cards_ids)
                expect(player_cards.length).to eq(5 - first_attack_cards_ids.length)
              else
                expect(player_cards.pluck(:id)).to match_array(::Card::Record.pluck(:id) - choosed_defense_cards_ids)
                expect(player_cards.length).to eq(5 - choosed_defense_cards_ids.length)
              end
            end
          )

        expect(Matches[password].state(current_user)[:player_1][:cards].length).to eq(5)
        expect(Matches[password].state(second_player)[:player_2][:cards].length).to eq(5)
      end
    end
  end
end
