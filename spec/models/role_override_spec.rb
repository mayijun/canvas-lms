#
# Copyright (C) 2011 Instructure, Inc.
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

require File.expand_path(File.dirname(__FILE__) + '/../sharding_spec_helper.rb')

describe RoleOverride do
  it "should retain the prior permission when it encounters the first explicit override" do
    @account = account_model(:parent_account => Account.default)
    RoleOverride.create!(:context => @account, :permission => 'moderate_forum',
                         :enrollment_type => "TeacherEnrollment", :enabled => false)
    permissions = RoleOverride.permission_for(Account.default, Account.default, :moderate_forum, "TeacherEnrollment")
    expect(permissions[:enabled]).to be_truthy
    expect(permissions[:prior_default]).to be_truthy
    expect(permissions[:explicit]).to eq false

    permissions = RoleOverride.permission_for(@account, @account, :moderate_forum, "TeacherEnrollment")
    expect(permissions[:enabled]).to be_falsey
    expect(permissions[:prior_default]).to be_truthy
    expect(permissions[:explicit]).to eq true
  end

  it "should use the immediately parent context as the prior permission when there are multiple explicit levels" do
    a1 = account_model
    a2 = account_model(:parent_account => a1)
    a3 = account_model(:parent_account => a2)

    RoleOverride.create!(:context => a1, :permission => 'moderate_forum',
                         :enrollment_type => "TeacherEnrollment", :enabled => false)
    RoleOverride.create!(:context => a2, :permission => 'moderate_forum',
                         :enrollment_type => "TeacherEnrollment", :enabled => true)

    permissions = RoleOverride.permission_for(a1, a1, :moderate_forum, "TeacherEnrollment")
    expect(permissions[:enabled]).to be_falsey
    expect(permissions[:prior_default]).to be_truthy
    expect(permissions[:explicit]).to eq true

    permissions = RoleOverride.permission_for(a2, a2, :moderate_forum, "TeacherEnrollment")
    expect(permissions[:enabled]).to be_truthy
    expect(permissions[:prior_default]).to be_falsey
    expect(permissions[:explicit]).to eq true

    permissions = RoleOverride.permission_for(a3, a3, :moderate_forum, "TeacherEnrollment")
    expect(permissions[:enabled]).to be_truthy
    expect(permissions[:prior_default]).to be_truthy
    expect(permissions[:explicit]).to eq false
  end

  it "should not fail when a context's associated accounts are missing" do
    group_model
    @group.stubs(:account).returns(nil)
    expect {
      RoleOverride.permission_for(@group, @group, :read_course_content, "TeacherEnrollment")
    }.not_to raise_error
  end

  describe "student view permissions" do
    it "should mirror student permissions" do
      permission = 'comment_on_others_submissions'

      course_with_teacher(:active_all => true)
      student_in_course(:active_all => true)
      @fake_student = @course.student_view_student

      expect(@student.enrollments.first.has_permission_to?(permission.to_sym)).to be_falsey
      expect(@fake_student.enrollments.first.has_permission_to?(permission.to_sym)).to be_falsey

      RoleOverride.manage_role_override(Account.default, 'StudentEnrollment', permission, :override => true)
      RoleOverride.clear_cached_contexts

      expect(@student.enrollments.first.has_permission_to?(permission.to_sym)).to be_truthy
      expect(@fake_student.enrollments.first.has_permission_to?(permission.to_sym)).to be_truthy
    end
  end

  describe "manage_role_override" do
    before :once do
      @account = account_model(:parent_account => Account.default)
      @role = 'NewRole'
      @permission = 'read_reports'
    end

    describe "override already exists" do
      before :once do
        @existing_override = @account.role_overrides.build(
          :permission => @permission,
          :enrollment_type => @role)
        @existing_override.enabled = true
        @existing_override.locked = false
        @existing_override.save!
        @initial_count = @account.role_overrides.size
      end

      it "should update an existing override if override has a value" do
        new_override = RoleOverride.manage_role_override(@account, @role, @permission, :override => false)
        expect(@account.role_overrides.size).to eq @initial_count
        expect(new_override).to eq @existing_override.reload
        expect(@existing_override.enabled).to be_falsey
      end

      it "should update an existing override if override is nil but locked is truthy" do
        new_override = RoleOverride.manage_role_override(@account, @role, @permission, :locked => true)
        expect(@account.role_overrides.size).to eq @initial_count
        expect(new_override).to eq @existing_override.reload
        expect(@existing_override.locked).to be_truthy
      end

      it "should only update the parts that are specified" do
        new_override = RoleOverride.manage_role_override(@account, @role, @permission, :override => false)
        @existing_override.reload
        expect(@existing_override.locked).to be_falsey

        @existing_override.enabled = true
        @existing_override.save

        new_override = RoleOverride.manage_role_override(@account, @role, @permission, :locked => true)
        @existing_override.reload
        expect(@existing_override.enabled).to be_truthy
      end

      it "should delete an existing override if override is nil and locked is not truthy" do
        new_override = RoleOverride.manage_role_override(@account, @role, @permission, :locked => false)
        expect(@account.role_overrides.size).to eq @initial_count - 1
        expect(new_override).to be_nil
        expect(RoleOverride.where(id: @existing_override).first).to be_nil
      end
    end

    describe "no override yet" do
      before :once do
        @initial_count = @account.role_overrides.size
      end

      it "should not create an override if override is nil and locked is not truthy" do
        override = RoleOverride.manage_role_override(@account, @role, @permission, :locked => false)
        expect(override).to be_nil
        expect(@account.role_overrides.size).to eq @initial_count
      end

      it "should create the override if override has a value" do
        override = RoleOverride.manage_role_override(@account, @role, @permission, :override => false)
        expect(@account.role_overrides.size).to eq @initial_count + 1
        expect(override.enabled).to be_falsey
      end

      it "should create the override if override is nil but locked is truthy" do
        override = RoleOverride.manage_role_override(@account, @role, @permission, :locked => true)
        expect(@account.role_overrides.size).to eq @initial_count + 1
        expect(override.locked).to be_truthy
      end

      it "should only set the parts that are specified" do
        override = RoleOverride.manage_role_override(@account, @role, @permission, :override => false)
        expect(override.enabled).to be_falsey
        expect(override.locked).to be_nil
        override.destroy

        override = RoleOverride.manage_role_override(@account, @role, @permission, :locked => true)
        expect(override.enabled).to be_nil
        expect(override.locked).to be_truthy
      end
    end
  end

  describe ":if checks" do
    it "should apply to courses" do
      course(:active_all => true)
      @course.expects(:enable_user_notes).once.returns(true)
      expect(@course.grants_right?(@teacher, :manage_user_notes)).to be_truthy
      @course.clear_permissions_cache(@user)
      @course.expects(:enable_user_notes).once.returns(false)
      expect(@course.grants_right?(@teacher, :manage_user_notes)).to be_falsey
    end

    it "should apply to accounts" do
      a = Account.default
      account_admin_user(:active_all => true)
      a.expects(:enable_user_notes).once.returns(true)
      expect(a.grants_right?(@user, :manage_user_notes)).to be_truthy
      a.clear_permissions_cache(@user)
      a.expects(:enable_user_notes).once.returns(false)
      expect(a.grants_right?(@user, :manage_user_notes)).to be_falsey
    end
  end

  describe "#permissions_for" do
    before :once do
      @account = account_model(:parent_account => Account.default)
      @role_name = 'NewRole'
      @permission = :view_group_pages
    end

    def check_permission(base_role, role, enabled)
      hash = RoleOverride.permission_for(@account, @account, @permission, base_role.to_s, role.to_s)
      expect(!!hash[:enabled]).to eq enabled
    end

    def create_role(base_role, role_name)
      @role = @account.roles.build(:name => role_name.to_s)
      @role.base_role_type = base_role.to_s
      @role.workflow_state = 'active'
      @role.save!
    end

    def create_override(role_name, enabled)
      RoleOverride.create!(:context => @account, :permission => @permission.to_s,
                         :enrollment_type => role_name.to_s, :enabled => enabled)
    end

    it "should error with unknown base role" do
      expect{RoleOverride.permission_for(@account, @account, @permission, "DodoBird")}.to raise_error
    end

    it "should give no permissions if basetype is no permissions regardless of role" do
      check_permission(RoleOverride::NO_PERMISSIONS_TYPE, 'TeacherEnrollment', false)
    end

    it "should not mark a permission as explicit in a sub account when it's explicit in the root" do
      @sub_account = @account
      @account = Account.default
      create_role('AccountMembership', 'somerole')
      create_override('somerole', true)
      permission_data = RoleOverride.permission_for(@sub_account, @sub_account, @permission, 'AccountMembership', 'somerole')
      expect(permission_data[:enabled]).to be_truthy
      expect(permission_data[:explicit]).to be_falsey
      expect(permission_data[:prior_default]).to be_truthy

      permission_data = RoleOverride.permission_for(@account, @account, @permission, 'AccountMembership', 'somerole')
      expect(permission_data[:enabled]).to be_truthy
      expect(permission_data[:explicit]).to be_truthy
      expect(permission_data[:prior_default]).to be_falsey
    end

    context 'using :account_allows' do
      it "should be enabled for account if not specified" do
        permission_data = RoleOverride.permission_for(@account, @account, :undelete_courses,
                                                      'AccountMembership', 'AccountAdmin')
        expect(permission_data[:account_allows]).to be_truthy
        expect(permission_data[:enabled]).to be_truthy
        expect(permission_data[:explicit]).to be_falsey
      end

      it "should be enabled for account if not specified" do
        permission_data = RoleOverride.permission_for(@account, @account, :view_grade_changes,
                                                      'AccountMembership', 'AccountAdmin')
        expect(permission_data[:account_allows]).to be_truthy
        expect(permission_data[:enabled]).to be_truthy
        expect(permission_data[:explicit]).to be_falsey
      end

      it "should be enabled for account if specified" do
        root_account = @account.root_account
        root_account.settings[:admins_can_view_notifications] = true
        root_account.save!
        permission_data = RoleOverride.permission_for(@account, @account, :view_notifications,
                                                      'AccountMembership', 'AccountAdmin')
        expect(permission_data[:account_allows]).to be_truthy
        expect(permission_data[:enabled]).to be_falsey
        expect(permission_data[:explicit]).to be_falsey
      end

      it "should be disabled for account if lambda evaluates to false" do
        root_account = @account.root_account
        root_account.settings[:admins_can_view_notifications] = false
        root_account.save!
        permission_data = RoleOverride.permission_for(@account, @account, :view_notifications,
                                                      'AccountMembership', 'AccountAdmin')
        expect(permission_data[:account_allows]).to be_falsey
        expect(permission_data[:enabled]).to be_falsey
        expect(permission_data[:explicit]).to be_falsey
      end
    end

    context "admin roles" do
      it "should special case AccountAdmin role to use AccountAdmin as base role" do
        # the default base role type has no permissions, so this tests it is getting
        # them from the AccountAdmin type.
        check_permission(AccountUser::BASE_ROLE_NAME, 'AccountAdmin', true)
      end

      it "should reject AccountAdmin role with wrong base role" do
        expect{RoleOverride.permission_for(@account, @account, @permission, "DodoBird", "AccountAdmin")}.to raise_error
      end

      it "should use role override for role" do
        create_role(AccountUser::BASE_ROLE_NAME, @role_name)
        create_override(@role_name, true)

        check_permission(AccountUser::BASE_ROLE_NAME, @role_name, true)
      end

      it "should fall back to base role permissions" do
        create_role(AccountUser::BASE_ROLE_NAME, @role_name)

        check_permission(AccountUser::BASE_ROLE_NAME, @role_name, false)
      end

      it "should default :view_notifications to false" do
        create_role(AccountUser::BASE_ROLE_NAME, @role_name)
        permission_data = RoleOverride.permission_for(@account, @account, @permission, 'AccountMembership', @role_name)
        expect(permission_data[:enabled]).to be_falsey
        expect(permission_data[:explicit]).to be_falsey
      end
    end

    context "course roles" do
      RoleOverride.enrollment_types.each do |base_role|
        context "#{base_role[:name]} enrollments" do
          before do
            @base_role = base_role[:name]
            @default_perm = RoleOverride.permissions[@permission][:true_for].include?(@base_role)
          end

          it "should use default permissions" do
            create_role(@base_role, @role_name)
            check_permission(@base_role, @role_name, @default_perm)
          end

          it "should use permission for role" do
            create_role(@base_role, @role_name)
            create_override(@role_name, !@default_perm)

            check_permission(@base_role, @role_name, !@default_perm)
          end

          it "should not find override for base type of role" do
            create_role(@base_role, @role_name)
            create_override(@role_name, @default_perm)
            create_override(@base_role, !@default_perm)

            check_permission(@base_role, @role_name, @default_perm)
            check_permission(@base_role, @base_role, !@default_perm)
          end

          it "should use permission for role in parent account" do
            @parent_account = @account
            @sub = account_model(:parent_account => @account)
            @course = @sub.courses.create!
            @account = @parent_account

            # create in parent
            create_role(@base_role, @role_name)
            # create in sub account
            @role = @sub.roles.build(:name => @role_name.to_s)
            @role.base_role_type = @base_role.to_s
            @role.workflow_state = 'active'
            @role.save!

            #create permission in parent
            create_override(@role_name, !@default_perm)

            # check based on sub account
            hash = RoleOverride.permission_for(@course, @sub, @permission, @base_role.to_s, @role_name.to_s)
            expect(!!hash[:enabled]).to eq !@default_perm
          end

          it "should use permission for role in parent account even if sub account doesn't have role" do
            @parent_account = @account
            @sub = account_model(:parent_account => @account)
            @course = @sub.courses.create!
            @account = @parent_account

            create_role(@base_role, @role_name)

            #create permission in parent
            create_override(@role_name, !@default_perm)

            # check based on sub account
            hash = RoleOverride.permission_for(@course, @sub, @permission, @base_role.to_s, @role_name.to_s)
            expect(!!hash[:enabled]).to eq !@default_perm
          end

          it "should use permission for role in sub account" do
            @parent_account = @account
            @sub = account_model(:parent_account => @account)
            @course = @sub.courses.create!

            create_role(@base_role, @role_name)

            #create permission in child
            create_override(@role_name, !@default_perm)

            # check based on sub account
            hash = RoleOverride.permission_for(@course, @sub, @permission, @base_role.to_s, @role_name.to_s)
            expect(!!hash[:enabled]).to eq !@default_perm
          end
        end
      end
    end

    context "account_only" do
      before :once do
        @site_admin = User.create!
        Account.site_admin.account_users.create!(user: @site_admin)
        @root_admin = User.create!
        Account.default.account_users.create!(user: @root_admin)
        @sub_admin = User.create!
        @sub_account = Account.default.sub_accounts.create!
        @sub_account.account_users.create!(user: @sub_admin)
      end

      it "should not grant site admin permissions to normal account admins" do
        expect(Account.default.grants_right?(@root_admin, :manage_site_settings)).to be_falsey
        # check against the normal root account, but granted rights from Site Admin
        expect(Account.default.grants_right?(@site_admin, :manage_site_settings)).to be_truthy
        # check against Site Admin
        expect(Account.site_admin.grants_right?(@site_admin, :manage_site_settings)).to be_truthy
      end

      it "should not grant root only permissions to sub account admins" do
        expect(Account.default.grants_right?(@root_admin, :become_user)).to be_truthy
        expect(@sub_account.grants_right?(@sub_admin, :become_user)).to be_falsey
        # check against the sub account, but granted rights from the root account
        expect(@sub_account.grants_right?(@root_admin, :become_user)).to be_truthy
      end

      it "should grant root only permissions in courses when the user is a root account admin" do
        @course = @account.courses.create!
        expect(@course.grants_right?(@root_admin, :become_user)).to be_truthy
      end

      it "should not grant account only permissions to malicious course users" do
        @account = @account.courses.create!
        @permission = :become_user
        check_permission(AccountUser::BASE_ROLE_NAME, 'AccountAdmin', false)
      end

      it "should not allow a sub-account to revoke a permission granted to a parent account" do
        @sub_account.role_overrides.create!(enrollment_type: 'AccountAdmin', enabled: false, permission: :manage_admin_users)
        expect(@sub_account.grants_right?(@site_admin, :manage_admin_users)).to be_truthy
        expect(@sub_account.grants_right?(@root_admin, :manage_admin_users)).to be_truthy
        expect(@sub_account.grants_right?(@sub_admin, :manage_admin_users)).to be_falsey
      end
    end

    context "sharding" do
      specs_require_sharding

      it "should find role overrides on a non-current shard" do
        @shard1.activate do
          @account = Account.create!
          @account.role_overrides.create!(:permission => 'become_user', :enabled => false,
                                          :enrollment_type => 'AccountAdmin')
        end
        expect(RoleOverride.permission_for(@account, @account, :become_user, AccountUser::BASE_ROLE_NAME, 'AccountAdmin')[:enabled]).to eq nil
      end
    end
  end

  describe "enabled_for?" do
    it "should honor applies_to_self" do
      ro = RoleOverride.new(:context => Account.site_admin, :permission => 'manage_role_overrides',
                            :enrollment_type => 'role', :enabled => true)
      ro.applies_to_self = false
      ro.save!
      # for the UI - should be enabled
      expect(RoleOverride.permission_for(Account.site_admin, Account.site_admin, :manage_role_overrides, 'AccountMembership', 'role')[:enabled]).to eq [:descendants]
      # applying to Site Admin, should be disabled
      expect(RoleOverride.enabled_for?(Account.site_admin, Account.site_admin, :manage_role_overrides, 'AccountMembership', 'role')).to eq [:descendants]
      # applying to Default Account, should be enabled
      expect(RoleOverride.enabled_for?(Account.site_admin, Account.default, :manage_role_overrides, 'AccountMembership', 'role')).to eq [:self, :descendants]
    end

    it "should honor applies_to_descendants" do
      ro = RoleOverride.new(:context => Account.site_admin, :permission => 'manage_role_overrides',
                            :enrollment_type => 'role', :enabled => true)
      ro.applies_to_descendants = false
      ro.save!
      # for the UI - should be enabled
      expect(RoleOverride.permission_for(Account.site_admin, Account.site_admin, :manage_role_overrides, 'AccountMembership', 'role')[:enabled]).to eq [:self]
      # applying to Site Admin, should be enabled
      expect(RoleOverride.enabled_for?(Account.site_admin, Account.site_admin, :manage_role_overrides, 'AccountMembership', 'role')).to eq [:self]
      # applying to Default Account, should be disabled
      expect(RoleOverride.enabled_for?(Account.site_admin, Account.default, :manage_role_overrides, 'AccountMembership', 'role')).to eq []
    end
  end

  context "enabled_for_plugin" do
    before(:once) do
      account_model
    end

    it "should not show a permission if the specified plugin does not exist" do
      expect(RoleOverride.manageable_permissions(@account).keys).not_to include(:manage_frozen_assignments)
    end

    it "should not show a permission if the specified plugin is not enabled" do
      p = Canvas::Plugin.register(:assignment_freezer, :assignment_freezer, {
        :settings => {:foo => true}})
      s = PluginSetting.new(:name => p.id, :settings => p.default_settings)
      s.disabled = true
      s.save!
      expect(RoleOverride.manageable_permissions(@account).keys).not_to include(:manage_frozen_assignments)
    end

    it "should include show a permission if the specified plugin is enabled" do
      p = Canvas::Plugin.register(:assignment_freezer, :assignment_freezer, {
        :settings => {:foo => true}})
      s = PluginSetting.new(:name => p.id, :settings => p.default_settings)
      s.disabled = false
      s.save!
      expect(RoleOverride.manageable_permissions(@account).keys).to include(:manage_frozen_assignments)
    end
  end
end
