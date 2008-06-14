ActiveRecord::Schema.define(:version => 0) do
  create_table :users, :force => true do |t|
    t.string :username
  end

  create_table :wristbands, :force => true do |t|
    t.string :color

    t.integer :something_id
    t.string :something_type
  end

  create_table :favorites, :force => true do |t|
    t.integer :user_id
    t.integer :wristband_id
  end
end
