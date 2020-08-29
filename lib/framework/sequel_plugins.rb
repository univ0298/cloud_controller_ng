require 'framework/sequel_plugins/vcap_validations'
require 'framework/sequel_plugins/vcap_serialization'
require 'framework/sequel_plugins/vcap_normalization'
require 'framework/sequel_plugins/vcap_relations'
require 'framework/sequel_plugins/vcap_guid'

Sequel::Model.plugin :vcap_validations
Sequel::Model.plugin :vcap_serialization
Sequel::Model.plugin :vcap_normalization
Sequel::Model.plugin :vcap_relations
Sequel::Model.plugin :vcap_guid

Sequel::Model.plugin :association_dependencies
