require 'spec_helper'
require 'presenters/v3/role_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RolePresenter do
    describe '#to_hash' do
      let(:role_guid) { 'role-guid-1' }
      let(:user_guid) { 'user-guid-1' }
      let(:space_guid) { nil }
      let(:organization_guid) { nil }
      let(:some_time) { Time.now.utc }
      let(:role) {
        {
          guid: role_guid,
          created_at: some_time,
          updated_at: some_time,
          user_guid: user_guid,
          space_guid: space_guid,
          organization_guid: organization_guid,
          type: type,
        }
      }

      subject do
        RolePresenter.new(role).to_hash
      end

      context 'when the role is a space role' do
        let(:space_guid) { 'space-guid-1' }
        let(:type) { 'space_auditor' }

        it 'presents the role as json' do
          links = subject[:links]
          expect(subject[:guid]).to eq(role_guid)
          expect(subject[:created_at]).to eq(some_time)
          expect(subject[:updated_at]).to eq(some_time)
          expect(subject[:type]).to eq('space_auditor')
          expect(subject[:relationships][:user][:data][:guid]).to eq(user_guid)
          expect(subject[:relationships][:organization][:data]).to be_nil
          expect(subject[:relationships][:space][:data][:guid]).to eq(space_guid)
          expect(links[:self][:href]).to eq("#{link_prefix}/v3/roles/#{role_guid}")
          expect(links[:user][:href]).to eq("#{link_prefix}/v3/users/#{user_guid}")
          expect(links[:space][:href]).to eq("#{link_prefix}/v3/spaces/#{space_guid}")
          expect(links[:organization]).to be_nil
        end
      end

      context 'when the role is an org role' do
        let(:organization_guid) { 'org-guid-1' }
        let(:type) { 'org_auditor' }

        it 'presents the role as json' do
          links = subject[:links]
          expect(subject[:guid]).to eq(role_guid)
          expect(subject[:created_at]).to eq(some_time)
          expect(subject[:updated_at]).to eq(some_time)
          expect(subject[:type]).to eq('org_auditor')
          expect(subject[:relationships][:user][:data][:guid]).to eq(user_guid)
          expect(subject[:relationships][:organization][:data][:guid]).to eq(organization_guid)
          expect(subject[:relationships][:space][:data]).to be_nil
          expect(links[:self][:href]).to eq("#{link_prefix}/v3/roles/#{role_guid}")
          expect(links[:user][:href]).to eq("#{link_prefix}/v3/users/#{user_guid}")
          expect(links[:space]).to be_nil
          expect(links[:organization][:href]).to eq("#{link_prefix}/v3/organizations/#{organization_guid}")
        end
      end
    end
  end
end
