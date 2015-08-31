#  loader.rb
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

# Main loader for BIMserver plugin

require 'sketchup'

module OpenSourceBIM
  module BIMserver
    attr_reader :profiles, :btn_upload
    extend self

    PLUGIN_PATH_IMAGE = File.join(PLUGIN_PATH, 'images')
    PLUGIN_PATH_CSS   = File.join(PLUGIN_PATH, 'css')

    # load SKUI webdialog helper library
    load File.join( AUTHOR_PATH, 'lib', 'SKUI', 'embed_skui.rb' )
    ::SKUI.embed_in( self )

    require File.join( PLUGIN_PATH, 'lib', 'BIMserverRubyAPI', 'core.rb' )
    require File.join( PLUGIN_PATH, 'profile.rb' )
    require File.join( PLUGIN_PATH, 'profiles.rb' )
    require File.join( PLUGIN_PATH, 'upload_window.rb' )
    require File.join( PLUGIN_PATH, 'project_window.rb' )
    require File.join( PLUGIN_PATH, 'profile_window.rb' )

    @profiles = Profiles.new()
    @profile_window = ProfileWindow.new()

    # add BIMserver tool to toolbar
    # Load common ui elements
    require File.join(AUTHOR_PATH, 'lib', 'ui.rb')

    # Upload button
    @btn_upload = UI::Command.new('upload model') {

      # close old upload window and create new
      if @upload_window
        @upload_window.window.close
      end
      @upload_window = UploadWindow.new()
      # first upload
      # than status window with results
    }
    @btn_upload.small_icon = File.join(PLUGIN_PATH_IMAGE, 'upload_small.png')
    @btn_upload.large_icon = File.join(PLUGIN_PATH_IMAGE, 'upload_large.png')
    @btn_upload.tooltip = "Upload model to BIMserver"
    @btn_upload.status_bar_text = "Upload current model to selected BIMserver"
    @btn_upload.set_validation_proc {
      MF_GRAYED
    }
    OpenSourceBIM::OsBimUI.add_item( @btn_upload )

    # Show project on server
    @btn_project = UI::Command.new('show project') {

      # close old project window and create new
      if @project_window
        @project_window.window.close
      end
      @project_window = ProjectWindow.new()
    }
    @btn_project.small_icon = File.join(PLUGIN_PATH_IMAGE, 'bimserver_small.png')
    @btn_project.large_icon = File.join(PLUGIN_PATH_IMAGE, 'bimserver_large.png')
    @btn_project.tooltip = "Show project info"
    @btn_project.status_bar_text = "Show project and extended data on BIMserver"
    @btn_project.set_validation_proc {
      MF_GRAYED
    }
    OpenSourceBIM::OsBimUI.add_item( @btn_project )

    # Edit profile
    cmd = UI::Command.new("BIMserver") {
      @profile_window.toggle
    }
    cmd.small_icon = File.join(PLUGIN_PATH_IMAGE, 'profiles_small.png')
    cmd.large_icon = File.join(PLUGIN_PATH_IMAGE, 'profiles_large.png')
    cmd.tooltip = "Manage profiles"
    cmd.status_bar_text = "Select and edit BIMserver profiles"
    OpenSourceBIM::OsBimUI.add_item( cmd )

    # change toolbar button status
    def activate_tools()
      @btn_upload.set_validation_proc {
      #    @btn_upload.status_bar_text = "3r53fegesge"
          MF_ENABLED
      }
      @btn_project.set_validation_proc {
          MF_ENABLED
      }
    end

    def conn()
      if $conn
        if $conn.profile == BIMserver.profiles.active_profile
          return $conn
        end
      else
        $conn = Connection.new()
      end
    end

    class Connection
      attr_reader :profile
      def initialize( profile )
        @profile = profile
        # create connection object that connects to the server
        begin

          @conn = OpenSourceBIM::BIMserverAPI::Connection.new( profile.address, profile.port )
          set_status('Connected to BIMserver at ' + profile.address)

          # login on the server
          begin
            @conn.login( profile.username, profile.password )
            #puts ('Connected to BIMserver at ' + address.value)
            #puts ('Logged in as ' + profile.username)
            set_status('Logged in as ' + profile.username)

            # Get user id
            uoid = @conn.auth_interface.getLoggedInUser["oid"]
          rescue Exception => err
            set_status("Error connecting to BIMserver: #{err}")
          end
        rescue Exception => err
          set_status("Error: #{err}")
        end
      end
    end

    #    class Connection < OpenSourceBIM::BIMserverAPI::Connection
    #      attr_reader :status
    #      def initialize( profile )

    #        # create connection object that connects to the server
    #        begin
    #          @conn = OpenSourceBIM::BIMserverAPI::Connection.new( profile.address, profile.port )
    #        rescue Exception => err
    #          @status = "Error: #{err}"
    #        end

    #        # login on the server
    #        begin
    #          @conn.login( profile.username, profile.password )
    #          #puts ('Connected to BIMserver at ' + address.value)
    #          @status = ('Logged in as ' + profile.username)
    #        rescue Exception => err
    #          @status = "Error connecting to BIMserver: #{err}"
    #        end
    #      end
    #    end # Class Connection

    # dialog window for BIMserver connection
    class BIMserverWindow
      attr_reader :window, :profiles
      def initialize()

        # load default config values
        #require File.join(PLUGIN_PATH, 'config.rb')
        #server_config = BIMserver_config.new("BIMserver.cfg")

        # BIMserver parameters
        #server = server_config.get("address")
        #port = server_config.get("port")
        #user = server_config.get("username")
        #password = server_config.get("password")
        #project = server_config.get("project")

        # create menu window
        options = {
          :title           => 'BIMserver connector',
          :preferences_key => 'BIMserver',
          :width           => 267,
          :height          => 600,
          :resizable       => false,
          :theme           => File.join( PLUGIN_PATH_CSS, 'theme.css' ).freeze
        }
        @window = SKUI::Window.new(options)
        @profiles = Profiles.new()

        # empty projectlist hash
        @list = Hash.new

        # Menu section: connection/profile
        @sec_connection = ConnectionSection.new('Connection', self)

        @sec_revisions = RevisionSection.new('Revisions', self)
        @sec_revisions.minimize

        # Menu section: server
        @sec_server = ServerSection.new('Manage servers',  self)
        @sec_server.minimize

        @sec_projects = ProjectSection.new('Manage projects', self)
        @sec_projects.minimize
        #@sec_projects = SKUI::Groupbox.new( 'Project' )
        #@window.add_control( @sec_projects )

        #@sec_revisions = SKUI::Groupbox.new( 'Revision' )
        #@window.add_control( @sec_revisions )

        @window.show

      end # def initialize


    end # class BIMserverWindow
  end # module BIMserver
end # module OpenSourceBIM
