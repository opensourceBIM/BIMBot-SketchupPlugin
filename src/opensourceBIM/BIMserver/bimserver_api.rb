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

# BIMserver connection calls

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
        message =
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
        @token = base_request(message)
        
      end # def initialize
      
      ##################################################################
      ### helper methods
      ##################################################################
    
      # send message to BIMserver and get response
      def request(message)
        
        # Add token to complete the request message
        request =
        {
          "token" => @token,
          "request" => message
        }
        base_request(request)
      end # def request
      
      # send message to BIMserver and get response
      def base_request(request)
        
        request_json = JSON.generate(request)
        response_json = @http_connection.post(@server.path, request_json)
        response = JSON.parse (response_json.body)
        
        #check if a result was found
        if response["response"]["result"]
          result = response["response"]["result"]
          return result
        else
          raise StandardError, response["response"]["exception"]["message"]
          return false
        end
      end # def base_request
      
      # get the oid for the requested deserializer name
      def get_deserializerOid(deserializer_name)
        getAllDeserializers.each do |deserializer|
          if deserializer["name"] == deserializer_name
            return deserializer["oid"]
          end
        end
      end # def get_deserializerOid
      
      # get the oid for the requested project name
      def get_projectOid(project_name)
        getAllProjects.each do |project|
          if project["name"] == project_name
            return project["oid"]
          end
        end
      end # def get_projectOid
      
      ##################################################################
      ### BIMserver API calls
      ##################################################################
    
      ### NOT COMPLETE ###
      #def addExtendedDataToRevision(roid)
        
        #message_hash =
        #{
          #"token" => @token,
          #"request" => 
          #{
            #"interface"=> "Bimsie1ServiceInterface", 
            #"method"=> "addExtendedDataToRevision", 
            #"parameters"=>
            #{
              #"roid"=> roid
              #"extendedData"=>
              #{
                #"added"=> "undefined",
                #"fileId"=> "undefined",
                #"oid"=> "undefined",
                #"projectId"=> "undefined",
                #"revisionId"=> "undefined",
                #"rid"=> "undefined",
                #"schemaId"=> "undefined",
                #"size"=> "undefined",
                #"title"=> "undefined",
                #"url"=> "undefined",
                #"userId"=> "undefined"
              #}
            #}
          #}
        #}
        
        #return request(message_hash)
      #end # def addExtendedDataToRevision
    
      # Description: Checkin a new model by sending a serialized form
      # Returns: An id, which you can use for the getCheckinState method
      def checkin(ifc_file, projectOid)
        #if @token
          file = File.new(ifc_file, "r")
          file_contents = file.read
          file_size = file.size
          file_base64 = Base64.encode64(file_contents)
          
          file_name = Sketchup.active_model.title
          #if not file_name or file_name==""
          #  raise "Please save your project before Exporting to IFC"
          #end
          
          # add IFC file extention
          file_name = file_name + ".ifc"
          
          # use the following deserializer
          deserializer_name = "Ifc2x3tc1 Step Deserializer"
          deserializerOid = get_deserializerOid(deserializer_name)
          
          message_hash =
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
          return request(message_hash)
        #else
        #  log("Unable to checkin model, not logged in on BIMserver")
        #end
        
        
      end # def checkin
    
      # Returns: A list of all available deserializers
      def getAllDeserializers
        message_hash =
        {
          "interface"=> "PluginInterface", 
          "method"=> "getAllDeserializers", 
          "parameters"=>
          {
            "onlyEnabled"=> "true"
          }
        }
        return request(message_hash)
      end # def getAllDeserializers
      
      # Returns: ExtendedData
      def getAllExtendedDataOfRevision( roid )
        message_hash =
        {
          "interface" => "Bimsie1ServiceInterface",
          "method" => "getAllExtendedDataOfRevision",
          "parameters" =>
          {
            "roid" => roid
          }
        }
        return request(message_hash)
      end # def getAllExtendedDataOfRevision
      
      # Returns: The User that it currently loggedin on this ServiceInterface
      def getLoggedInUser
        message_hash =
        {
          "interface" => "AuthInterface",
          "method" => "getLoggedInUser",
          "parameters" =>
          {
          }
        }
        return request(message_hash)
      end # def getLoggedInUser
      
      # Get checkin progress based on topicId returned by checkin request
      def getProgress( topicId )
        message_hash =
        {
          "interface" => "Bimsie1NotificationRegistryInterface",
          "method" => "getProgress",
          "parameters" =>
          {
            "topicId" => topicId
          }
        }
      return request(message_hash)
      end # def getProgress
      
      # Returns: The Project
      def getProjectByPoid( poid )
        message_hash =
        {
          "interface" => "Bimsie1ServiceInterface",
          "method" => "getProjectByPoid",
          "parameters" =>
          {
            "poid" => poid
          }
        }
        return request(message_hash)
      end # def getProjectByPoid
      
      # Description: Get a list of all Projects the user is authorized for
      # Returns: A list of Projects
      def getAllProjects
        message_hash =
        {
          "interface" => "Bimsie1ServiceInterface",
          "method" => "getAllProjects",
          "parameters" =>
          {
            "onlyTopLevel" => "true",
            "onlyActive" => "true"
          }
        }
        return request(message_hash)
      end # def getProjects
      
      # Returns: The Revision
      def getRevision( roid )
        message_hash =
        {
          "interface" => "Bimsie1ServiceInterface",
          "method" => "getRevision",
          "parameters" =>
          {
            "roid" => roid
          }
        }
        return request(message_hash)
      end # def getRevision
      
      # Description: Get a User by its UserName (e-mail address) ###typo in official description
      # Returns: The SUser Object if found, otherwise null
      def getUserByUserName( username )
        message_hash =
        {
            "interface" => "ServiceInterface",
            "method" => "getUserByUserName",
            "parameters" =>
            {
              "username" => username
            }
        }
        return request(message_hash)
      end # def getUserByUserName
      
      # Returns: A list of projects a user has been authorized for
      def getUsersProjects( uoid )
        message_hash =
        {
          "interface" => "ServiceInterface",
          "method" => "getUsersProjects",
          "parameters" =>
          {
            "uoid" => uoid
          }
        }
        return request(message_hash)
      end # def getUsersProjects
      
    end # class BIMserver_connection
  end # BIMserver
end # module OpenSourceBIM
