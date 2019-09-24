require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Events' do
  describe 'GET /v3/audit_events/:guid' do
    let(:user) { make_user }
    # let(:user_headers) { headers_for(user) }
    let(:admin_header) { admin_headers_for(user) }
    let!(:app_model) { VCAP::CloudController::AppModel.make }
    let(:update_request) do
      {
        name: 'audit_resource'
      }
    end
    let(:event) { VCAP::CloudController::Event.last }
    let(:space) { app_model.space }
    let(:org) { app_model.space.organization }

    context 'when the audit_event does exist ' do
      let(:api_call) { lambda { |user_headers| get "/v3/audit_events/#{event.guid}", nil, user_headers } }

      context 'the event has a space and org' do
        before do
          patch "/v3/apps/#{app_model.guid}", update_request.to_json, admin_header
        end

        let(:client_json) do
          {
            "guid" => event.guid,
            "created_at" => iso8601,
            "updated_at" => iso8601,
            "type" => "audit.app.update",
            "actor" => {
              "guid" => user.guid,
              "type" => "user",
              "name" => VCAP::CloudController::SecurityContext.current_user_email
            },
            "target" => {
              "guid" => app_model.guid,
              "type" => "app",
              "name" => "audit_resource"
            },
            "data" => {
              "request" => {
                "name" => "audit_resource"
              }
            },
            "space" => {
              "guid" => app_model.space.guid
            },
            "organization" => {
              "guid" => app_model.space.organization.guid
            },
            "links" => {
              "self" => {
                "href" => "#{link_prefix}/v3/audit_events/#{event.guid}"
              }
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_object: client_json
          )
          h['space_manager'] = {
            code: 404,
            response_object: []
          }
          h['org_manager'] = {
            code: 404,
            response_object: []
          }
          h['org_billing_manager'] = {
            code: 404,
            response_object: []
          }
          h['no_role'] = {
            code: 404,
            response_object: []
          }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'the event only has an org' do
        before do
          patch "/v3/organizations/#{org.guid}", update_request.to_json, admin_header
        end

        let(:client_json) do
          {
            "guid" => event.guid,
            "created_at" => iso8601,
            "updated_at" => iso8601,
            "type" => "audit.organization.update",
            "actor" => {
              "guid" => user.guid,
              "type" => "user",
              "name" => VCAP::CloudController::SecurityContext.current_user_email
            },
            "target" => {
              "guid" => org.guid,
              "type" => "organization",
              "name" => "audit_resource"
            },
            "data" => {
              "request" => {
                "name" => "audit_resource"
              }
            },
            "space" => nil,
            "organization" => {
              "guid" => org.guid
            },
            "links" => {
              "self" => {
                "href" => "#{link_prefix}/v3/audit_events/#{event.guid}"
              }
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_object: client_json
          )
          h['space_auditor'] = {
            code: 404,
            response_object: []
          }
          h['space_developer'] = {
            code: 404,
            response_object: []
          }
          h['space_manager'] = {
            code: 404,
            response_object: []
          }
          h['org_manager'] = {
            code: 404,
            response_object: []
          }
          h['org_billing_manager'] = {
            code: 404,
            response_object: []
          }
          h['no_role'] = {
            code: 404,
            response_object: []
          }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'when the audit_event does not exist' do
      it 'returns a 404' do
        get  "/v3/audit_events/does-not-exist", nil, admin_header
        expect(last_response.status).to eq 404
        expect(last_response).to have_error_message('Event not found')
      end
    end
  end
end
