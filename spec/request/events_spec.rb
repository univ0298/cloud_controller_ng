require 'spec_helper'

RSpec.describe 'Events' do
  describe 'GET /v3/audit_events/:guid' do
    let(:user) { make_user }
    let(:user_headers) { headers_for(user) }
    let(:admin_header) { admin_headers_for(user) }
    let!(:app_model) { VCAP::CloudController::AppModel.make }
    let(:update_request) do
      {
        name: 'audit_app'
      }
    end
    let(:event) { VCAP::CloudController::Event.last }

    before do
      patch "/v3/apps/#{app_model.guid}", update_request.to_json, admin_header
    end

    it 'returns details of the requested audit_event' do
      get "/v3/audit_events/#{event.guid}", nil, admin_header
      expect(last_response.status).to eq 200
      expect(parsed_response).to be_a_response_like(
        {
          "guid" => event.guid,
          "created_at" => iso8601,
          "updated_at" => iso8601,
          "type" => "audit.app.update",
          "actor" => {
            "guid" => user.guid,
            "type" => "user",
            "name" => "email-1@somedomain.com" # Why not user.username?
          },
          "target" => {
            "guid" => app_model.guid,
            "type" => "app",
            "name" => "audit_app"
          },
          "data" => {
            "request" => {
              "name" => "audit_app"
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
      )
    end
  end
end
