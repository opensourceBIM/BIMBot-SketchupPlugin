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
    
    # load BIMserverAPI
    require File.join( PLUGIN_PATH, 'lib', 'BIMserverRubyAPI', 'core.rb' )
    
    PLUGIN_PATH_IMAGE = File.join(PLUGIN_PATH, 'images')
    PLUGIN_PATH_CSS   = File.join(PLUGIN_PATH, 'css')
    
    # Load common ui elements
    load File.join(AUTHOR_PATH, 'lib', 'ui.rb')
    
    # BIMserver toolbar command
    
    cmd = UI::Command.new("BIMserver") {
      window = BIMserverWindow.new()
    }
    cmd.small_icon = File.join(PLUGIN_PATH_IMAGE, 'bimserver_small.png')
    cmd.large_icon = File.join(PLUGIN_PATH_IMAGE, 'bimserver_large.png')
    cmd.tooltip = "Upload to BIMserver"
    cmd.status_bar_text = "Open BIMserver connection window"
    
    # add BIMserver tool to toolbar
    OpenSourceBIM::OsBimUI.add_item( cmd )
    
    # load SKUI webdialog helper library
    load File.join( AUTHOR_PATH, 'lib', 'SKUI', 'embed_skui.rb' )
    ::SKUI.embed_in( self )
    
    # dialog window for BIMserver connection
    class BIMserverWindow
      
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

        # add groupbox for log
        group_log = SKUI::Groupbox.new( 'Connection log' )
        group_log.position( 5, 5 )
        group_log.right = 5
        group_log.height = 200
        @window.add_control( group_log )
        
        # add log window
        @log = SKUI::Textbox.new(  )
        @log.multiline = true
        @log.readonly = true
        @log.name = :txt_name
        @log.position( 10, 20 )
        @log.height = 158
        @log.right = 10 # (!) Currently ignored by browser.
        @log.background_color = Sketchup::Color.new( 84, 84, 84 )
        group_log.add_control( @log )

        # add groupbox for server settings
        group_server = SKUI::Groupbox.new( 'Server connection' )
        group_server.position( 5, 205 )
        group_server.right = 5
        group_server.height = 176
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
        txt_password.password = true
        txt_password.position( 70, 95 )
        txt_password.right = 10 # (!) Currently ignored by browser.
        group_server.add_control( txt_password )
        
        lbl_password = SKUI::Label.new( 'Password:', txt_password )
        lbl_password.position( 10, 98 )
        lbl_password.width = 60
        group_server.add_control( lbl_password )
        
        # create empty checkin_section
        checkin_section = nil
        
        # add login button
        btn_conn = SKUI::Button.new( 'Connect' ) { |control|
          name = control.window[:txt_name].value
          
          # create connection object that connects to the server
          @conn = OpenSourceBIM::BIMserverAPI::Connection.new( txt_address.value, txt_port.value )
          log ('Connected to BIMserver at ' + txt_address.value)
          
          # login on the server (internally defines a token that is automatically passed to all other methods to verify the user)
          if @conn.login( txt_user.value, txt_password.value )
            log ('Logged in as ' + txt_user.value)
            # Create checkin section
            checkin_section = show_checkin()
          else
            log "Error connecting to BIMserver: #{err}"
            #lbl_conn.caption = "Error connecting to BIMserver: #{err}"
            #lbl_conn.visible = true
            
            # Delete checkin section if it exists
            unless checkin_section.nil?
              @window.remove_control(checkin_section)
              # The other controls are not deleted, but overwritten along the way on a succesful login
              
              # instead of removing, it could also be hidden and later overwritten, don't know which is best here...
              #checkin_section.visible = false
            end
          end
          # make connection with BIMserver
          #begin
            #@conn = BIMserver_connection.new(txt_address.value, txt_port.value, txt_user.value, txt_password.value)
            #log ('Connected to BIMserver at ' + txt_address.value)
            ##lbl_conn.caption = 'Connected to BIMserver'
            ##lbl_conn.visible = true
            
            ## Create checkin section
            #checkin_section = show_checkin(@conn)
          #rescue => err
            #log "Error connecting to BIMserver: #{err}"
            ##lbl_conn.caption = "Error connecting to BIMserver: #{err}"
            ##lbl_conn.visible = true
            
            ## Delete checkin section if it exists
            #unless checkin_section.nil?
              #@window.remove_control(checkin_section)
              ## The other controls are not deleted, but overwritten along the way on a succesful login
              
              ## instead of removing, it could also be hidden and later overwritten, don't know which is best here...
              ##checkin_section.visible = false
            #end
          #end
        }
        btn_conn.position( 70, 122 )
        btn_conn.tooltip = 'Connect to BIMserver'
        group_server.add_control( btn_conn )
        
        @window.show
        
      end # def initialize
      
      # get the list of projects from the BIMserver and show these in a select box
      def show_checkin()
      
        require File.join(PLUGIN_PATH, 'ifc_handler')
        
        # Get user id
        uoid = @conn.auth_interface.getLoggedInUser["oid"]
        
        # Get list of projects
        list = Array.new
        @conn.service_interface.getUsersProjects( uoid ).each do |project|
          list << project["name"]
        end

        # add groupbox for model checkin
        group_checkin = SKUI::Groupbox.new( 'Model checkin' )
        group_checkin.position( 5, 368 )
        group_checkin.right = 5
        group_checkin.height = 104
        @window.add_control( group_checkin )

        # Create listbox containing projects
        lst_dropdown = SKUI::Listbox.new( list )
        lst_dropdown.value = lst_dropdown.items.first
        lst_dropdown.position( 70, 18 )
        lst_dropdown.right = 10
        group_checkin.add_control( lst_dropdown )
        
        lbl_projects = SKUI::Label.new( 'Project:', lst_dropdown )
        lbl_projects.position( 10, 21 )
        lbl_projects.width = 60
        group_checkin.add_control( lbl_projects )
        
        # add model checkin button
        btn_checkin = SKUI::Button.new( 'Upload' ) { |control|
        
          # add model checkin button that uploads the model
          #begin
            #??? Is it posible to create projects with duplicate names, is a poid required for selecting a single project ???
            project_name = lst_dropdown.value
            project_oid = get_project_oid(project_name)
            ifc = BIMserver.IfcWrite
            topicId = checkin(ifc, project_oid)
            
            progress = 0
            start_time = Time.now
            
            log ('Model upload succesful.')
            
            until progress == 100
              progress = @conn.bimsie1_notificationRegistry_interface.getProgress( topicId )["progress"]
              
              # raise error if processing takes too long
              raise if Time.now - start_time > 10
              
              # Progress -1%??? 
              unless progress == -1
                log ('Processing revision: ' + progress.to_s + '%')
              end
              
              
            end
              
            # get the id of the last revision
            roid = @conn.bimsie1_service_interface.getProjectByPoid( project_oid )['lastRevisionId']
            #log ('New revision id: ' + roid.to_s)
              
            # get revision number
            revision = @conn.bimsie1_service_interface.getRevision( roid )['id']
            log ('New revision #' + revision.to_s + ' (' + roid.to_s + ') created for project ' + project_name + ' (' + project_oid.to_s + ')')
            
            
            $i = 0
            $num = 4
            
            while $i < $num  do
              
              # show extended data for revision
              @conn.bimsie1_service_interface.getAllExtendedDataOfRevision( roid ).each do | extended_data |
              
                # create container array if it does not exists
                unless @extended_data_list
                  @extended_data_list = Array.new
        
                  # add groupbox for extended data
                  @group_ext_data = SKUI::Groupbox.new( 'Extended data' )
                  @group_ext_data.position( 5, 472 )
                  @group_ext_data.right = 5
                  @group_ext_data.height = 176
                  @window.add_control( @group_ext_data )
                end
                
                # add extended_data to array if it's not already there
                unless @extended_data_list.include?( extended_data['oid'] )
                  log('Extended data found: ' + extended_data['title'])
                  @extended_data_list << extended_data['oid']
                  
                  # add extended data button
                  btn_ext_data = SKUI::Button.new( extended_data['title'] ) { |control|
                  
                  
                    file_id = extended_data['fileId']
                    html = Base64.decode64( @conn.service_interface.getFile( file_id )['data'] )
                    dlg = UI::WebDialog.new("Extended data", true, "ExtendedData", 739, 641, 150, 150, true);
                    dlg.set_html( html )
                    dlg.show
                  
                  }
                  @group_ext_data.add_control( btn_ext_data )
                end
              end
              
              sleep 0.5
              $i +=1
            end
            
            
            
          #rescue => err
          #  log "Error uploading to BIMserver: #{err}"
          #  #lbl_checkin.caption = "Error uploading to BIMserver: #{err}"
          #  #lbl_checkin.visible = true
          #end
        }
        btn_checkin.position( 70, 50 )
        btn_checkin.tooltip = 'Check in current model'
        group_checkin.add_control( btn_checkin )
        return group_checkin
        
      end # def show_checkin
    
      # Description: Checkin a new model by sending a serialized form
      # Returns: An id, which you can use for the getCheckinState method
      def checkin(ifc_file, projectOid)
        
        file = File.new(ifc_file, "r")
        file_contents = file.read
        file_size = file.size
        
        poid = projectOid
        comment = ""
        deserializerOid = get_deserializerOid("Ifc2x3tc1 Step Deserializer")
        fileSize = file.size
        fileName = Sketchup.active_model.title + ".ifc"
        data = Base64.encode64(file_contents)
        sync = "false"
        
        return @conn.bimsie1_service_interface.checkin( poid, comment, deserializerOid, fileSize, fileName, data, sync)
        
        #else
        #  log("Unable to checkin model, not logged in on BIMserver")
        #end
        
      end # def checkin
      
      # get the oid for the requested deserializer name
      def get_deserializerOid(deserializer_name)
        @conn.plugin_interface.getAllDeserializers(true).each do |deserializer|
          if deserializer["name"] == deserializer_name
            return deserializer["oid"]
          end
        end
      end # def get_deserializerOid
            
      # get the oid for the requested project name
      def get_project_oid(project_name)
        @conn.bimsie1_service_interface.getAllProjects( true, true ).each do |project|
          if project["name"] == project_name
            return project["oid"]
          end
        end
      end # def get_projectOid
      
      def log( response )
        @log.value += Time.now.to_s + ': ' + response + "\n"
        puts response
      end # def log
    end # class BIMserverWindow    
  end # module BIMserver
end # module OpenSourceBIM
