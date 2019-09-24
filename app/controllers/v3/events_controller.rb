require 'presenters/v3/event_presenter'

class EventsController < ApplicationController
  def show

    event = VCAP::CloudController::Event.find(guid: hashed_params[:guid])
    event_not_found! unless event && is_authorized?(event)

    render status: :ok, json: Presenters::V3::EventPresenter.new(event)
  end

  private

  def event_not_found!
    resource_not_found!(:event)
  end

  def is_authorized?(event)
    if event.space_guid
      permission_queryer.can_audit_space?(event.space_guid, event.organization_guid)
    else
      permission_queryer.can_audit_org?(event.organization_guid)
    end
  end
end
