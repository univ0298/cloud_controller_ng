class OrganizationQuotasController < ApplicationController

  def create
    unauthorized! unless permission_queryer.can_write_globally?

    message = VCAP::CloudController::OrganizationQuotasCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    organization_quota = QuotaDefinition.new.create(message: message)
    organization_quota SpaceCreate.new(perm_client: perm_client, user_audit_info: user_audit_info).create(org, message)

    render json: Presenters::V3::OrganizationPresenter.new(organization_quota), status: :created
  rescue OrganizationCreate::Error => e
    unprocessable!(e.message)
  end

end
