module Broadcasting
  def private_broadcast(data)
    ActionCable.server.broadcast(private_broadcasting, data)
  end

  def private_broadcasting
    "notifications_#{current_user}"
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