require 'presenters/v3/role_presenter'
require 'fetchers/role_list_fetcher'
require 'messages/roles_list_message'

class RolesController < ApplicationController
  def index
    # step 1 is to only query the spaces_auditors table
    # add guid if it doesnt exist
    #   generate a guid and created_at entry
    # return the data
    # TODO: talk to all 7 joint roles tables
    #
    message = RolesListMessage.from_params(query_params)
    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::RolePresenter,
      paginated_result: SequelPaginator.new.get_page(RoleListFetcher.fetch_all, message.try(:pagination_options)),
      path: '/v3/roles',
      message: message
    )
  end
end
