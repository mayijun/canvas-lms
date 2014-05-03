#
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

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../views_helper')

describe "context/undelete_index.html.erb" do
  before do
    course_with_teacher(:active_all => true)
    assigns[:context] = @course
  end

  it "should render the undelete link correctly for quizzes" do
    quiz = @course.quizzes.create!
    assigns[:deleted_items] = [quiz]
    render
    response.body.should_not =~ /quizzes:quiz/
    response.body.should =~ /quiz_#{quiz.id}/
  end
end
