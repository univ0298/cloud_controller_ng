Sequel.migration do
  change do
    add_column :apps, :lifecycle_type, String, null: false, default: 'buildpack'
  end
end
