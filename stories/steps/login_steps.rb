steps_for(:login) do

  Given "a $role for inventory pool '$ip' logs in as '$who'" do | role, ip, who |
    user = Factory.create_user({:login => who
                                  #, :password => "pass"
                                }, {:role => role})
    post "/session", :login => user.login
                        #, :password => "pass"
    inventory_pool = InventoryPool.find_or_create_by_name(:name => ip)
    get backend_inventory_pool_path(inventory_pool)
    @inventory_pool = assigns(:current_inventory_pool)
    @last_inventory_manager_login_name = who
  end

end