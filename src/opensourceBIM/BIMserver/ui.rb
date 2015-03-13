#  ui.rb
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

# UI elements for BIMserver

require 'sketchup'

module OpenSourceBIM
  module BIMserver
    
    # load SKUI webdialog helper library
    skui_path = File.join( AUTHOR_PATH, 'lib', 'SKUI' )
    load File.join( skui_path, 'embed_skui.rb' )
    ::SKUI.embed_in( self )
    
    class BIMserverWindow
      
      require File.join(PLUGIN_PATH, 'bimserver_api')
      
      def initialize()
      
        # load default config values
        require File.join(PLUGIN_PATH, 'config.rb')
        server_config = BIMserver_config.new("BIMserver.cfg")
        
        # BIMserver parameters
        server = server_config.get("address")
        port = server_config.get("port")
        user = server_config.get("username")
        password = server_config.get("password")
        project = server_config.get("project")
        
        options = {
          :title           => 'BIMserver connector',
          :preferences_key => 'BIMserver',
          :width           => 243,
          :height          => 400,
          :resizable       => true
        }
        
        @window = SKUI::Window.new(options)
        
        #@window.on( :blur )   { puts 'Window Blur' }

        # add groupbox for server settings
        group_server = SKUI::Groupbox.new( 'Server connection' )
        group_server.position( 5, 5 )
        group_server.right = 5
        group_server.height = 176
        #group_server.foreground_color = Sketchup::Color.new( 192, 0, 0 )
        @window.add_control( group_server )
        
        # add server address input box
        txt_address = SKUI::Textbox.new( server )
        txt_address.name = :txt_name
        txt_address.position( 70, 20 )
        txt_address.right = 10 # (!) Currently ignored by browser.
        group_server.add_control( txt_address )
        
        lbl_address = SKUI::Label.new( 'Address:', txt_address )
        lbl_address.position( 10, 23 )
        lbl_address.width = 60
        group_server.add_control( lbl_address )
        
        # add server port number input box
        txt_port = SKUI::Textbox.new( port )
        txt_port.name = :txt_name
        txt_port.position( 70, 45 )
        txt_port.right = 10 # (!) Currently ignored by browser.
        group_server.add_control( txt_port )
        
        lbl_port = SKUI::Label.new( 'Port:', txt_port )
        lbl_port.position( 10, 48 )
        lbl_port.width = 60
        group_server.add_control( lbl_port )
        
        # add username input box
        txt_user = SKUI::Textbox.new( user )
        txt_user.name = :txt_name
        txt_user.position( 70, 70 )
        txt_user.right = 10 # (!) Currently ignored by browser.
        group_server.add_control( txt_user )
        
        lbl_user = SKUI::Label.new( 'Username:', txt_user )
        lbl_user.position( 10, 73 )
        lbl_user.width = 60
        group_server.add_control( lbl_user )
        
        # add password input box
        txt_password = SKUI::Textbox.new( password )
        txt_password.name = :txt_name
        txt_password.position( 70, 95 )
        txt_password.right = 10 # (!) Currently ignored by browser.
        group_server.add_control( txt_password )
        
        lbl_password = SKUI::Label.new( 'Password:', txt_password )
        lbl_password.position( 10, 98 )
        lbl_password.width = 60
        group_server.add_control( lbl_password )
          
        lbl_conn = SKUI::Label.new( 'Not connected' ) # Should this be a label, or just a text?
        lbl_conn.visible = false
        lbl_conn.position( 160, 125 )
        lbl_conn.right = 10
        group_server.add_control( lbl_conn )
        
        # create placeholder for checkin_section
        checkin_section = nil
        
        # add login button
        btn_conn = SKUI::Button.new( 'Connect' ) { |control|
          name = control.window[:txt_name].value
          
          # make connection with BIMserver
          begin
            conn = BIMserver_connection.new(txt_address.value, txt_port.value, txt_user.value, txt_password.value)
            lbl_conn.caption = 'Connected to BIMserver'
            lbl_conn.visible = true
            
            # Create checkin section
            checkin_section = show_checkin(conn)
          rescue => err
            puts "Error connecting to BIMserver: #{err}"
            lbl_conn.caption = "Error connecting to BIMserver: #{err}"
            lbl_conn.visible = true
            
            # Delete checkin section if it exists
            unless checkin_section.nil?
              @window.remove_control(checkin_section)
              # The other controls are not deleted, but overwritten along the way on a succesful login
              
              # instead of removing, it could also be hidden and later overwritten, don't know which is best here...
              #checkin_section.visible = false
            end

          end
          
        }
        btn_conn.position( 70, 122 )
        btn_conn.tooltip = 'Connect to BIMserver'
        group_server.add_control( btn_conn )
        
        @window.show

        #txt_address.on( :blur )   {
        #  puts "blur address"
        #}
        
      end # def initialize
      
      # get the list of projects from the BIMserver and show these in a select box
      def show_checkin(connection)
      
        require File.join(PLUGIN_PATH, 'ifc_handler')
        
        # Get list of projects
        list = Array.new
        connection.getProjects.each do |project|
          list << project["name"]
        end

        # add groupbox for model checkin
        group_checkin = SKUI::Groupbox.new( 'Model checkin' )
        group_checkin.position( 5, 168 )
        group_checkin.right = 5
        group_checkin.height = 164
        @window.add_control( group_checkin )

        # Create listbox containing projects
        lst_dropdown = SKUI::Listbox.new( list )
        lst_dropdown.value = lst_dropdown.items.first
        lst_dropdown.position( 70, 18 )
        lst_dropdown.right = 10
        #lst_dropdown.on( :change ) { |control, value| # (?) Second argument needed?
        #  puts "Dropbox value: #{control.value}"
        #}
        group_checkin.add_control( lst_dropdown )
        
        lbl_projects = SKUI::Label.new( 'Project:', lst_dropdown )
        lbl_projects.position( 10, 21 )
        lbl_projects.width = 60
        group_checkin.add_control( lbl_projects )
          
        lbl_checkin = SKUI::Label.new( 'Not uploaded' ) # Should this be a label, or just a text?
        lbl_checkin.visible = false
        lbl_checkin.position( 160, 53 )
        lbl_checkin.right = 10
        group_checkin.add_control( lbl_checkin )
        
        # add model checkin button
        btn_checkin = SKUI::Button.new( 'Upload' ) { |control|
        
          # add model checkin button that uploads the model
          begin
            project_name = lst_dropdown.value
            project_oid = connection.get_projectOid(project_name)
            ifc = BIMserver.IfcWrite
            if connection.checkin(ifc, project_oid)
              lbl_checkin.caption = "Model upload succesful."
              lbl_checkin.visible = true
            end
          rescue => err
            lbl_checkin.caption = "Error uploading to BIMserver: #{err}"
            lbl_checkin.visible = true
          end
        }
        btn_checkin.position( 70, 50 )
        btn_checkin.tooltip = 'Check in current model'
        group_checkin.add_control( btn_checkin )
        return group_checkin
        
      end # def show_checkin      
    end # class BIMserverWindow
  end # BIMserver
end # module OpenSourceBIM
