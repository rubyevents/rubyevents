class WatchListsController < ApplicationController
  include WatchedTalks

  before_action :authenticate_user!
  before_action :set_watch_list, only: [:show, :edit, :update, :destroy]

  def index
    @watch_lists = Current.user.watch_lists
    @watch_list = Current.user.default_watch_list
  end

  def show
  end

  def new
    @watch_list = Current.user.watch_lists.new
  end

  def create
    @watch_list = Current.user.watch_lists.new(watch_list_params)
    if @watch_list.save
      redirect_to @watch_list, notice: "WatchList was successfully created."
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @watch_list.update(watch_list_params)
      redirect_to @watch_list, notice: "WatchList was successfully updated."
    else
      render :edit
    end
  end

  def destroy
    @watch_list.destroy
    redirect_to watch_lists_url, notice: "WatchList was successfully destroyed."
  end

  private

  def set_watch_list
    @watch_list = Current.user.watch_lists.find(params[:id])
  end

  def watch_list_params
    params.require(:watch_list).permit(:name, :description)
  end
end
