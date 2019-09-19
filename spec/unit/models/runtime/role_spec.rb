require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::Role, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      user = User.make
      space = Space.make

      Role.create(type: 'space_auditor', user: user, space: space)
      created_role = Role.last

      expect(created_role.type).to eq('space_auditor')
      expect(created_role.user).to eq(user)
      expect(created_role.space).to eq(space)
      expect(created_role.guid).to be_a_guid
    end
  end
end
