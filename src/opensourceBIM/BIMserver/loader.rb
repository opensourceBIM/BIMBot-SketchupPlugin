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
          :resizable       => true,
          :theme           => File.join( PLUGIN_PATH_CSS, 'theme.css' ).freeze
        }
        
        @window = SKUI::Window.new(options)
        
        # empty projectlist hash
        @list = Hash.new
        
        # logo
        #img_logo = SKUI::Image.new( File.join(PLUGIN_PATH_IMAGE, 'osbim-logo-64.png') )
        #img_logo.top = 5
        #img_logo.right = 10
        #img_logo.width = 32
        #@window.add_control( img_logo )

        # add groupbox for log
        group_log = SKUI::Groupbox.new( 'Connection log' )
        group_log.position( 5, 21 )
        group_log.right = 5
        group_log.height = 195
        @window.add_control( group_log )
        
        # add log window
        @log = SKUI::Textbox.new(  )
        @log.multiline = true
        @log.readonly = true
        @log.position( 10, 20 )
        @log.height = 153
        @log.right = 10 # (!) Currently ignored by browser.
        @log.background_color = Sketchup::Color.new( 84, 84, 84 )
        group_log.add_control( @log )

        # add groupbox for server settings
        group_server = SKUI::Groupbox.new( 'Server connection' )
        group_server.position( 5, 217 )
        group_server.right = 5
        group_server.height = 167
        @window.add_control( group_server )
        
        # add server address input box
        txt_address = SKUI::Textbox.new( server )
        txt_address.position( 70, 20 )
        txt_address.right = 10
        group_server.add_control( txt_address )
        
        lbl_address = SKUI::Label.new( 'Address:', txt_address )
        lbl_address.position( 10, 23 )
        lbl_address.width = 60
        group_server.add_control( lbl_address )
        
        # add server port number input box
        txt_port = SKUI::Textbox.new( port )
        txt_port.position( 70, 45 )
        txt_port.right = 10
        group_server.add_control( txt_port )
        
        lbl_port = SKUI::Label.new( 'Port:', txt_port )
        lbl_port.position( 10, 48 )
        lbl_port.width = 60
        group_server.add_control( lbl_port )
        
        # add username input box
        txt_user = SKUI::Textbox.new( user )
        txt_user.position( 70, 70 )
        txt_user.right = 10
        group_server.add_control( txt_user )
        
        lbl_user = SKUI::Label.new( 'Username:', txt_user )
        lbl_user.position( 10, 73 )
        lbl_user.width = 60
        group_server.add_control( lbl_user )
        
        # add password input box
        txt_password = SKUI::Textbox.new( password )
        txt_password.password = true
        txt_password.position( 70, 95 )
        txt_password.right = 10
        group_server.add_control( txt_password )
        
        lbl_password = SKUI::Label.new( 'Password:', txt_password )
        lbl_password.position( 10, 98 )
        lbl_password.width = 60
        group_server.add_control( lbl_password )
        
        # create empty checkin_section
        checkin_section = nil
        
        # add login button
        btn_conn = SKUI::Button.new( 'Connect' ) { |control|
          
          # create connection object that connects to the server
          begin
            @conn = OpenSourceBIM::BIMserverAPI::Connection.new( txt_address.value, txt_port.value )
          rescue Exception => err
            log "Error: #{err}"
          end
          
          # login on the server (internally defines a token that is automatically passed to all other methods to verify the user)
          begin
            @conn.login( txt_user.value, txt_password.value )
            log ('Connected to BIMserver at ' + txt_address.value)
            log ('Logged in as ' + txt_user.value)
            
            # Create checkin section
            checkin_section = show_checkin()
          rescue Exception => err
            log "Error connecting to BIMserver: #{err}"
            
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
        btn_conn.width = 150
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
          
          # if project is subproject: change formatting
          if project["parentId"] == -1
            @list[project["name"]] = project["oid"]
          else
            parent = @conn.bimsie1_service_interface.getProjectByPoid( project["parentId"] )
            @list[parent["name"] + ": " + project["name"]] = project["oid"]
          end
        end

        # add groupbox for model checkin
        group_checkin = SKUI::Groupbox.new( 'Model checkin' )
        group_checkin.position( 5, 386 )
        group_checkin.right = 5
        group_checkin.height = 90
        @window.add_control( group_checkin )

        # Create listbox containing projects
        lst_dropdown = SKUI::Listbox.new( @list.keys )
        lst_dropdown.value = lst_dropdown.items.first
        lst_dropdown.position( 70, 20 )
        lst_dropdown.right = 10
        group_checkin.add_control( lst_dropdown )
        
        lbl_projects = SKUI::Label.new( 'Project:', lst_dropdown )
        lbl_projects.position( 10, 23 )
        lbl_projects.width = 60
        group_checkin.add_control( lbl_projects )
        
        # add model checkin button that uploads the model
        btn_checkin = SKUI::Button.new( 'Upload' ) { |control|
        
          project_name = lst_dropdown.value
          project_oid = @list[ project_name ]
          ifc = BIMserver.IfcWrite
          topicId = checkin(ifc, project_oid)
          
          progress = 0
          now = Time.now
          counter = 1
          loop do
            if Time.now < now + counter
              next
            else
              
              # get current processing status
              progress = @conn.bimsie1_notificationRegistry_interface.getProgress( topicId )["progress"]
              
              unless progress == -1 # progress -1 means not ready 
                log ('Processing revision: ' + progress.to_s + '%')
              end
              break if progress >= 100
            end
            counter += 1
            break if counter > 10 # maximum wait is 10 seconds
          end
            
          # get the id of the last revision
          begin
            roid = @conn.bimsie1_service_interface.getProjectByPoid( project_oid )['lastRevisionId']
          rescue Exception => error
            log error
          end
            
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
                @group_ext_data.position( 5, 478 )
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

                  if html.include? "<html" # probably html
                    dlg = UI::WebDialog.new("Extended data", true, "ExtendedData", 739, 641, 150, 150, true);
                    dlg.set_html( html )
                    dlg.show
                  else
                    log("Unable to show extended data, not of the type 'html'." )
                  end
                }
                @group_ext_data.add_control( btn_ext_data )
                btn_ext_data.position( 70, 20 )
                btn_ext_data.width = 150
              end
            end
            
            sleep 0.5
            $i +=1
          end
        }
        btn_checkin.position( 70, 45 )
        btn_checkin.width = 150
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
        begin
          id = @conn.bimsie1_service_interface.checkin( poid, comment, deserializerOid, fileSize, fileName, data, sync)
          log ('Model upload succesful.')
          id
        rescue Exception => err
          log "Error during upload: #{err}"
        end
      end
      
      # get the oid for the requested deserializer name
      def get_deserializerOid(deserializer_name)
        @conn.plugin_interface.getAllDeserializers(true).each do |deserializer|
          if deserializer["name"] == deserializer_name
            return deserializer["oid"]
          end
        end
        
        # if not found, raise error
        raise "No deserializer found with name '" + deserializer_name + "'."
      end # def get_deserializerOid
      
      # get the oid for the requested project name
      def get_project_oid(project_name)
        
        # compare project_name against all projects on the server, return oid when found
        @conn.bimsie1_service_interface.getAllProjects( false, true ).each do |project|
          if project["name"] == project_name
            return project["oid"]
          end
        end
        
        # if not found, raise error
        raise "No project found with name '" + project_name + "'."
      end
      
      # add string to the log window
      def log( response )
        @log.value += Time.now.strftime("%I:%M:%S") + ': ' + response + "\n"
      end # def log
    end # class BIMserverWindow    
  end # module BIMserver
end # module OpenSourceBIM
