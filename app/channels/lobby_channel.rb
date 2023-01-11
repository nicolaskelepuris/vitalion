# frozen_string_literal: true

class LobbyChannel < ApplicationCable::Channel
  include Matching

  def subscribed
    stream_from Broadcasting.private_broadcasting(current_user.id)
  end

  def unsubscribed
    player_match = current_user.match

    if player_match.present? && !player_match.started?
      player_match.players_ids.each do |id|
        ActionCable.server.remote_connections.where(current_user_id: id).disconnect
      end
  
      delete_match(player_match.password)
    end
  end

  def join_lobby(data)
    return if params[:password].blank?

    if Matches.key? params[:password]
      match.join(player_id: current_user.id, player_nickname: data['nickname'])

      match_state = match.state(current_user.id)
      player_1_id = match_state[:player_1][:id]
      player_2_id = match_state[:player_2][:id]
      match.players_ids.each do |id|
        is_player_1 = id == player_1_id

        Broadcasting.private_broadcast_to(
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
                   ::Match::Model.new(player_1_id: current_user.id, player_1_nickname: data['nickname'],
                                      observers: [::GameChannel]))
    end

    current_user.match = match

    Broadcasting.private_broadcast_to(current_user.id, { method: 'joined_lobby', data: { current_user_id: current_user.id } })
  rescue StandardError => e
    Broadcasting.private_broadcast_to(current_user.id, { method: 'joined_lobby', error: e.message })
  end

  def start_match
    match.start(current_user.id)
    match.players_ids.each do |id|
      Broadcasting.private_broadcast_to(id, { method: 'match_started' })
    end
  rescue StandardError => e
    Broadcasting.private_broadcast_to(current_user.id, { method: 'match_started', error: e.message })
  end

  private

  def match
    find_match(params[:password])
  end
end
