#  core.rb
#  
#  Copyright 2015 Jan <Jan@ASUS>
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

module BIMserver
  extension_path = File.dirname( __FILE__ )
  skui_path = File.join( extension_path, 'SKUI' )
  load File.join( skui_path, 'embed_skui.rb' )
  ::SKUI.embed_in( self )
  # SKUI module is now available under Example::SKUI

  # Add a menu item to launch our plugin.
  UI.menu("Plugins").add_item("Send to BIMserver") {
    model = Sketchup.active_model
    tempdir=ENV["TMPDIR"] if not tempdir=ENV["TEMP"]
    tempfile = File.join(tempdir, "tmp.ifc")
    show_summary = false
    model.export tempfile, show_summary
    
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
      puts "Exception: #{err}"
      err
    end
    
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
    b = SKUI::Button.new( 'Upload!' ) { UI.messagebox('Upload failed :-(') }
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
end # module BIMserver
