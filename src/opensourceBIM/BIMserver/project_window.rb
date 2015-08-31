#  project_window.rb
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

    require File.join( PLUGIN_PATH, 'menu_section.rb' )

    class ProjectWindow
      attr_reader :window, :ready, :profiles, :sec_connection, :sec_server, :sec_revisions, :sec_projects
      def initialize()

        # empty projectlist hash
        @revisionlist = Hash.new

        @extended_data_list = Array.new

        # create menu window
        options = {
          :title           => 'BIMserver connector',
          :preferences_key => 'BIMserver',
          :width           => 267,
          :height          => 600,
          #  :scrollable      => true,
          :resizable       => false,
          :theme           => File.join( PLUGIN_PATH_CSS, 'theme.css' ).freeze
        }

        @window = SKUI::Window.new(options)
        @group = MenuSection.new( 'Project info', self)
        @group_ext_data = MenuSection.new( 'Extended data', self)

        # check if window is ready
        @window.on( :ready ) {
          @ready = true
        }

        @profile = SKUI::Textbox.new( 'Active profile: ' + BIMserver.profiles.active_profile.name )
        @profile.readonly = true
        @group.add_control( @profile )

        # create connection object that connects to the server
        begin
          profile = BIMserver.profiles.active_profile
          @conn = OpenSourceBIM::BIMserverAPI::Connection.new( profile.address, profile.port )

          # login on the server
          begin
            @conn.login( profile.username, profile.password )
            #puts ('Connected to BIMserver at ' + address.value)
            puts ('Logged in as ' + profile.username)

            # Get user id
            uoid = @conn.auth_interface.getLoggedInUser["oid"]
              
    
            project_oid = profile.project_oid
            project_name = profile.project
              

            # get the current project
            begin
              project = @conn.bimsie1_service_interface.getProjectByPoid( project_oid )
            rescue Exception => error
              set_status( error )
            end
            
            
            roid = @conn.bimsie1_service_interface.getProjectByPoid( project_oid )['lastRevisionId']
            revision = @conn.bimsie1_service_interface.getRevision( roid )

            time = Time.at(project['createdDate']/1000.0).strftime("%Y-%m-%d %H:%M.%S")
            
            project_text = ''
            project_text << "Name: " + project['name'].to_s << "\n"
            project_text << "Description: " + project['description'].to_s << "\n"
            project_text << "Revision Id: " + revision['id'].to_s << "\n"
              
            
            # Project info
            project_info = SKUI::Textbox.new( project_text )
            project_info.readonly = true
            project_info.multiline = true
            @group.add_control( project_info )
            
          rescue Exception => err
            puts "Error connecting to BIMserver: #{err}"
          end
        rescue Exception => err
          puts = "Error: #{err}"
        end

          profile = BIMserver.profiles.active_profile
          project_oid = BIMserver.profiles.active_profile.project_oid

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

              #@revision.clear()
              @revisionlist.clear()
              
              # get the id of the last revision
              begin
                roid = @conn.bimsie1_service_interface.getProjectByPoid( project_oid )['lastRevisionId']

                # show extended data for revision
                @conn.bimsie1_service_interface.getAllExtendedDataOfRevision( roid ).each do | extended_data |

                  # add extended_data to array if it's not already there
                  unless @extended_data_list.include?( extended_data['oid'] )

                    time = Time.at(extended_data['added']/1000.0).strftime("%Y-%m-%d %H:%M.%S")

                    text = ''
                    text << "Title: " + extended_data['title'].to_s << "\n"
                    text << "Revision Id: " + extended_data['revisionId'].to_s << "\n"
                    text << "Added: " + time << "\n"
                    text << "Size: " + extended_data['size'].to_s + " bytes"<< "\n"

                    ext_data = SKUI::Textbox.new( text )
                    ext_data.readonly = true
                    ext_data.multiline = true
                    @group_ext_data.add_control( ext_data )

                    file_id = extended_data['fileId']
                    html = Base64.decode64( @conn.service_interface.getFile( file_id )['data'] )
                    if html.include? "<html" # probably html

                      # add extended data button
                      ext_data = SKUI::Button.new( 'show' ) { |control|

                        dlg = UI::WebDialog.new("Extended data", true, "ExtendedData", 739, 641, 150, 150, true);
                        dlg.set_html( html )
                        dlg.show
                      }

                      @group_ext_data.add_control( ext_data )
                    end
                  end
                end

              rescue Exception => error
                puts error
              end

              # Get list of projects
              @conn.service_interface.getUsersProjects( uoid ).each do |project|
                # if project is subproject: change formatting
                if project["parentId"] == -1
                  @projectlist[project["name"]] = project["oid"]
                  @project.add_item(project["name"])
                else
                  parent = @conn.bimsie1_service_interface.getProjectByPoid( project["parentId"] )
                  @projectlist[parent["name"] + ": " + project["name"]] = project["oid"]
                end
              end
            rescue Exception => err
              puts "Error connecting to BIMserver: #{err}"
            end
          rescue Exception => err
            puts = "Error: #{err}"
          end
        @window.show
      end # def initialize

      # get the list of projects from the BIMserver and show these in a select box
      def show_checkin(conn)
        @conn = conn
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
        @sec_projects.maximize

        # Create listbox containing projects
        lst_dropdown = SKUI::Listbox.new( @list.keys )
        lst_dropdown.value = lst_dropdown.items.first
        lbl_projects = SKUI::Label.new( 'Project:', lst_dropdown )
        @sec_projects.add_control( lbl_projects )
        @sec_projects.add_control( lst_dropdown )

        btn_proj_delete = SKUI::Button.new( 'Delete' ) { |control|
          puts 'Delete...'
          @sec_server.maximize
        }
        @sec_projects.add_control( btn_proj_delete )

        btn_proj_select = SKUI::Button.new( 'Select' ) { |control|
          puts 'Select...'
          @sec_server.minimize
        }
        @sec_projects.add_control( btn_proj_select )
        return @sec_projects

      end # def show_checkin

      def toggle
        @window.toggle
      end
    end # class ProjectWindow
  end # module BIMserver
end # module OpenSourceBIM
