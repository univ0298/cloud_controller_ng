require 'framework/sequel_plugins'
require 'sequel_plugins/update_or_create'
require 'sequel_plugins/vcap_user_group'
require 'sequel_plugins/vcap_user_visibility'

Sequel::Model.plugin :vcap_user_group
Sequel::Model.plugin :vcap_user_visibility
Sequel::Model.plugin :update_or_create
