#  core.rb
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

require 'uri'
require 'net/http'
require 'JSON'
require "base64"
    
module Brewsky::BIMserver
  
  # Create toolbar containing all available BIMserver tools.
  toolbar = UI::Toolbar.new "BIMserver"
  
  # This toolbar command exports the current model to BIMserver.
  cmd = UI::Command.new("Export to BIMserver") {
   BIMserver_testcall()
  }
  cmd.small_icon = File.join(PLUGIN_IMAGE_PATH, "bimserver_small.png")
  cmd.large_icon = File.join(PLUGIN_IMAGE_PATH, "bimserver_large.png")
  cmd.tooltip = "Export to BIMserver"
  cmd.status_bar_text = "Exporting to BIMserver..."
  cmd.menu_text = "Export to BIMserver"
  toolbar = toolbar.add_item cmd
  toolbar.show
  
  # Load SKUI ui library
  extension_path = File.dirname( __FILE__ )
  skui_path = File.join( extension_path, 'SKUI' )
  load File.join( skui_path, 'embed_skui.rb' )
  ::SKUI.embed_in( self )
  # SKUI module is now available under Brewsky::BIMserver::SKUI

  # Add a menu item to launch our plugin.
  UI.menu("Plugins").add_item("Send to BIMserver") {

    # create SKUI webdialog    
    options = {
      :title           => 'BIMserver Export',
      :preferences_key => 'BIMserver',
      :width           => 600,
      :height          => 550,
      :resizable       => true
    }
    w = SKUI::Window.new( options )
    
    # add login elements
    group = SKUI::Groupbox.new( 'Upload to BIMserver' )
    group.position( 5, 5 )
    group.right = 5
    group.height = 150
    
    txt1 = SKUI::Textbox.new( 'thebimfederationserver.thebimfederation.com:8080' )
    txt1.name = :txt_server
    txt1.position( 120, 20 )
    txt1.width = 300
    txt1.right = 10 # (!) Currently ignored by browser.
    group.add_control( txt1 )

    lbl1 = SKUI::Label.new( 'BIMserver: http://', txt1 )
    lbl1.position( 10, 20 )
    lbl1.width = 100
    group.add_control( lbl1 )
    
    txt2 = SKUI::Textbox.new()
    txt2.name = :txt_name
    txt2.position( 120, 40 )
    txt2.width = 300
    txt2.right = 10 # (!) Currently ignored by browser.
    group.add_control( txt2 )

    lbl2 = SKUI::Label.new( 'user: @', txt2 )
    lbl2.position( 10, 40 )
    lbl2.width = 50
    group.add_control( lbl2 )
    
    txt3 = SKUI::Textbox.new()
    txt3.name = :txt_password
    txt3.position( 120, 60 )
    txt3.width = 300
    txt3.right = 10 # (!) Currently ignored by browser.
    group.add_control( txt3 )

    lbl3 = SKUI::Label.new( 'password:', txt3 )
    lbl3.position( 10, 60 )
    lbl3.width = 100
    group.add_control( lbl3 )
    
    # create send button
    b = SKUI::Button.new( 'Upload!' ) { BIMserver_testcall() }
    b.position( 10, 90 )
    group.add_control( b )
    
    w.add_control( group )
    
    # create multiline textbox for IFC content
    tb = SKUI::Textbox.new( output )
    tb.multiline = true
    tb.position( 10, 130 )
    tb.right = 5
    tb.height = 320
    w.add_control( tb )
    w.show
    
  }
  class BIMserver_connection
    def initialize(server, user, password)
      @user = user
      @password = password
      @uri = URI(server)
      @log = ""
      
      # create http connection to BIMserver
      @http_connection = Net::HTTP.new(@uri.host, @uri.port)
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
    
    def log(message=nil)
      if message.is_a? String 
        @log << message + "\n"
      end
      return @log
    end
    
    # send message to BIMserver and get response
    def request(message_hash)
      #puts JSON.pretty_generate(message_hash)
      message_json = JSON.generate(message_hash)
      response_json = @http_connection.post(@uri.path, message_json)
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
    
    def checkin(ifc_file, project_name)
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
        
        # checkin into the following project
        projectOid = get_projectOid(project_name)
        
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
    def getAllProjects
      
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
    end # def getAllProjects
    
    # get the oid for the requested project name
    def get_projectOid(project_name)
      getAllProjects.each do |project|
        if project["name"] == project_name
          return project["oid"]
        end
      end
    end # def get_projectOid
    
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
    
  end # class BIMserver_connection
  
  # Test method for uploading the current SketchUp model to a BIMserver
  def self.BIMserver_testcall()
    
    # BIMserver parameters
    server = "http://thebimfederationserver.thebimfederation.com:80/json"
    user = "jan@brewsky.nl"
    password = "***REMOVED***"
    project = "su2BIMserver"
    
    # make connection with BIMserver
    begin
      conn = BIMserver_connection.new(server, user, password)
    
      # Export model to temporary IFC file
      model = Sketchup.active_model
      tempdir=ENV["TMPDIR"] if not tempdir=ENV["TEMP"]
      tempfile = File.join(tempdir, "tmp.ifc")
      show_summary = false
      model.export tempfile, show_summary
      
      file = nil
      counter = 1
      output = ""
      begin
        file = File.new(tempfile, "r")
        while (line = file.gets)
          output = output + line
          counter = counter + 1
        end
        file.close
      rescue => err
        puts "Error reading temporary IFC file: #{err}"
        err
      end
      
      # checkin IFC file
      conn.checkin(tempfile, project)
    rescue SocketError => err
        puts "Error connecting to BIMserver: #{err}"
    rescue => err
        puts err
    end
    
  end # def BIMserver_testcall()
end # module Brewsky::BIMserver
