#  profile_window.rb
#
#  Copyright 2015 Jan Brouwer <jan@brewsky.nl>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#
#

module OpenSourceBIM
  module BIMserver

    require File.join( PLUGIN_PATH, 'profile.rb' )
    require File.join( PLUGIN_PATH, 'menu_section.rb' )

    class ProfileWindow
      attr_reader :window, :ready
      def initialize()

        options = {
          :title           => 'Profiles',
          :preferences_key => 'BIMserverProfiles',
          :width           => 267,
          :height          => 500,
          :resizable       => false,
          :theme           => File.join( PLUGIN_PATH_CSS, 'theme.css' ).freeze
        }
        @window = SKUI::Window.new(options)
        @project_list = Hash.new

        @base_profile = MenuSection.new( 'Select profile', self, true)
        @group = MenuSection.new('Edit profile', self, false)
        @group_status = MenuSection.new( 'Status', self, true)

        # Control: status line
        @status = SKUI::Textbox.new( "" )
        @status.readonly = true
        @status.multiline = true

        @status_value = ""
        @ready = false

        # add status line at the bottom
        @group_status.add_control( @status )

        # check if window is ready
        @window.on( :ready ) {
          @ready = true
          get_projects()
        }

        # Add controls
        @serverlist = SKUI::Listbox.new( BIMserver.profiles.names )
        @name = SKUI::Textbox.new()
        @address = SKUI::Textbox.new()
        @port = SKUI::Textbox.new()
        @username = SKUI::Textbox.new()
        @password = SKUI::Textbox.new()

        set_profile_edit( BIMserver.profiles.active_profile )

        # Control: server
        @serverlist.on( :change ) { |control, value| # (?) Second argument needed?
          BIMserver.profiles.set_active_profile( value ) # (?) should this change the active profile?
          set_profile_edit( BIMserver.profiles.active_profile )
          get_projects()
        }
        add_control(@serverlist, @base_profile, 'profile')
        # Control: profile name
        add_control( @name, @group, 'profile name' )

        # Control: address
        add_control( @address, @group, 'address' )

        # Control: port
        add_control( @port, @group, 'port')

        # Control: username
        add_control( @username, @group, 'username')

        # Control: password
        @password.password = true
        add_control( @password, @group, 'password' )

        # Control: projects listbox
        @project = SKUI::Listbox.new( [@profile_edit.project] )
        add_control(@project, @group, 'project')

        @address.on( :change ) { |control, value|
          @profile_edit.address = @address.value
          get_projects()
        }
        @port.on( :change ) { |control, value|
          @profile_edit.port = @port.value
          get_projects()
        }
        @username.on( :change ) { |control, value|
          @profile_edit.username = @username.value
          get_projects()
        }
        @password.on( :change ) { |control, value|
          @profile_edit.password = @password.value
          get_projects()
        }

        # Control: delete button
        delete = SKUI::Button.new( 'Delete' ) { |control|
          unless BIMserver.profiles.profiles.length <= 1
            profile = BIMserver.profiles.active_profile
            name = profile.name
            @serverlist.remove_item( profile.name )
            BIMserver.profiles.delete_profile( profile )
            BIMserver.profiles.set_active_profile( ) # (?) should this change the active profile?

            set_profile_edit( BIMserver.profiles.active_profile )
            set_status( 'Profile "' + name + '" deleted' )
          else
            set_status( 'Error: Profile not deleted! There must be at least one profile.' )
          end
        }
        delete.tooltip = 'Delete selected profile'
        add_control( delete, @group )

        # Control: save button
        save = SKUI::Button.new( 'Save' ) { |control|
          edit_profile = BIMserver.profiles.get_profile_by_name( @serverlist.value )
          edit_profile.name = @name.value
          edit_profile.address = @address.value
          edit_profile.port = @port.value
          edit_profile.username = @username.value
          edit_profile.password = @password.value
          edit_profile.project = @project.value

          edit_profile.project_oid = @project_list.key( @project.value )

          BIMserver.profiles.set_active_profile( edit_profile.name )
          reset_server_list
          set_profile_edit( BIMserver.profiles.active_profile )
          @serverlist.value = @profile_edit.name
          BIMserver.profiles.write_config
          set_status( 'Profile "' + edit_profile.name + '" saved' )
        }
        save.tooltip = 'Save current profile'
        add_control( save, @group )

        # Control: save as new profile
        new = SKUI::Button.new( 'New' ) { |control|

          # create new profile unless profile name exists
          unless @serverlist.items.include? @name.value
            profile = Profile.new(@name.value,@address.value,@port.value,@username.value,@password.value,@project.value,@project_list.key( @project.value ))
            BIMserver.profiles.add_profile( profile )
            BIMserver.profiles.set_active_profile( profile.name )
            reset_server_list
            set_profile_edit( BIMserver.profiles.active_profile )
            @serverlist.value =  @name.value
            BIMserver.profiles.write_config
            set_status( 'Profile "' + profile.name + '" created' )
          else
            set_status( 'Error: No profile created! A profile with the name "' + @name.value + '" already exists. Please choose a different name.' )
          end
        }
        new.tooltip = 'Save as new profile'
        add_control( new, @group )

        # check if window is ready
        @window.on( :ready ) {
          set_size
        }

      end

      def set_size
        @base_profile.set_size
        @group.set_size
      end

      def add_control( control, group, name=nil )
        if control.is_a? SKUI::Textbox or control.is_a? SKUI::Listbox
          label = SKUI::Label.new( name.capitalize + ':', control )
          group.add_control( label )
        end
        group.add_control( control )
      end

      def reset_server_list
        @serverlist.clear()
        BIMserver.profiles.names.each do | name |
          @serverlist.add_item( name )
        end
      end

      def get_projects()
        profile = @profile_edit
        @project.clear() # empty project list control

        # create connection object that connects to the server
        begin
          @conn = OpenSourceBIM::BIMserverAPI::Connection.new( profile.address, profile.port )
          begin
            @conn.login( profile.username, profile.password )
            uoid = @conn.auth_interface.getLoggedInUser["oid"]

            @project_list = Hash.new
            @conn.service_interface.getUsersProjects(uoid).each do | project_hash |
              @project_list[project_hash["oid"]] = project_hash["name"] # create hash containing all id's and names
              @project.add_item( project_hash["name"] ) # add name to project list
            end
            @project.value = @project.items.first

          rescue Exception => err
            set_status("Error connecting to BIMserver: #{err}")
          end
        rescue Exception => err
          set_status("Error: #{err}")
        end
        if @project.items.length < 1
          @project.add_item( @profile_edit.project ) # add stored name to project list
        end
      end

      def toggle
        @serverlist.value = BIMserver.profiles.active_profile.name
        @window.toggle
      end

      def set_status( message )
        BIMserver.set_status( message )
      end

      def update_status()
        if @ready == true
          @status.value = BIMserver.status
        end
      end

      def set_profile_edit( profile )

        # create temporary copy of profile for editing
        @profile_edit = BIMserver.profiles.active_profile.dup
        #@serverlist.value = BIMserver.profiles.active_profile.name

        @name.value = @profile_edit.name
        @address.value = @profile_edit.address
        @port.value = @profile_edit.port
        @username.value = @profile_edit.username
        @password.value = @profile_edit.password
        #@project.value = serverlist.items.first
        #if @project.items.include?(profile.project)
        #  @project.value = profile.project
        #else
        #  @project.clear()
        #  @project.add_item( profile.project )
        #  @project.value = @project.items.first
        #end
      end
    end # class ProfileWindow
  end # module BIMserver
end # module OpenSourceBIM
