class CreateDiscussionLikes < ActiveRecord::Migration
  tag :predeploy
  def change
    create_table :discussion_likes do |t|
      t.references :user
      t.references :discussion_topic

      t.timestamps
    end
    add_index :discussion_likes, :user_id
    add_index :discussion_likes, :discussion_topic_id
  end
end
