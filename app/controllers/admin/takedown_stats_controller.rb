# frozen_string_literal: true

module Admin
  class TakedownStatsController < ApplicationController
    before_action :admin_only
    respond_to :html

    def index
      @stats = JSON.parse(Cache.redis.get("e6stats_takedown") || "{}")
      respond_with(@stats)
    end
  end
end
