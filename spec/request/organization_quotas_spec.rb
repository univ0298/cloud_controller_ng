require 'spec_helper'
require 'request_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe 'organization_quotas' do
    let(:user) { VCAP::CloudController::User.make(guid: 'user') }
    let(:space) { VCAP::CloudController::Space.make }
    let(:org) { space.organization }
    let(:admin_header) { headers_for( user , scopes: %w(cloud_controller.admin)) }
    describe 'POST /v3/organization_quotas' do
      let(:api_call) { lambda { |user_headers| post '/v3/organization_quotas', params.to_json, user_headers } }

      let(:params) do
        {
        'name': 'org1',
        }
      end

      let(:organization_quota_json) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          name: params[:name],
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organization_quotas\/#{params[:guid]}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
        )
        h['admin'] = {
          code: 201,
          response_object: organization_quota_json
        }
        h.freeze
      end

      it 'creates a organisation_quota' do
        expect {
          api_call.call(admin_header)
        }.to change {
          QuotaDefinition.count
        }.by 1
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

    end
  end
end
