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
    extend self
    
    attr_reader :profiles, :conn, :btn_upload, :btn_project, :status
    attr_accessor :buttons_enabled

    PLUGIN_PATH_IMAGE = File.join(PLUGIN_PATH, 'images')
    PLUGIN_PATH_CSS   = File.join(PLUGIN_PATH, 'css')

    # load SKUI webdialog helper library
    load File.join( AUTHOR_PATH, 'lib', 'SKUI', 'embed_skui.rb' )
    ::SKUI.embed_in( self )

    @conn = nil
    @buttons_enabled = false
    
    def BIMserver.set_status( message )
      if message.nil?
        @status == ""
      else
        @status = message
      end
      if @profile_window
        @profile_window.update_status()
      end
      if @project_window
        @project_window.update_status()
      end
    end

    require File.join( PLUGIN_PATH, 'lib', 'BIMserverRubyAPI', 'core.rb' )
    require File.join( PLUGIN_PATH, 'profiles.rb' )
    require File.join( PLUGIN_PATH, 'upload_window.rb' )
    require File.join( PLUGIN_PATH, 'project_window.rb' )
    require File.join( PLUGIN_PATH, 'profile_window.rb' )

    # Load common ui elements
    require File.join(AUTHOR_PATH, 'lib', 'ui.rb')

    @profiles = Profiles.new()
    @profile_window = ProfileWindow.new()

    # add BIMserver tools to toolbar
    # Upload button
    @btn_upload = UI::Command.new('upload model') {

      # close old upload window and create new
      if @upload_window
        if @upload_window.window
          @upload_window.window.close
        end
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
      if @buttons_enabled == true
        MF_ENABLED
      else
        MF_GRAYED
      end
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
      if @buttons_enabled == true
        MF_ENABLED
      else
        MF_GRAYED
      end
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

  end # module BIMserver
end # module OpenSourceBIM
