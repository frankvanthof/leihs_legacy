class Borrow::InventoryPoolsController < Borrow::ApplicationController
  def index
    @inventory_pools = current_user.inventory_pools.reorder(:name)
  end
end
