#  upload_window.rb
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

    require File.join(PLUGIN_PATH, 'ifc_handler')

    class UploadWindow
      def initialize()
        options = {
          :title           => 'BIMserver checkin',
          :preferences_key => 'BIMserverUpload',
          :width           => 267,
          :height          => 200,
          :resizable       => false,
          :theme           => File.join( PLUGIN_PATH_CSS, 'theme.css' ).freeze
        }
        @window = SKUI::Window.new(options)
        @group = SKUI::Groupbox.new( 'Upload model' )
        @group_status = SKUI::Groupbox.new( '' )

        # add minimize button
        image = File.join(PLUGIN_PATH_IMAGE, 'minimize.png')
        @button = SKUI::Button.new( "" ) { |control|
        }
        @button.background_image = image
        @button.width = 22
        @button.height = 24
        @button.css_class( 'icon' )
        @window.add_control( @button )
        @window.add_control( @group )
        @window.add_control( @group_status )

        @profile = SKUI::Textbox.new( 'Active profile: ' + BIMserver.profiles.active_profile.name )
        @profile.readonly = true
        @group.add_control( @profile )

        #image = File.join(PLUGIN_PATH_IMAGE, 'waiting.gif')
        #waiting = SKUI::Image.new( image )
        #waiting.position( 100, 0 )
        #@group.add_control( waiting )

        # Control: status line
        @status = SKUI::Textbox.new( "" )
        @status.readonly = true
        @status.multiline = true

        @status_value = ""
        @ready = false

        # check if window is ready
        @window.on( :ready ) {
          @ready = true
          @status.value = @status_value
        }

        # add status line at the bottom
        @group_status.add_control( @status )

        @window.show

        ## Control: upload button
        #upload = SKUI::Button.new( 'Upload' ) { |control|

        # clear status line
        #@status.value = ""

        profile = BIMserver.profiles.active_profile

        project_oid = profile.project_oid
        project_name = profile.project

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
                  set_status('Processing revision: ' + progress.to_s + '%')
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
              set_status( error )
            end

            # get revision number
            revision = @conn.bimsie1_service_interface.getRevision( roid )['id']
            set_status('New revision #' + revision.to_s + ' (' + roid.to_s + ') created for project ' + project_name + ' (' + project_oid.to_s + ')')

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
                  @status.value = ('Extended data found: ' + extended_data['title'])
                  @extended_data_list << extended_data['oid']

                  file_id = extended_data['fileId']
                  html = Base64.decode64( @conn.service_interface.getFile( file_id )['data'] )

                  if html.include? "<html" # probably html
                    dlg = UI::WebDialog.new("Extended data", true, "ExtendedData", 739, 641, 150, 150, true);
                    dlg.set_html( html )
                    @window.close()
                    dlg.show
                  else
                    set_status("Unable to show extended data, not of the type 'html'." )
                  end

                end
              end

              sleep 0.5
              $i +=1
            end

          rescue Exception => err
            set_status("Error connecting to BIMserver: #{err}")
          end
        rescue Exception => err
          set_status("Error: #{err}")
        end
        #}
        #upload.tooltip = 'Upload current model'
        #add_control( upload, @group )
      end

      def set_status( value=nil )
        @status_value = value unless value.nil?
        if @ready == true
          @status.value = @status_value
        end
      end

      def add_control( control, group, name=nil )
        if control.is_a? SKUI::Textbox or control.is_a? SKUI::Listbox
          label = SKUI::Label.new( name.capitalize + ':', control )
          group.add_control( label )
        end
        group.add_control( control )
      end

      # (!) these methods need to be moved to a connection object, not in a window!

      # Description: Checkin a new model by sending a serialized form
      # Returns: An id, which you can use for the getCheckinState method
      def checkin(ifc_file, projectOid)

        file = File.new(ifc_file, "r")
        file_contents = file.read
        file_size = file.size

        poid = projectOid # (!) check for valid id! unclear server error if id = nil
        comment = ""
        deserializerOid = get_deserializerOid("Ifc2x3tc1 Step Deserializer")
        fileSize = file.size
        fileName = Sketchup.active_model.title + ".ifc"
        data = Base64.encode64(file_contents)
        sync = "false"
        begin
          id = @conn.bimsie1_service_interface.checkin( poid, comment, deserializerOid, fileSize, fileName, data, sync)
          @status.value = ('Model upload succesful.')
          id
        rescue Exception => err
          @status.value = "Error during upload: #{err}"
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
      #def puts( response )
      #  @log.value += Time.now.strftime("%I:%M:%S") + ': ' + response + "\n"
      #end # def log
    end # class UploadWindow
  end # module BIMserver
end # module OpenSourceBIM
