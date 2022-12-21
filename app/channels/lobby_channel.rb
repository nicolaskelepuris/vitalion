# frozen_string_literal: true

class LobbyChannel < ApplicationCable::Channel
  include Broadcasting
  include Matching

  def subscribed
    stream_from private_broadcasting
  end

  def join_lobby(data)
    return if params[:password].blank?

    if Matches.key? params[:password]
      match.join(player_id: current_user, player_nickname: data['nickname'])

      match_state = match.state(current_user)
      player_1_id = match_state[:player_1][:id]
      player_2_id = match_state[:player_2][:id]
      match.players_ids.each do |id|
        is_player_1 = id == player_1_id

        private_broadcast_to(
          id,
          {
            method: 'waiting_to_start_match',
            data: {
              is_player_1:,
              enemy_nickname: match.enemy_nickname(id),
              enemy_id: is_player_1 ? player_2_id : player_1_id
            }
          }
        )
      end
    else
      create_match(params[:password],
                   ::Match::Model.new(player_1_id: current_user, player_1_nickname: data['nickname'],
                                      observers: [::GameChannel]))
    end

    private_broadcast({ method: 'joined_lobby', data: { current_user_id: current_user } })
  rescue StandardError => e
    private_broadcast({ method: 'joined_lobby', error: e.message })
  end

  def start_match
    match.start(current_user)
    match.players_ids.each do |id|
      private_broadcast_to(id, { method: 'match_started' })
    end
  rescue StandardError => e
    private_broadcast({ method: 'match_started', error: e.message })
  end

  private

  def match
    find_match(params[:password])
  end
end
