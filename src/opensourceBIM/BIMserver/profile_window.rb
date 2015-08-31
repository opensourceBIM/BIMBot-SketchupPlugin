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

        # empty projectlist hash
        @projectlist = Hash.new

        options = {
          :title           => 'Profiles',
          :preferences_key => 'BIMserverProfiles',
          :width           => 267,
          :height          => 500,
          :resizable       => false,
          :theme           => File.join( PLUGIN_PATH_CSS, 'theme.css' ).freeze
        }
        @window = SKUI::Window.new(options)

        @base_profile = MenuSection.new( 'Select profile', self)
        @group = MenuSection.new('Edit server', self, false)
        @load_projects = MenuSection.new('Select project', self, false)
        @save_section = MenuSection.new('Edit profile', self, false)

        # check if window is ready
        @window.on( :ready ) {
          @ready = true
        }

        profile = BIMserver.profiles.active_profile

        # Control: server
        @serverlist = SKUI::Listbox.new( BIMserver.profiles.names )
        #@serverlist.value = serverlist.items.first
        @serverlist.on( :change ) { |control, value| # (?) Second argument needed?
          BIMserver.profiles.set_active_profile( value ) # (?) should this change the active profile?
          set_active_profile()
          BIMserver.btn_upload.tooltip = value
        }
        add_control(@serverlist, @base_profile, 'profile')

        # Control: delete button
        delete = SKUI::Button.new( 'Delete' ) { |control|
          profile = BIMserver.profiles.active_profile
          @serverlist.remove_item( profile.name )
          BIMserver.profiles.delete_profile( profile )
          BIMserver.profiles.set_active_profile() # (?) should this change the active profile?
          set_active_profile()
        }
        delete.tooltip = 'Delete selected profile'
        add_control( delete, @save_section )

        # Control: profile name
        @name = SKUI::Textbox.new( profile.name )
        add_control( @name, @group, 'profile name' )

        # Control: address
        @address = SKUI::Textbox.new( profile.address )
        add_control( @address, @group, 'address' )

        # Control: port
        @port = SKUI::Textbox.new( profile.port )
        add_control( @port, @group, 'port')

        # Control: username
        @username = SKUI::Textbox.new( profile.username )
        add_control( @username, @group, 'username')

        # Control: password
        @password = SKUI::Textbox.new( profile.password )
        @password.password = true
        add_control( @password, @group, 'password' )

        # Control: projects listbox
        @project = SKUI::Listbox.new( [profile.project] )
        #@serverlist.value = serverlist.items.first
        @project.on( :change ) { |control, value| # (?) Second argument needed?
        }

        # Control: load projects button
        get_projects = SKUI::Button.new( 'Get projects' ) { |control|

          profile = BIMserver.profiles.active_profile

          # create connection object that connects to the server
          begin

            @conn = OpenSourceBIM::BIMserverAPI::Connection.new( profile.address, profile.port )

            # login on the server
            begin
              @conn.login( profile.username, profile.password )
              #puts ('Connected to BIMserver at ' + address.value)
              puts ('Logged in as ' + profile.username)

              # Get user id
              uoid = @conn.auth_interface.getLoggedInUser["oid"]

              # get the id of the last revision
              begin
                roid = @conn.bimsie1_service_interface.getProjectByPoid( profile.project_oid )['lastRevisionId']
              rescue Exception => error
                puts error
              end

              # get revision number
              revision = @conn.bimsie1_service_interface.getRevision( roid )['id']

            rescue Exception => err
              puts "Error connecting to BIMserver: #{err}"
            end
          rescue Exception => err
            puts = "Error: #{err}"
          end

        }
        get_projects.tooltip = 'Get project list from server'
        get_projects.width = 150
        add_control( get_projects, @load_projects )
        add_control(@project, @load_projects, 'projects')

        # Control: save button
        save = SKUI::Button.new( 'Save' ) { |control|
          edit_profile = BIMserver.profiles.get_profile_by_name( @serverlist.value )
          edit_profile.name = @name.value
          edit_profile.address = @address.value
          edit_profile.port = @port.value
          edit_profile.username = @username.value
          edit_profile.password = @password.value
          edit_profile.project = @project.value
          edit_profile.project_oid = @projectlist[@project.value]
          BIMserver.profiles.write_config
          # @status.value = 'Profile saved succesfully'
        }
        save.tooltip = 'Save current profile'
        add_control( save, @save_section )

        # Control: save as new profile
        new = SKUI::Button.new( 'New' ) { |control|
          profile = Profile.new(@name.value,@address.value,@port.value,@username.value,@password.value,@project.value, @projectlist[@project.value])
          BIMserver.profiles.add_profile( profile )
          BIMserver.profiles.set_active_profile( profile )
          @serverlist.add_item( profile.name )
          set_active_profile()
          BIMserver.profiles.write_config
          # @status.value = 'Profile created succesfully'
        }
        new.tooltip = 'Save as new profile'
        add_control( new, @save_section )

      end

      def add_control( control, group, name=nil )
        if control.is_a? SKUI::Textbox or control.is_a? SKUI::Listbox
          label = SKUI::Label.new( name.capitalize + ':', control )
          group.add_control( label )
        end
        group.add_control( control )
      end

      def toggle
        @serverlist.value = BIMserver.profiles.active_profile.name
        @window.toggle
      end

      def set_active_profile()
        profile = BIMserver.profiles.active_profile
        @serverlist.value = profile.name
        @name.value = profile.name
        @address.value = profile.address
        @port.value = profile.port
        @username.value = profile.username
        @password.value = profile.password
        #@project.value = serverlist.items.first
        if @project.items.include?(profile.project)
          @project.value = profile.project
        else
          @project.clear()
          @project.add_item( profile.project )
          @project.value = @project.items.first
        end

      end
    end # class ProfileWindow
  end # module BIMserver
end # module OpenSourceBIM
