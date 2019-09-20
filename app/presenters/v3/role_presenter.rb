module VCAP::CloudController::Presenters::V3
  class RolePresenter < BasePresenter
    def to_hash
      {
        guid: role[:guid],
        created_at: role[:created_at],
        updated_at: role[:updated_at],
        type: role[:type],
        relationships: build_relationships,
        links: build_links
      }
    end

    private

    def role
      @resource
    end

    def build_relationships
      {
        user: {
          data: { guid: role[:user_guid] }
        },
        organization: {
          data: if role[:organization_guid]
                  { guid: role[:organization_guid] }
                end
        },
        space: {
          data: if role[:space_guid]
                  { guid: role[:space_guid] }
                end
        }
      }
    end

    def build_links
      links = {
        self: { href: url_builder.build_url(path: "/v3/roles/#{role[:guid]}") },
        user: { href: url_builder.build_url(path: "/v3/users/#{role[:user_guid]}") },
      }

      if role[:organization_guid]
        links[:organization] = {
          href: url_builder.build_url(path: "/v3/organizations/#{role[:organization_guid]}")
        }
      end

      if role[:space_guid]
        links[:space] = {
          href: url_builder.build_url(path: "/v3/spaces/#{role[:space_guid]}")
        }
      end

      links
    end

    def url_builder
      @url_builder ||= VCAP::CloudController::Presenters::ApiUrlBuilder.new
    end
  end
end
