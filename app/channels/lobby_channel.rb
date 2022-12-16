class LobbyChannel < ApplicationCable::Channel
  include Broadcasting
  include Matching

  def subscribed
    stream_from private_broadcasting

    if Matches.key? params[:password]
      match.join(player_id: current_user)
    else
      create_match(params[:password], ::Match::Model.new(player_1_id: current_user, observers: [::GameChannel]))
    end

    private_broadcast({ data: { current_user_id: current_user } })

    stream_from match_broadcasting(params[:password])
  rescue StandardError => e
    private_broadcast({ error: e.message })
  end

  def receive(data)
    return unless data[:start_match]

    match.start(current_user)
  rescue StandardError => e
    private_broadcast({ error: e.message })
  end

  private

  def match
    @match ||= find_match(params[:password])
  end
end