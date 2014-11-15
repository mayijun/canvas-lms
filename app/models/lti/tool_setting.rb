# Copyright (C) 2014 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

module Lti
  class ToolSetting < ActiveRecord::Base
    attr_accessible :tool_proxy, :context, :resource_link_id, :custom

    belongs_to :tool_proxy
    belongs_to :context, polymorphic: true

    validates_presence_of :tool_proxy
    validates_presence_of :context, if: :has_resource_link_id?
    validates_inclusion_of :context_type, :allow_nil => true, :in => ['Course', 'Account']

    serialize :custom


    private
    def has_resource_link_id?
      resource_link_id.present?
    end

  end
end