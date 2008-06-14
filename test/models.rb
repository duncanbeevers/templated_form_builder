class User < ActiveRecord::Base
  has_one :wristband
  validates_presence_of :wristband

  has_many :favorites
  has_many :favorite_wristbands, :through => :favorites, :source => :wristband
end

class Wristband < ActiveRecord::Base
  belongs_to :user
  validates_presence_of :color
end

class Favorite < ActiveRecord::Base
  belongs_to :user
  belongs_to :wristband

  validates_uniqueness_of :wristband_id, :scope => :user_id
end
