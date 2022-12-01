class LobbyChannel < ApplicationCable::Channel
  Rooms = {}

  def subscribed
    @@rooms[params[:password]] = [] unless @@rooms.include_key? params[:password]

    stream_from "notifications_#{current_user}"

    if @@rooms[params[:password]].length >= 2
      ActionCable.server.broadcast("notifications_#{current_user}", { error: "This room is full" })

      return
    end

    ActionCable.server.broadcast("notifications_#{current_user}", { data: { current_user: current_user } })

    @@rooms[params[:password]] << { id: current_user }
    stream_from "room_#{params[:password]}"
    ActionCable.server.broadcast("room_#{params[:password]}", { data: { players: @@rooms[params[:password]].pluck(:id) } })
  end
end