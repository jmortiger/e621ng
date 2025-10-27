# frozen_string_literal: true

class ResourceAbilitiesController < ApplicationController
  before_action :set_resource_ability, only: %i[show edit update destroy]

  # GET /resource_abilities
  def index
    @resource_abilities = ResourceAbility.all
  end

  # GET /resource_abilities/1
  def show
  end

  # GET /resource_abilities/new
  def new
    @resource_ability = ResourceAbility.new
  end

  # GET /resource_abilities/1/edit
  def edit
  end

  # POST /resource_abilities
  def create
    @resource_ability = ResourceAbility.new(resource_ability_params)

    if @resource_ability.save
      redirect_to @resource_ability, notice: "Resource ability was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /resource_abilities/1
  def update
    if @resource_ability.update(resource_ability_params)
      redirect_to @resource_ability, notice: "Resource ability was successfully updated.", status: 303
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /resource_abilities/1
  def destroy
    @resource_ability.destroy!
    redirect_to resource_abilities_url, notice: "Resource ability was successfully destroyed.", status: 303
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_resource_ability
    @resource_ability = ResourceAbility.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def resource_ability_params
    params.require(:resource_ability).permit(:active_permissions, :active_restrictions)
  end
end
