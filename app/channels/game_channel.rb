class GameChannel < ApplicationCable::Channel
  Rooms = LobbyChannel::Rooms

  def subscribed
    cards = ::Card::List.call
    current_player[:cards] = cards.sample(5).map { |c| c.as_json(only: [:id, :name, :attack, :defense]) }
    current_player[:in_game] = true
    ActionCable.server.broadcast("notifications_#{current_user}", { data: { cards: current_player[:cards] } })

    if @@rooms[params[:password]].all? { |player| player[:in_game] }
      random_player = @@rooms[params[:password]].sample
      random_player[:attacker] = true
      ActionCable.server.broadcast("room_#{params[:password]}", { data: { attacker: random_player[:id] } })
    end
  end

  def receive(data)
    cards = data[:cards]
    if current_player[:attacker]
      valid_cards = Card.where(id: cards).where("attack > ?", 0)
    else
      valid_cards = Card.where(id: cards).where("defense > ?", 0)
    end
  end

  private

  def current_player
    @player ||= @@rooms[params[:password]].first { |player| player[:id] == current_user }
  end
end