require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Events' do
  describe 'GET /v3/audit_events/:guid' do
    let(:user) { make_user }
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
    let(:api_call) { lambda { |user_headers| get "/v3/audit_events/#{event.guid}", nil, user_headers } }

    def generate_event_in_space
      patch "/v3/apps/#{app_model.guid}", update_request.to_json, admin_header
    end

    def generate_event_in_org_not_in_space
      patch "/v3/organizations/#{org.guid}", update_request.to_json, admin_header
    end

    context 'when the audit_event does exist ' do
      context 'when the event happens in a space' do
        # Generate an audit event in a space
        before do
          generate_event_in_space
        end

        let(:space_guid) { app_model.space.guid }

        let(:event_json) do
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
              "guid" => space_guid
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
            response_object: event_json
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

        context 'and the space has been deleted' do

          before do
            delete "/v3/spaces/#{space.guid}", nil, admin_header
          end

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_object: event_json
            )
            h.freeze
          end

          it_behaves_like 'permissions for single object endpoint', %w(admin admin_read_only global_auditor org_auditor)
        end
      end

      context 'when the event happens in an org' do
        before do
          generate_event_in_org_not_in_space
        end

        let(:event_json) do
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
            response_object: event_json
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

        context 'and the org has been deleted' do
          before do
            delete "/v3/organizations/#{org.guid}", nil, admin_header
          end

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_object: event_json
            )
            h.freeze
          end

          it_behaves_like 'permissions for single object endpoint', %w(admin admin_read_only global_auditor)

        end
      end

      context 'when the event has neither space nor org' do
        let(:event) {
          event = VCAP::CloudController::Repositories::OrphanedBlobEventRepository.record_delete('cc-buildpacks', 'so/me/blobstore-file')
          event.reload
        }

        let(:event_json) do
          {
            "guid" => event.guid,
            "created_at" => iso8601,
            "updated_at" => iso8601,
            "type" => "blob.remove_orphan",
            "actor" => {
              "guid" => "system",
              "type" => "system",
              "name" => "system"
            },
            "target" => {
              "guid" => "cc-buildpacks/so/me/blobstore-file",
              "type" => "blob",
              "name" => ""
            },
            "data" => {},
            "space" => nil,
            "organization" => nil,
            "links" => {
              "self" => {
                "href" => "#{link_prefix}/v3/audit_events/#{event.guid}"
              }
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 404,
            response_object: []
          )
          %w(admin admin_read_only global_auditor).each do |role|
            h[role] = {
              code: 200,
              response_object: event_json
            }
          end
          h.freeze
        end

        # This won't work because we need an `api_call`
        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'when the audit_event does not exist' do
      it 'returns a 404' do
        get "/v3/audit_events/does-not-exist", nil, admin_header
        expect(last_response.status).to eq 404
        expect(last_response).to have_error_message('Event not found')
      end
    end
  end
end
