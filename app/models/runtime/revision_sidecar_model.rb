module VCAP::CloudController
  class RevisionSidecarModel < Sequel::Model(:revision_sidecars)
    include SidecarMixin

    many_to_one :revision,
      class: 'VCAP::CloudController::RevisionModel',
      key: :revision_guid,
      primary_key: :guid,
      without_guid_generation: true

    one_to_many :revision_sidecar_process_types,
      class: 'VCAP::CloudController::RevisionSidecarProcessTypeModel',
      key: :revision_sidecar_guid,
      primary_key: :guid

    alias_method :sidecar_process_types, :revision_sidecar_process_types

    add_association_dependencies revision_sidecar_process_types: :destroy

    def hydrate
      sidecar = SidecarModel.create(
        app_guid: revision.app.guid,
        name: name,
        command: command,
        memory: memory,
      )

      revision_sidecar_process_types.each do |revision_sidecar_process_type|
        SidecarProcessTypeModel.create(
          type: revision_sidecar_process_type.type,
          sidecar_guid: sidecar.guid,
          app_guid: sidecar.app_guid,
        )
      end
    end

    def validate
      super
      validates_presence [:name, :command]
      validates_max_length 255, :name, message: Sequel.lit('Name is too long (maximum is 255 characters)')
      validates_max_length 4096, :command, message: Sequel.lit('Command is too long (maximum is 4096 characters)')
      validates_unique [:revision_guid, :name], message: Sequel.lit("Sidecar with name '#{name}' already exists for given revision")
    end
  end
end
