module App
  
  class Root
    
    include Dot::App
    
    map :index
    map :status, 'status/:type'
    map :admin, ':group/administrate', :rules=>{:group=>/^us$|^them$/}
    
    def index
      'The index action'
    end
    
    def status
      "Status for <em>#{request.params[:type]}</em>"
    end
    
    def admin
      admin_response = forward_to Admin
      "<h1>Admin</h2>#{admin_response}"
    end
    
  end
  
  class Admin
    
    include Dot::App
    
    map :index
    
    def index
      "Administrate #{request.params[:group]}"
    end
    
  end
  
end