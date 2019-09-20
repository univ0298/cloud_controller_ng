module VCAP::CloudController
  class RoleListFetcher
    class << self
      def fetch_all
        Space.db[:spaces_auditors]
          .join_table(:inner, :spaces, id: :space_id)
          .join_table(:inner, :users, id: :spaces_auditors__user_id)
          .select(
            Sequel.as("space_auditor", :type),
            Sequel.as(:spaces__guid, :space_guid),
            Sequel.as(nil, :organization_guid),
            Sequel.as(:users__guid, :user_guid)
          )
      end
    end
  end
end

# SELECT * FROM "spaces" INNER JOIN "spaces_auditors" ON ("spaces_auditors"."space_id" = "spaces"."id") INNER JOIN "users" ON ("users"."id" = "spaces_auditors"."user_id")
