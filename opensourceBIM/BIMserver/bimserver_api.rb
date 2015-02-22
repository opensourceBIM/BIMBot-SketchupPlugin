#  bimserver_api.rb
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
    class BIMserver_connection
      attr_reader :token
    
      require 'uri'
      require 'net/http'
      require 'JSON'
      require "base64"

      def initialize(server, port, user, password)
        @user = user
        @password = password
        @log = ""
        
        # BIMserver parameters
        @server = URI(server + ":" + port + "/json")
        
        # create http connection to BIMserver
        @http_connection = Net::HTTP.new(@server.host, @server.port)
        @http_connection.use_ssl = false
        
        #login on BIMserver
        message_hash =
        {
          "request"=>
          {
            "interface"=>"Bimsie1AuthInterface",
            "method"=>"login",
            "parameters"=>
            {
              "username"=> @user,
              "password"=> @password
            }
          }
        }
        @token = request(message_hash)
        
      end # def initialize
    
      def checkin(ifc_file, projectOid)
        #if @token
          file = File.new(ifc_file, "r")
          file_contents = file.read
          file_size = file.size
          file_base64 = Base64.encode64(file_contents)
          
          file_name = Sketchup.active_model.title
          if not file_name or file_name==""
            UI.messagebox("IFC Exporter:\n\nPlease save your project before Exporting to IFC\n")
            return nil
          end
          
          # add IFC file extention
          file_name = file_name + ".ifc"
          
          # use the following deserializer
          deserializer_name = "Ifc2x3tc1 Step Deserializer"
          deserializerOid = get_deserializerOid(deserializer_name)
          
          message_hash =
          {
            "token" => @token,
            "request" => 
            {
              "interface" => "Bimsie1ServiceInterface",
              "method" => "checkin",
              "parameters" =>
              {
                "poid"=> projectOid,
                "comment"=> "",
                "deserializerOid"=> deserializerOid,
                "fileSize"=> file_size,
                "fileName"=> file_name,
                "data"=> file_base64,
                "sync"=> "false"
              }
            }
          }
          return request(message_hash)
        #else
        #  log("Unable to checkin model, not logged in on BIMserver")
        #end
        
        
      end # def checkin
    
      # retreive a hash with all active deserialisers
      def getAllDeserializers
        
        message_hash =
        {
          "token" => @token,
          "request" => 
          {
            "interface"=> "PluginInterface", 
            "method"=> "getAllDeserializers", 
            "parameters"=>
            {
              "onlyEnabled"=> "true"
            }
          }
        }
        
        return request(message_hash)
      end # def getAllDeserializers
      
      # get the oid for the requested deserializer name
      def get_deserializerOid(deserializer_name)
        getAllDeserializers.each do |deserializer|
          if deserializer["name"] == deserializer_name
            return deserializer["oid"]
          end
        end
      end # def get_deserializerOid
      
      def getProjects
        
        message_hash =
        {
          "token" => @token,
          "request" => 
          {
            "interface" => "Bimsie1ServiceInterface",
            "method" => "getAllProjects",
            "parameters" =>
            {
              "onlyTopLevel" => "true",
              "onlyActive" => "true"
            }
          }
        }
        return request(message_hash)
      end # def getProjects
      
      # get the oid for the requested project name
      def get_projectOid(project_name)
        getProjects.each do |project|
          if project["name"] == project_name
            return project["oid"]
          end
        end
      end # def get_projectOid
    
      # send message to BIMserver and get response
      def request(message_hash)
        #puts JSON.pretty_generate(message_hash)
        message_json = JSON.generate(message_hash)
        response_json = @http_connection.post(@server.path, message_json)
        response = JSON.parse (response_json.body)
        #puts JSON.pretty_generate(response)
        
        #check if a result was found
        if response["response"]["result"]
          result = response["response"]["result"]
          return result
        else
          raise StandardError, "BIMserver: " + response["response"]["exception"]["message"]
          return false
        end
      end # def request
    end # class BIMserver_connection
  end # BIMserver
end # module OpenSourceBIM
