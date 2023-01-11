# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ::ApplicationCable::Connection, type: :channel do
  describe '/cable connection' do
    describe 'success' do
      it 'connects and generate uuid for current user' do
        connect '/cable'

        expect(connection.current_user.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end
    end
  end
end
