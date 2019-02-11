module Delegation::Reservation
  def self.included(base)
    base.class_eval { belongs_to :delegated_user, class_name: 'User' }
  end
end
