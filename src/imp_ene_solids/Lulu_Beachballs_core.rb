# A set of methods to animate the cursor
# Lulu Walls
# https://github.com/LuluWalls/Beachballs
#
# Example:
#   module Test_Lulu
#     def self.spin()
#       # start the spinning beach ball
#       Lulu::Beachballs.start()
#     
#       #perform a long calculation
#       a = 0
#       40000000.times do
#         a = a + 1
#       end
#     
#       # Throw an exception
#       #x = 10/0
#   
#       # always ensure you didn't drop the ball
#       ensure
#       Lulu::Beachballs.stop()
#       
#     end # sin  
#     
#     toolbar = UI::Toolbar.new "Test Beachballs"
#     cmd = UI::Command.new("Test") {spin()}
#     toolbar = toolbar.add_item cmd
#     toolbar.show
#   
#   end #module
#
# Methods 
#   start()
#   stop()
#   single_step()
# 
# Controls 
#   speed - time between rotation steps (in seconds)
#   run - allow the creation of the animation thread (true/false)
#   suspend - inhibit the throwing of interrupt signals by the animation thread (true/false)



if !!defined? Lulu::Beachballs
  puts "Lulu::Beachballs version #{Lulu::Beachballs.version} is already loaded" # in " + File.dirname(__FILE__)
else

  module Lulu
    PLUGIN_DIR = File.dirname(__FILE__)
    
    module Beachballs
      @speed = 0.1
      @run = true
      @suspend = false
      
      # load the eight cursors that we will animate while we are busy
      # http://ruby.sketchup.com/UI.html#create_cursor-class_method
      # Says: This must be called from within a custom Tool. See the Tool class for a complete example.
      # Obviously this statement is not accurate
      def self.load_cursors()
        @busy_cursors = []
        @busy_cursors << UI.create_cursor(File.join(PLUGIN_DIR, "images", "BWaitQ1.png"), 2, 2)
        @busy_cursors << UI.create_cursor(File.join(PLUGIN_DIR, "images", "BWaitQ2.png"), 2, 2)
        @busy_cursors << UI.create_cursor(File.join(PLUGIN_DIR, "images", "BWaitQ3.png"), 2, 2)
        @busy_cursors << UI.create_cursor(File.join(PLUGIN_DIR, "images", "BWaitQ4.png"), 2, 2)
        @busy_cursors << UI.create_cursor(File.join(PLUGIN_DIR, "images", "BWaitQ5.png"), 2, 2)
        @busy_cursors << UI.create_cursor(File.join(PLUGIN_DIR, "images", "BWaitQ6.png"), 2, 2)
        @busy_cursors << UI.create_cursor(File.join(PLUGIN_DIR, "images", "BWaitQ7.png"), 2, 2)
        @busy_cursors << UI.create_cursor(File.join(PLUGIN_DIR, "images", "BWaitQ8.png"), 2, 2)
        @cursor_index = 0
      end
      load_cursors()
      
      def self.start()
        #puts 'start cursor thread called'
        #@time = Time.now
        if @run == true
          UI.set_cursor(@busy_cursors[@cursor_index])
          @cursor_thread = Thread.new {cursor_worker_thread()}
          @cursor_thread.priority = 4
        end
      end
      
      def self.stop()
         #puts 'stop cursor thread called'
         #terminate the worker thread
         #puts 'Execution time = ' + (Time.now - @time).to_s
         @cursor_thread.exit if @cursor_thread 
      end

      def self.single_step()
        @cursor_index = (@cursor_index + 1) % 8
        UI.set_cursor(@busy_cursors[@cursor_index])
      end

      def self.cursor_worker_thread()
        while true
          sleep(@speed)
          #send the INT signal to the main thread
          if @suspend == false
            @cursor_do = true
            Process.kill("INT", Process.pid) 
          end
        end 
      end

      
      # Trap SIGINT signal in the main thread since
      # only the main thread can access the UI.set_cursor
      # during an active model operation
      if !@old_signal_handler
        puts 'Lulu\'s Beachballs - adding Signal trap SIGINT'
        @old_signal_handler = Signal.trap("INT") do 
          #puts 'Cursor Thread Interrupt'
          if @cursor_do 
            @cursor_index = (@cursor_index + 1) % 8
            UI.set_cursor(@busy_cursors[@cursor_index])
            @cursor_do = nil
          else
            # try to call the chain of handlers if I have no work to do
            # https://stackoverflow.com/questions/29568298/run-code-when-signal-is-sent-but-do-not-trap-the-signal-in-ruby
            # this might be total BS, this has not been debugged
            @old_signal_handler.call if @old_signal_handler.respond_to?(:call)
          end
        end
      end
      
      # User settings
      
      # animation time interval in seconds
      def self.speed
        @speed
      end

      def self.speed=(val)
        @speed = val
      end

      # false disables the creation on the animation thread    
      def self.run
        @run
      end

      def self.run=(val)
        @run = val
      end
      
      #true stops the calling of SIGINT
      def self.suspend
        @suspend
      end

      def self.suspend=(val)
        @suspend = val
      end
      
      def self.version
          '1.0.0'
      end
    
    end
  end # module 

end # if defined?
