require 'spec_helper'
require 'actions/organization_quotas_update'
require 'messages/organization_quotas_update_message'

module VCAP::CloudController
  RSpec.describe OrganizationQuotasUpdate do
    describe 'update' do
      subject(:org_quotas_update) { OrganizationQuotasUpdate.new }

      context 'when updating a organization quota' do
        let(:org) { VCAP::CloudController::Organization.make }
        let(:org_quota ) {VCAP::CloudController::OrganizationQuota.make}

        let(:message) do
          VCAP::CloudController::OrganizationQuotasUpdateMessage.new({
              name: 'don-quixote',
              apps: {
                total_memory_in_mb: 5120,
                per_process_memory_in_mb: 1024,
                total_instances: 10,
                per_app_tasks: 5
              },
              services: {
                paid_services_allowed: true,
                total_service_instances: 10,
                total_service_keys: 20,
              },
              route: {
                total_routes: 8,
                total_reserved_ports: 4
              },
              domains: {
                total_private_domains: 7
              }
          })
        end

        # let(:minimum_message) do
        #   VCAP::CloudController::OrganizationQuotasCreateMessage.new({
        #     'name' => 'my-name',
        #     'relationships' => { organizations: { data: [] } },
        #   })
        # end

        # let(:message_with_org) do
        #   VCAP::CloudController::OrganizationQuotasCreateMessage.new({
        #     'name' => 'my-name',
        #     'relationships' => { organizations: { data: [{ guid: org.guid }] } },
        #   })
        # end

        it 'updates an organization quota with the correct values' do
          updated_organization_quota = org_quotas_update.update(org_quota, message)

          expect(organization_quota.name).to eq('don-quixote')

          # expect(organization_quota.memory_limit).to eq(5120)
          # expect(organization_quota.instance_memory_limit).to eq(10)
          # expect(organization_quota.app_instance_limit).to eq(3)
          # expect(organization_quota.app_task_limit).to eq(5)

          # expect(organization_quota.total_services).to eq(10)
          # expect(organization_quota.total_service_keys).to eq(20)
          # expect(organization_quota.non_basic_services_allowed).to eq(true)

          # expect(organization_quota.total_reserved_route_ports).to eq(4)
          # expect(organization_quota.total_routes).to eq(8)

          # expect(organization_quota.total_private_domains).to eq(7)

        end

      # context 'when a model validation fails' do
      #   it 'raises an error' do
      #     errors = Sequel::Model::Errors.new
      #     errors.add(:blork, 'is busted')
      #     expect(VCAP::CloudController::QuotaDefinition).to receive(:create).
      #       and_raise(Sequel::ValidationFailed.new(errors))

      #     message = VCAP::CloudController::OrganizationQuotasCreateMessage.new(name: 'foobar')
      #     expect {
      #       org_quotas_create.create(message)
      #     }.to raise_error(OrganizationQuotasCreate::Error, 'blork is busted')
      #   end

        # context 'when it is a uniqueness error' do
        #   let(:name) { 'Olsen' }
        #   let(:message) { VCAP::CloudController::OrganizationQuotasCreateMessage.new(name: name) }

        #   before do
        #     org_quotas_create.create(message)
        #   end

        #   it 'raises a human-friendly error' do
        #     expect {
        #       org_quotas_create.create(message)
        #     }.to raise_error(OrganizationQuotasCreate::Error, "Organization Quota '#{name}' already exists.")
        #   end
        # end
        # context 'when the org guid is invalid' do
        #   let(:invalid_org_guid) { 'invalid_org_guid' }
        #   let(:message_with_invalid_org_guid) do
        #     VCAP::CloudController::OrganizationQuotasCreateMessage.new({
        #       'name' => 'my-name',
        #       'relationships' => { organizations: { data: [{ guid: invalid_org_guid }] } },
        #     })
        #   end
        #   it 'raises a human-friendly error' do
        #     expect {
        #       org_quotas_create.create(message_with_invalid_org_guid)
        #     }.to raise_error(OrganizationQuotasCreate::Error, "Organization with guid '#{invalid_org_guid}' does not exist, or you do not have access to it.")
        #   end
        # end
      end
    end
  end
end
