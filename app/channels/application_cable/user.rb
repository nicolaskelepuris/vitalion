module ApplicationCable
  class User
    attr_accessor :match
    attr_reader :id

    def initialize
      @id = SecureRandom.uuid
    end
  end
end