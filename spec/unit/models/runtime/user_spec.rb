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

    describe '.readable_users_for_current_user' do
      # See Miro board https://miro.com/app/board/o9J_kwAiqsc=/ for graphical explanation of test
      let(:org_1) { Organization.make }
      let(:org_2) { Organization.make }

      let(:space_1a) { Space.make(organization: org_1) }
      let(:space_2a) { Space.make(organization: org_2) }
      let(:space_2b) { Space.make(organization: org_2) }

      let(:org_1_manager) { User.make(guid: 'org_1_manager') }
      let(:org_1_billing_manager) { User.make(guid: 'org_1_billing_manager') }
      let(:org_1_auditor) { User.make(guid: 'org_1_auditor') }

      let(:space_1a_manager) { User.make(guid: 'space_1a_manager') }
      let(:space_1a_auditor) { User.make(guid: 'space_1a_auditor') }
      let(:space_1a_developer) { User.make(guid: 'space_1a_developer') }

      let(:space_2a_manager) { User.make(guid: 'space_2a_manager') }
      let(:space_2a_auditor) { User.make(guid: 'space_2a_auditor') }
      let(:space_2a_developer) { User.make(guid: 'space_2a_developer') }

      let(:space_2b_manager) { User.make(guid: 'space_2b_manager') }
      let(:space_2b_auditor) { User.make(guid: 'space_2b_auditor') }
      let(:space_2b_developer) { User.make(guid: 'space_2b_developer') }

      before do
        OrganizationManager.make(user: org_1_manager, organization: org_1)
        OrganizationBillingManager.make(user: org_1_billing_manager, organization: org_1)
        OrganizationAuditor.make(user: org_1_auditor, organization: org_1)

        SpaceManager.make(user: space_1a_manager, space: space_1a)
        OrganizationUser.make(user: space_1a_manager, organization: org_1)
        SpaceAuditor.make(user: space_1a_auditor, space: space_1a)
        OrganizationUser.make(user: space_1a_auditor, organization: org_1)
        SpaceDeveloper.make(user: space_1a_developer, space: space_1a)
        OrganizationUser.make(user: space_1a_developer, organization: org_1)

        SpaceManager.make(user: space_2a_manager, space: space_2a)
        OrganizationUser.make(user: space_2a_manager, organization: org_2)
        SpaceAuditor.make(user: space_2a_auditor, space: space_2a)
        OrganizationUser.make(user: space_2a_auditor, organization: org_2)
        SpaceDeveloper.make(user: space_2a_developer, space: space_2a)
        OrganizationUser.make(user: space_2a_developer, organization: org_2)

        SpaceManager.make(user: space_2b_manager, space: space_2b)
        OrganizationUser.make(user: space_2b_manager, organization: org_2)
        SpaceAuditor.make(user: space_2b_auditor, space: space_2b)
        OrganizationUser.make(user: space_2b_auditor, organization: org_2)
        SpaceDeveloper.make(user: space_2b_developer, space: space_2b)
        OrganizationUser.make(user: space_2b_developer, organization: org_2)
      end
      context 'when an {admin, read_only_admin, global_auditor} lists users' do
        it 'sees all the org users in managed org' do
          expect(User.readable_users_for_current_user(true, User.make(guid: 'global-user')).map(&:guid)).
            to(match_array([
              'global-user',
              'org_1_manager',
              'org_1_billing_manager',
              'org_1_auditor',
              'space_1a_manager',
              'space_1a_auditor',
              'space_1a_developer',
              'space_2a_manager',
              'space_2a_auditor',
              'space_2a_developer',
              'space_2b_manager',
              'space_2b_auditor',
              'space_2b_developer',
            ]
            ))
        end
      end
      context 'when an org manager lists users' do
        it 'sees all the org users in managed org' do
          expect(User.readable_users_for_current_user(false, org_1_manager).map(&:guid)).
            to(match_array([
              'org_1_manager',
              'org_1_billing_manager',
              'org_1_auditor',
              'space_1a_manager',
              'space_1a_auditor',
              'space_1a_developer']
            ))
        end
      end
      context 'when an {org_billing_manager, org_auditor} lists users' do
        it 'sees only the "managerial" org users' do
          [org_1_billing_manager, org_1_auditor].each do |privileged_user|
            expect(User.readable_users_for_current_user(false, privileged_user).map(&:guid)).
              to(match_array([
                'org_1_manager',
                'org_1_billing_manager',
                'org_1_auditor']
              ))
          end
        end
      end
      context 'when a space {manager,auditor,developer} lists users' do
        it 'sees the "managerial" org users and the users in its space' do
          [space_1a_manager, space_1a_auditor, space_1a_developer].each do |space_user|
            expect(User.readable_users_for_current_user(false, space_user).map(&:guid)).
              to(match_array([
                'org_1_manager',
                'org_1_billing_manager',
                'org_1_auditor',
                'space_1a_manager',
                'space_1a_auditor',
                'space_1a_developer']
              ))
          end

          [space_2a_manager, space_2a_auditor, space_2a_developer].each do |space_user|
            expect(User.readable_users_for_current_user(false, space_user).map(&:guid)).
              to(match_array([
                'space_2a_manager',
                'space_2a_auditor',
                'space_2a_developer']
              ))
          end
        end
      end
    end


    describe '#membership_spaces' do
      let(:user) { User.make }
      let(:organization) { Organization.make }

      let(:developer_space) { Space.make organization: organization }
      let(:auditor_space) { Space.make organization: organization }
      let(:manager_space) { Space.make organization: organization }

      before do
        organization.add_user user

        manager_space.add_manager user
        auditor_space.add_auditor user
        developer_space.add_developer user
      end

      it 'returns a list of spaces that the user is a member of' do
        ids = user.membership_spaces.all.map(&:id)
        expect(ids).to match_array([developer_space, manager_space, auditor_space].map(&:id))
      end

      it "omits spaces that the user isn't a member of" do
        outside_user = User.make guid: 'outside_user_guid'
        organization.add_user outside_user

        different_space = Space.make organization: organization

        different_space.add_developer outside_user

        ids = user.membership_spaces.all.map(&:id)
        expect(ids).to match_array([developer_space, manager_space, auditor_space].map(&:id))
      end
    end

    describe '#visible_users_in_my_spaces' do
      let(:user_organization) { Organization.make }

      let(:developer_space) { Space.make(organization: user_organization) }
      let(:auditor_space) { Space.make(organization: user_organization) }
      let(:manager_space) { Space.make(organization: user_organization) }
      let(:outside_space) { Space.make(organization: user_organization) }

      let(:other_user1) { User.make(guid: 'other_user1.guid') }
      let(:other_user2) { User.make(guid: 'other_user2.guid') }
      let(:other_user3) { User.make(guid: 'other_user3.guid') }
      let(:other_user_in_outside_space) { User.make(guid: 'other_user_in_outside_space_guid') }

      before do
        # Add other users as org members in order to assign space roles to them
        user_organization.add_user(other_user1)
        user_organization.add_user(other_user2)
        user_organization.add_user(other_user3)
        user_organization.add_user(other_user_in_outside_space)

        # Assign space roles
        manager_space.add_manager(other_user1)
        auditor_space.add_auditor(other_user2)
        developer_space.add_developer(other_user3)
        outside_space.add_developer(other_user_in_outside_space)
      end

      it 'returns a list of users in spaces that the user is a member of' do
        space_manager = User.make
        space_auditor = User.make
        space_developer = User.make

        user_organization.add_user(space_manager)
        user_organization.add_user(space_auditor)
        user_organization.add_user(space_developer)

        manager_space.add_manager(space_manager)
        auditor_space.add_auditor(space_auditor)
        developer_space.add_developer(space_developer)

        result = space_manager.visible_users_in_my_spaces.all.map(&:id)
        expect(result).to match_array([
          space_manager.id,
          other_user1.id,
        ])

        result2 = space_auditor.visible_users_in_my_spaces.all.map(&:id)
        expect(result2).to match_array([
          space_auditor.id,
          other_user2.id,
        ])

        result3 = space_developer.visible_users_in_my_spaces.all.map(&:id)
        expect(result3).to match_array([
          space_developer.id,
          other_user3.id,
        ])
      end
    end

    describe '#membership_organizations' do
      let(:user) { User.make }
      let(:user_organization) { Organization.make }
      let(:manager_organization) { Organization.make }
      let(:auditor_organization) { Organization.make }
      let(:billing_manager_organization) { Organization.make }

      before do
        user_organization.add_user user
        manager_organization.add_manager user
        auditor_organization.add_auditor user
        billing_manager_organization.add_billing_manager user
      end

      it 'returns a list of orgs that the user is a member of' do
        ids = user.membership_organizations.all.map(&:id)

        expect(ids).to match_array([
          user_organization,
          manager_organization,
          auditor_organization,
          billing_manager_organization
        ].map(&:id))
      end

      it "omits orgs that the user isn't a member of" do
        outside_organization = Organization.make

        ids = user.membership_organizations.all.map(&:id)
        expect(ids).to match_array([
          user_organization,
          billing_manager_organization,
          manager_organization,
          auditor_organization].map(&:id))
      end
    end

    describe '#visible_users_in_my_orgs' do
      let(:user_organization) { Organization.make }
      let(:manager_organization) { Organization.make }
      let(:auditor_organization) { Organization.make }
      let(:billing_manager_organization) { Organization.make }
      let(:outside_organization) { Organization.make }

      let(:other_user1) { User.make(guid: 'other_user1-guid') }
      let(:other_user2) { User.make(guid: 'other_user2-guid') }
      let(:other_user3) { User.make(guid: 'other_user3-guid') }
      let(:other_user4) { User.make(guid: 'other_user4-guid') }
      let(:outside_other_user) { User.make(guid: 'outside_other_user-guid') }

      before do
        user_organization.add_user(other_user1)
        manager_organization.add_manager(other_user2)
        manager_organization.add_user(other_user1)
        auditor_organization.add_auditor(other_user3)
        billing_manager_organization.add_billing_manager(other_user4)
        outside_organization.add_billing_manager(outside_other_user)
      end

      it 'returns a list of users in orgs that the user is a member of' do
        user = User.make
        org_manager = User.make
        org_auditor = User.make
        org_billing_manager = User.make

        user_organization.add_user(user)
        manager_organization.add_manager(org_manager)
        auditor_organization.add_auditor(org_auditor)
        billing_manager_organization.add_billing_manager(org_billing_manager)

        user_result = user.visible_users_in_my_orgs.all.map(&:id)
        expect(user_result).to match_array([],)
        manager_result = org_manager.visible_users_in_my_orgs.all.map(&:id)
        expect(manager_result).to match_array(
          [
            org_manager.id,
            other_user1.id,
            other_user2.id,
          ],
        )
        auditor_result = org_auditor.visible_users_in_my_orgs.all.map(&:id)
        expect(auditor_result).to match_array(
          [
            org_auditor.id,
            other_user3.id,
          ],
        )
        billing_manager_result = org_billing_manager.visible_users_in_my_orgs.all.map(&:id)
        expect(billing_manager_result).to match_array(
          [
            org_billing_manager.id,
            other_user4.id
          ],
        )
      end
    end
  end
end
