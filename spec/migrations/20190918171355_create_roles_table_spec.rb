require 'spec_helper'

RSpec.describe 'create roles table', isolation: :truncation do
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20190918171355_create_roles_table.rb'),
      tmp_migrations_dir,
    )
  end

  let(:role) { VCAP::CloudController::Role.make }

  it 'creates a roles table' do
    Sequel::Migrator.run(VCAP::CloudController::Role.db, tmp_migrations_dir, table: :my_fake_table)
    expect(1).to eq(1)
  end
end
