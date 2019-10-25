require 'messages/role_create_message'
require 'actions/role_create'
require 'presenters/v3/role_presenter'

class RolesController < ApplicationController

  def index
    message = RoleListMessage.from_params(query_params)
    unprocessable!(message.errors.full_messages) unless message.valid?
    roles = fetch_readable_roles(message)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::RolePresenter,
      paginated_result: SequelPaginator.new.get_page(roles, message.try(:pagination_options)),
      path: '/v3/roles',
      message: message,
    )
  end

  def create
    message = RoleCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    user = readable_users.first(guid: message.user_guid)
    unprocessable_user! unless user

    if message.space_guid
      space = Space.find(guid: message.space_guid)
      unprocessable_space! unless space
      org = space.organization

      unprocessable_space! if permission_queryer.can_read_from_org?(org.guid) &&
        !permission_queryer.can_read_from_space?(message.space_guid, org.guid)

      unauthorized! unless permission_queryer.can_update_space?(message.space_guid, org.guid)

    else
      org = Organization.find(guid: message.organization_guid)
      unprocessable_organization! unless org
      unauthorized! unless permission_queryer.can_write_to_org?(message.organization_guid)

    end

    role = RoleCreate.create(message: message)

    render status: :created, json: Presenters::V3::RolePresenter.new(role)
  rescue RoleCreate::Error => e
    unprocessable!(e)
  end

  private

  def fetch_readable_roles(message)
    readable_roles_dataset = Role.readable_roles_for_current_user(permission_queryer.can_read_secrets_globally?, current_user)
    # RoleListFetcher.fetch_all(message, readable_roles_dataset)
  end

  def readable_users
    User.readable_users_for_current_user(permission_queryer.can_read_secrets_globally?, current_user)
  end

  def unprocessable_space!
    unprocessable!('Invalid space. Ensure that the space exists and you have access to it.')
  end

  def unprocessable_organization!
    unprocessable!('Invalid organization. Ensure that the organization exists and you have access to it.')
  end

  def unprocessable_user!
    unprocessable!('Invalid user. Ensure that the user exists and you have access to it.')
  end
end
