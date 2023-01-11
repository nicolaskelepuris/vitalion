# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user
    identified_by :current_user_id

    def connect
      user = User.new
      self.current_user = user
      self.current_user_id = user.id
    end
  end
end
