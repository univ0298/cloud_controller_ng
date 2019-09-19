Sequel.migration do
  change do
    create_table :roles do
      VCAP::Migration.common(self)
      String :type, size: 255, null: false
      Integer :user_id
      foreign_key [:user_id], :users, name: :fk_role_user_id
      Integer :space_id
      foreign_key [:space_id], :spaces, name: :fk_role_space_id
    end
  end
end
