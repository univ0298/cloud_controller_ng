require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Roles' do
  let(:user) { VCAP::CloudController::User.make }
  let(:admin_header) { admin_headers_for(user) }

  describe 'GET /v3/roles' do
    let(:api_call) { lambda { |user_headers| get '/v3/roles', nil, user_headers } }
    let(:user_1) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }

    before do
      space.organization.add_user(user_1)
      space.add_auditor(user_1)
    end

    let(:role_json) do
      {
        # guid: UUID_REGEX,
        # created_at: iso8601,
        # updated_at: iso8601,
        type: 'space_auditor',
        relationships: {
          user: {
            data: { guid: user_1.guid }
          },
          organization: {
            data: nil
          },
          space: {
            data: { guid: space.guid }
          }
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/roles\/#{UUID_REGEX}) },
          user: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{user_1.guid}) },
          space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
        }
      }
    end

    context 'when the user is logged in' do
      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_objects: [role_json]
        )
        #
        # h['admin'] = { code: 200, response_objects: [role_json] }
        # h['admin_read_only'] = { code: 200, response_objects: [role_json] }
        # h['global_auditor'] = { code: 200, response_objects: [role_json] }
        #
        # h['org_billing_manager'] = { code: 200, response_objects: [] }
        # h['no_role'] = { code: 200, response_objects: [] }
        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end
  end
end
