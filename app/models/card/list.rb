# frozen_string_literal: true

module Card
  class List
    def self.call
      Record.all
    end
  end
end
