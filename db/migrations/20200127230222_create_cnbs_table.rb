Sequel.migration do
  change do
    create_table :cloud_native_buildpacks do
      VCAP::Migration.common(self)
      String :name, size: 255
      String :version, size: 255
      String :stack, size: 255
      String :image, size: 255
      String :builder, size: 255
  end
end
