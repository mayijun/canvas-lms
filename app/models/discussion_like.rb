class DiscussionLike < ActiveRecord::Base
  include Workflow

  attr_readonly :discussion_topic_id, :user_id, :workflow_state
  attr_accessible :discussion_topic, :user

  belongs_to :user
  belongs_to :discussion_topic

  EXPORTABLE_ATTRIBUTES = [:id, :discussion_topic_id, :user_id, :workflow_state ]
  EXPORTABLE_ASSOCIATIONS = [:discussion_topic, :user]


  validates_presence_of :discussion_topic_id, :user_id
  # attr_accessible :title, :body
end
