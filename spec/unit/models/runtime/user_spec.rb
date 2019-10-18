require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::User, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :organizations }
      it { is_expected.to have_associated :default_space, class: Space }
      it do
        is_expected.to have_associated :managed_organizations, associated_instance: ->(user) {
          org = Organization.make
          user.add_organization(org)
          org
        }
      end
      it do
        is_expected.to have_associated :billing_managed_organizations, associated_instance: ->(user) {
          org = Organization.make
          user.add_organization(org)
          org
        }
      end
      it do
        is_expected.to have_associated :audited_organizations, associated_instance: ->(user) {
          org = Organization.make
          user.add_organization(org)
          org
        }
      end
      it { is_expected.to have_associated :spaces }
      it { is_expected.to have_associated :managed_spaces, class: Space }
      it { is_expected.to have_associated :audited_spaces, class: Space }
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :guid }
      it { is_expected.to validate_uniqueness :guid }
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :admin, :active, :default_space_guid }
      it { is_expected.to import_attributes :guid, :admin, :active, :organization_guids, :managed_organization_guids,
        :billing_managed_organization_guids, :audited_organization_guids, :space_guids,
        :managed_space_guids, :audited_space_guids, :default_space_guid
      }
    end

    describe '#presentation_name' do
      let(:user) { VCAP::CloudController::User.make }
      let(:uaa_client) { double(:uaa_client) }

      context 'when the user is a UAA user' do
        before do
          allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
          allow(uaa_client).to receive(:users_for_ids).with([user.guid]).and_return(
            { user.guid => { 'username' => 'mona', 'origin' => 'uaa' } }
          )
        end

        it 'returns the UAA username' do
          expect(user.presentation_name).to eq('mona')
        end
      end

      context 'when the user is a UAA client' do
        let(:user) { VCAP::CloudController::User.make(guid: 're-id') }

        before do
          allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
          allow(uaa_client).to receive(:users_for_ids).with([user.guid]).and_return({})
        end

        it 'returns the guid' do
          expect(user.presentation_name).to eq(user.guid)
        end
      end
    end

    describe '#remove_spaces' do
      let(:org) { Organization.make }
      let(:user) { User.make }
      let(:space) { Space.make }

      before do
        org.add_user(user)
        org.add_space(space)
      end

      context 'when a user is not assigned to any space' do
        it "should not alter a user's developer space" do
          expect {
            user.remove_spaces space
          }.to_not change { user.spaces }
        end

        it "should not alter a user's managed space" do
          expect {
            user.remove_spaces space
          }.to_not change { user.managed_spaces }
        end

        it "should not alter a user's audited spaces" do
          expect {
            user.remove_spaces space
          }.to_not change { user.audited_spaces }
        end
      end

      context 'when a user is assigned to a single space' do
        before do
          space.add_developer(user)
          space.add_manager(user)
          space.add_auditor(user)
          user.refresh
          space.refresh
        end

        it "should remove the space from the user's developer spaces" do
          expect {
            user.remove_spaces space
          }.to change { user.spaces }.from([space]).to([])
        end

        it "should remove the space from the user's managed spaces" do
          expect {
            user.remove_spaces space
          }.to change { user.managed_spaces }.from([space]).to([])
        end

        it "should remove the space form the user's auditor spaces" do
          expect {
            user.remove_spaces space
          }.to change { user.audited_spaces }.from([space]).to([])
        end

        it "should remove the user from the space's developers role" do
          expect {
            user.remove_spaces space
          }.to change { space.developers }.from([user]).to([])
        end

        it "should remove the user from the space's managers role" do
          expect {
            user.remove_spaces space
          }.to change { space.managers }.from([user]).to([])
        end

        it "should remove the user from the space's auditors role" do
          expect {
            user.remove_spaces space
          }.to change { space.auditors }.from([user]).to([])
        end
      end
    end

    describe 'relationships' do
      let(:org) { Organization.make }
      let(:user) { User.make }

      context 'when a user is a member of organzation' do
        before do
          user.add_organization(org)
        end

        it 'should allow becoming an organization manager' do
          expect {
            user.add_managed_organization(org)
          }.to change { user.managed_organizations.size }.by(1)
        end

        it 'should allow becoming an organization billing manager' do
          expect {
            user.add_billing_managed_organization(org)
          }.to change { user.billing_managed_organizations.size }.by(1)
        end

        it 'should allow becoming an organization auditor' do
          expect {
            user.add_audited_organization(org)
          }.to change { user.audited_organizations.size }.by(1)
        end
      end

      context 'when a user is not a member of organization' do
        it 'should NOT allow becoming an organization manager' do
          expect {
            user.add_audited_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end

        it 'should NOT allow becoming an organization billing manager' do
          expect {
            user.add_billing_managed_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end

        it 'should NOT allow becoming an organization auditor' do
          expect {
            user.add_audited_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end
      end

      context 'when a user is a manager' do
        before do
          user.add_organization(org)
          user.add_managed_organization(org)
        end

        it 'should fail to remove user from organization' do
          expect {
            user.remove_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end
      end

      context 'when a user is a billing manager' do
        before do
          user.add_organization(org)
          user.add_billing_managed_organization(org)
        end

        it 'should fail to remove user from organization' do
          expect {
            user.remove_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end
      end

      context 'when a user is an auditor' do
        before do
          user.add_organization(org)
          user.add_audited_organization(org)
        end

        it 'should fail to remove user from organization' do
          expect {
            user.remove_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end
      end

      context 'when a user is not a manager/billing manager/auditor' do
        before do
          user.add_organization(org)
        end

        it 'should remove user from organization' do
          expect {
            user.remove_organization(org)
          }.to change { user.organizations.size }.by(-1)
        end
      end
    end

    describe '#export_attrs' do
      let(:user) { User.make }

      it 'does not include username when username has not been set' do
        expect(user.export_attrs).to_not include(:username)
      end

      it 'includes username when username has been set' do
        user.username = 'somebody'
        expect(user.export_attrs).to include(:username)
      end

      context 'organization_roles' do
        it 'does not include organization_roles when organization_roles has not been set' do
          expect(user.export_attrs).to_not include(:organization_roles)
        end

        it 'includes organization_roles when organization_roles has been set' do
          user.organization_roles = 'something'
          expect(user.export_attrs).to include(:organization_roles)
        end
      end

      context 'space_roles' do
        it 'does not include space_roles when space_roles has not been set' do
          expect(user.export_attrs).to_not include(:space_roles)
        end

        it 'includes space_roles when space_roles has been set' do
          user.space_roles = 'something'
          expect(user.export_attrs).to include(:space_roles)
        end
      end
    end

    describe '#membership_spaces' do
      it 'returns a list of spaces that the user is a member of' do
        user = User.make
        organization = Organization.make
        organization.add_user user
        developer_space = Space.make organization: organization
        auditor_space = Space.make organization: organization
        manager_space = Space.make organization: organization

        manager_space.add_manager user
        auditor_space.add_auditor user
        developer_space.add_developer user

        ids = user.membership_spaces.all.map(&:id)

        expect(ids).to match_array([developer_space, manager_space, auditor_space].map(&:id))
      end
    end

    describe '#membership_organizations' do
      it 'returns a list of orgs that the user is a member of' do
        user = User.make
        user_organization = Organization.make
        billing_manager_organization = Organization.make
        auditor_organization = Organization.make
        manager_organization = Organization.make

        user_organization.add_user user
        manager_organization.add_manager user
        auditor_organization.add_auditor user
        billing_manager_organization.add_billing_manager user

        ids = user.membership_organizations.all.map(&:id)

        expect(ids).to match_array([
          user_organization,
          billing_manager_organization,
          manager_organization,
          auditor_organization
        ].map(&:id))
      end
    end

    describe '#visable_users_in_my_orgs' do
      it 'returns a list of users in orgs that the user is a member of' do
        actor = User.make
        actee1 = User.make
        actee2 = User.make
        actee3 = User.make
        actee4 = User.make
        user_organization = Organization.make
        billing_manager_organization = Organization.make
        auditor_organization = Organization.make
        manager_organization = Organization.make

        user_organization.add_user actor
        manager_organization.add_manager actor
        auditor_organization.add_auditor actor
        billing_manager_organization.add_billing_manager actor

        user_organization.add_user actee1
        manager_organization.add_manager actee2
        auditor_organization.add_auditor actee3
        billing_manager_organization.add_billing_manager actee4

        ids = actor.visable_users_in_my_orgs.all.map(&:id)

        expect(ids).to match_array([
          actee1,
          actee2,
          actee3,
          actee4
        ].map(&:id))
      end

      it 'doesnt repeat users' do
        actor = User.make
        actee1 = User.make

        user_organization = Organization.make
        billing_manager_organization = Organization.make
        auditor_organization = Organization.make
        manager_organization = Organization.make

        user_organization.add_user actor
        manager_organization.add_manager actor
        auditor_organization.add_auditor actor
        billing_manager_organization.add_billing_manager actor

        user_organization.add_user actee1
        manager_organization.add_manager actee1
        auditor_organization.add_auditor actee1
        billing_manager_organization.add_billing_manager actee1

        ids = actor.visible_users_in_my_orgs.all.map(&:id)

        expect(ids).to match_array([
          actee1,
        ].map(&:id))
      end
    end

    # describe '#readable_users_for_current_user_with_roles' do
    #   RoleTypes.ALL_ROLES.each do |role|
    #     context("as a #{role}") do
    #     #   current user is a role (which is a org role)
    #     #
    #     end
    #   end
    # end
  end
end
