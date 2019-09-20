require 'spec_helper'
require 'fetchers/role_list_fetcher'

module VCAP::CloudController
  RSpec.describe RoleListFetcher do
    describe '#fetch_all' do
      subject { RoleListFetcher.fetch_all }
      let(:user) { User.make }
      let(:org) { Organization.make }
      let(:space) { Space.make(organization: org) }
      let(:role) {
        {
          :user_guid => user.guid,
          :space_guid => space.guid,
          :organization_guid => nil,
          :type => "space_auditor",
        }
      }

      before do
        org.add_user(user)
        space.add_auditor(user)
      end

      it 'fetches all the roles' do
        expect(subject).to match_array([role])
      end
    end
  end
end
