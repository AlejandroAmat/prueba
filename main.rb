equire "gtk3"
require "css"
require "thread"
require "httpx"
require "json"
require_relative "Puzzle01"
require "ruby-nfc"
require_relative "taula"

#require 'i2c/drivers/lcd'
require 'facets/timer'

class Finestra
        attr_accessor :label, :window, :window2, :grid, :grid2, :blau, :blanc, :vermell, :lector, :uid, :button, :search, :taula, :timer, :font, :label2, :css_provider, :style_prov
      

        def initialize #Inicialitzem les variables d'interés en el constructor. Creem la finestra principal.
                @css_provider= Gtk::CssProvider.new
                @css_provider.load_from_path('stylesheet.css')
                @style_prov = Gtk::StyleProvider::PRIORITY_USER
                @resposta=""
                @req = ""
                @rf= Rfid.new
                @display = I2C::Drivers::LCD::Display.new('/dev/i2c-1', 0x27)
                @display.clear
                @display.text(' Please, login with',0)
                @display.text(' your university card:',1)
                @timer = Timer.new

                #Configuració de la finestra inicial
                @window = Gtk::Window.new("Critical Design")
                @window.set_title("Lector MFRC522")
                @window.set_default_size(400,200)
                @window.set_border_width(10)
                @window.set_window_position(:CENTER)
                
                #Finestra sessio iniciada
                @window2 = Gtk::Window.new("Critical Design")
                @window2.set_title("Login")
                @window2.set_default_size(400,400)
                @window2.set_border_width(10)
                @window2.set_window_position(:CENTER)
                @font=Pango::FontDescription.new('15')
       end
       
      def init #funció que crea les variables de cada finestra que després , en funcio del estat mostrarà.
                @window = Gtk::Window.new("Critical Design")
                @window.set_title("Lector MFRC522")
                @window.set_default_size(400,200)
                @window.set_border_width(10)
                @window.set_window_position(:CENTER)
                
                @window2 = Gtk::Window.new("Critical Design")
                @window2.set_title("Login")
                @window2.set_default_size(400,400)
                @window2.set_border_width(10)
                @window2.set_window_position(:CENTER) 
                       
                startWindow1 #comença la finestra1 que es d'on es parteix
                @timer.reset
      end
      

      def startWindow1
      
                #Configuració del label inicial
                @label=Gtk::Label.new("Please put your card on the reader")
                @label.override_font(@font)
                @label.style_context.add_provider(@css_provider, @style_prov)
                @label.set_name("uid")

                #Configuració del grid
                @grid = Gtk::Grid.new
                @window.add(@grid)
                @grid.set_column_homogeneous(true)
                @grid.set_row_homogeneous(true)
                @grid.set_row_spacing(7)
                @grid.attach(@label,5,0,5,5)

                @window.show_all
                puts "Finestra creada"
                self.newthread #un cop mostrada la finestra crida a la funció encarregada de crear thread auxiliar encarregat de la gestió de lectura
      end
     


      def newthread
        tr=Thread.new {
                get_user #es crea thread i cridem a la funció get_user que es per llegir la targeta de l'usuari
                tr.exit
        }
      end
 

      def logout
        req=HTTPX.get('http://172.20.10.2:4344?d?').to_str  # en cas d'apretar el botó logout s'envia get al servidor indicant desconexió.
        puts req #disconnected
        
        endWindow2 #tanquem finestra 2.
        init #tornem a cridad la inicialització
      end

        def get_user
          @uid = @rf.read_uid.to_s  #llegeix uid de RFID i envia request al servidor
          @url = 'http://172.20.10.2:4344?' + @uid
          @resposta = HTTPX.get(@url).to_str
          
          puts @resposta

          login(@resposta)
          #GLib::Idle.add(login(@resposta))   #es crida a la funció resposta però es delega al thread principal



        end

          def login(resposta)
          puts resposta

                if resposta.eql? 'error' #Si el servidor retorna error es que no s'ha trobat usuari. Es torna a llegir UID. funció startWIndow1
                        puts "Usuari no trobat"
                        startWindow1

                else
                        puts "WELCOME " + resposta #Si es reb un nom, es crea el timer, tanquem window1 i comencem la 2
                        timer_manage
                        endWindow1
                        startWindow2

                        @timer.start
                end
          end

    def startWindow2
                #afegim tots els elements UI necessaris
                @grid2=Gtk::Grid.new
                @search=Gtk::Entry.new
                @window2.add(@grid2)
                
                #Creem la pagina d'inici
                welcome = "WELCOME " + @resposta
                @label2= Gtk::Label.new(welcome)
                @label2.override_font(@font)
                @label2.style_context.add_provider(@css_provider, @style_prov)
                @label2.set_name("lletra_blava")
                @button=Gtk::Button.new(:label => "Logout")
                @button.signal_connect('clicked') {logout}
                
                
                @grid2.set_row_spacing(10)
                al=Gtk::Align.new(2)
                @button.set_halign(al)
                @button.set_hexpand(true)
                
                @grid2.attach(@button,1,0,9,1)
                @grid2.attach(@label2,0,0,1,1)
                @grid2.attach(@search,0,7,10,1)
               
                @window2.show_all
                

                @search.signal_connect "activate" do |_widget| #Gestió de què succeeix quan enviem una query== s'activa el search bar
                        @timer.reset
                        @timer.start
                        t = Thread.new{ #Creem un thread per gestionar el get i la resposta
                                @url = 'http://172.20.10.2:4344?' + @search.text
                                @resposta = HTTPX.get(@url).to_str #passem a string per passarli a la funció crea Taula que esta com a classe al archiu Taula.rb
                                puts @resposta
                                t.exit
                        }
                        t.join
                        
                        10.times do |i| #Borrem la taula existent
                                @grid2.remove_row(14)
                        end
                        
                         if @resposta.to_str != 'error'
                                 @taula = Taula.new.crearTaula(@resposta)
                                   if @taula != nil
                                      @taula.set_hexpand(true)
                                     al2=Gtk::Align.new(3) 
                                     @taula.set_halign(al2)
                                      @grid2.attach(@taula,0,14,10,10)
                                 
                                 @window2.show_all
                                   else
                                        puts "empty set"
                                   end
                        else
                                puts  "error in sql comprobation"
                        end
                end
      end
      
      def endWindow1
        @window.destroy
      end
      
      def endWindow2
        @window2.destroy
      end

      def timer_manage
        @timer = Timer.new(10){
               puts "10 seconds"
               endWindow2
               init
               req=HTTPX.get('http://172.20.10.2:4344?d?').to_str #envia request de desocnnexió
        }
        @timer.start

     end
end







fin = Finestra.new
fin.startWindow1

Gtk.main
