# frozen_string_literal: true

module Broadcasting
  extend self

  def private_broadcasting(id)
    "notifications_#{id}"
  end

  def private_broadcast_to(id, data)
    ActionCable.server.broadcast("notifications_#{id}", data)
  end

  def match_broadcast(match_password, data)
    ActionCable.server.broadcast(match_broadcasting(match_password), data)
  end

  def match_broadcasting(match_password)
    "match_#{match_password}"
  end
end
