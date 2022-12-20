class LobbyChannel < ApplicationCable::Channel
  include Broadcasting
  include Matching

  def subscribed
    stream_from private_broadcasting
  end

  def join_lobby
    return if params[:password].blank?

    if Matches.key? params[:password]
      match.join(player_id: current_user)

      player_1_id = match.state(current_user)[:player_1][:id]
      match.players_ids.each do |id|
        private_broadcast_to(id, { method: 'waiting_to_start_match', data: { is_player_1: id == player_1_id } })
      end
    else
      create_match(params[:password], ::Match::Model.new(player_1_id: current_user, observers: [::GameChannel]))
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