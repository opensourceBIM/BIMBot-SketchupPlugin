#  connection.rb
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
    class Connection
      attr_reader :profile
      def initialize( profile )
        puts "connection!"
        @profile = profile
        # create connection object that connects to the server
        begin

          @conn = OpenSourceBIM::BIMserverAPI::Connection.new( profile.address, profile.port )
          puts('Connected to BIMserver at ' + profile.address)

          # login on the server
          begin
            @conn.login( profile.username, profile.password )
            #puts ('Connected to BIMserver at ' + address.value)
            #puts ('Logged in as ' + profile.username)
            puts('Logged in as ' + profile.username)

            # Get user id
            uoid = @conn.auth_interface.getLoggedInUser["oid"]
    
            # change toolbar button status
            enable_buttons
          rescue Exception => err
            
            # change toolbar button status
            disable_buttons
            
            puts("Error connecting to BIMserver: #{err}")
          end
        rescue Exception => err
          
          # change toolbar button status
          disable_buttons
          
          puts("Error: #{err}")
        end
      end
      def disable_buttons
        # change toolbar button status
        BIMserver.buttons_enabled = false
        unless BIMserver.btn_upload.nil?
          BIMserver.btn_upload.set_validation_proc {
            #    @btn_upload.status_bar_text = "3r53fegesge"
            MF_GRAYED
          }
        end
        unless BIMserver.btn_project.nil?
          BIMserver.btn_project.set_validation_proc {
            MF_GRAYED
          }
        end
      end
      def enable_buttons
        # change toolbar button status
        BIMserver.buttons_enabled = true
        unless BIMserver.btn_upload.nil?
          BIMserver.btn_upload.set_validation_proc {
            #    @btn_upload.status_bar_text = "3r53fegesge"
            MF_ENABLED
          }
        end
        unless BIMserver.btn_project.nil?
          BIMserver.btn_project.set_validation_proc {
            MF_ENABLED
          }
        end
      end
    end
  end # module BIMserver
end # module OpenSourceBIM
