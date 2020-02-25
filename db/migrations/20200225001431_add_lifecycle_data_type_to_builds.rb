Sequel.migration do
  change do
    add_column :builds, :lifecycle_type, String, null: false, default: 'buildpack'
  end
end
