require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Events' do
  describe 'GET /v3/audit_events' do
    let(:user) { make_user }
    let(:user_audit_info) {
      VCAP::CloudController::UserAuditInfo.new(user_guid: user.guid, user_email: 'user@example.com')
    }
    let(:space) { VCAP::CloudController::Space.make }
    let(:org) { space.organization }
    let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }

    let!(:unscoped_event) {
      VCAP::CloudController::Repositories::OrphanedBlobEventRepository.record_delete('dir', 'key')
    }
    let!(:org_scoped_event) {
      VCAP::CloudController::Repositories::OrganizationEventRepository.new.record_organization_create(
        org,
        user_audit_info,
        { key: 'val' }
      )
    }
    let!(:space_scoped_event) {
      VCAP::CloudController::Repositories::AppEventRepository.new.record_app_restart(
        app_model,
        user_audit_info,
      )
    }

    let(:unscoped_event_json) do
      {
        guid: unscoped_event.guid,
        created_at: iso8601,
        updated_at: iso8601,
        type: 'blob.remove_orphan',
        actor: {
          guid: 'system',
          type: 'system',
          name: 'system'
        },
        target: {
          guid: 'dir/key',
          type: 'blob',
          name: ''
        },
        data: {},
        space: nil,
        organization: nil,
        links: {
          self: {
            href: "#{link_prefix}/v3/audit_events/#{unscoped_event.guid}"
          }
        }
      }
    end

    let(:org_scoped_event_json) do
      {
        guid: org_scoped_event.guid,
        created_at: iso8601,
        updated_at: iso8601,
        type: 'audit.organization.create',
        actor: {
          guid: user_audit_info.user_guid,
          type: 'user',
          name: user_audit_info.user_email
        },
        target: {
          guid: org.guid,
          type: 'organization',
          name: org.name
        },
        data: {
          request: {
            key: 'val'
          }
        },
        space: nil,
        organization: {
          guid: org.guid
        },
        links: {
          self: {
            href: "#{link_prefix}/v3/audit_events/#{org_scoped_event.guid}"
          }
        }
      }
    end

    let(:space_scoped_event_json) do
      {
        guid: space_scoped_event.guid,
        created_at: iso8601,
        updated_at: iso8601,
        type: 'audit.app.restart',
        actor: {
          guid: user_audit_info.user_guid,
          type: 'user',
          name: user_audit_info.user_email
        },
        target: {
          guid: app_model.guid,
          type: 'app',
          name: app_model.name
        },
        data: {},
        space: {
          guid: space.guid
        },
        organization: {
          guid: org.guid
        },
        links: {
          self: {
            href: "#{link_prefix}/v3/audit_events/#{space_scoped_event.guid}"
          }
        }
      }
    end

    context 'without filters' do
      let(:api_call) { lambda { |user_headers| get '/v3/audit_events', nil, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 200, response_objects: [])

        h['admin'] = { code: 200, response_objects: [unscoped_event_json, org_scoped_event_json, space_scoped_event_json] }
        h['admin_read_only'] = { code: 200, response_objects: [unscoped_event_json, org_scoped_event_json, space_scoped_event_json] }
        h['global_auditor'] = { code: 200, response_objects: [unscoped_event_json, org_scoped_event_json, space_scoped_event_json] }

        h['space_auditor'] = { code: 200, response_objects: [space_scoped_event_json] }
        h['space_developer'] = { code: 200, response_objects: [space_scoped_event_json] }

        h['org_auditor'] = { code: 200, response_objects: [org_scoped_event_json, space_scoped_event_json] }

        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end
  end

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
