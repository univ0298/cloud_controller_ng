Sequel.migration do
  change do
    alter_table :kpack_lifecycle_data do
      add_column :app_guid, String
    end
  end
end
