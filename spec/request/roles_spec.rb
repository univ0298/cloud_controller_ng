# require 'spec_helper'

RSpec.describe 'Roles' do
  let(:user) { VCAP::CloudController::User.make }
  let(:admin_header) { admin_headers_for(user) }

  describe 'POST /v3/roles' do
    it 'creates a new role for given space and user' do
      request_body = {
        type: 'space_auditor',
        relationships: {
          user: {
            data: { guid: 'user-guid' }
          },
          space: {
            data: { guid: 'space-guid' }
          }
        }
      }

      expect {
        post 'v3/roles', request_body, admin_header # TODO: user shared example for other permissions
      }.to change {
        VCAP::CloudController::Role.count
      }.by 1
    end
  end

end
