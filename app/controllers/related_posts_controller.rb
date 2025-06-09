# frozen_string_literal: true

class RelatedPostsController < ApplicationController
  respond_to :json, :html, only: [:show]
  # respond_to :json, only: [:bulk]
  before_action :member_only

  def show
    puts params[:search]
    @related_posts = RelatedPostQuery.new(id: params[:search][:id], post: params[:search][:post], query: params[:search][:query])
    # expires_in 30.seconds
    respond_with(@related_posts)
  end

  # def bulk
  #   @related_tags = BulkRelatedTagQuery.new(query: params[:query], category_id: params[:category_id])
  #   respond_with(@related_tags) do |fmt|
  #     fmt.json do
  #       render json: @related_tags.to_json
  #     end
  #   end
  # end
end
