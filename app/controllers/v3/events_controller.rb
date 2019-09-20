require 'presenters/v3/event_presenter'

class EventsController < ApplicationController
  def show
    event = VCAP::CloudController::Event.find(guid: hashed_params[:guid])
    event_not_found! unless event

    render status: :ok, json: Presenters::V3::EventPresenter.new(event)
  end

  def event_not_found!
    resource_not_found!(:event)
  end
end
