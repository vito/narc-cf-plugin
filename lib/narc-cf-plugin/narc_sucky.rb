require "net/ssh"
require "highline"
 
module NarcCfPlugin
  class Narc
    def initialize(host, port, task_id)
      @host = host
      @port = port
      @task_id = task_id
    end

    def set_terminal_size(channel)
      cols, rows = HighLine::SystemExtensions.terminal_size
      channel.send_channel_request "window-change",
        :long, cols,
        :long, rows,
        :long, 8 * cols,
        :long, 20 * rows
    end
     
    def forward_input(channel)
      `stty raw -echo`
    
      while true
        begin
          chr = $stdin.read_nonblock(10)
          channel.send_data(chr)
        rescue Errno::EAGAIN
          sleep 1/60.0
        end
      end
    ensure
      `stty -raw echo`
    end
     
    module SSL2TCP
      def write(str)
        syswrite(str)
      end

      def send(data, flags = 0)
        raise "cannot handle flags #{flags}" unless flags == 0
        write(data)
      end

      def recv(len)
        sysread(len)
      end
    end

    class TCPForwardedSSHSocket
      def initialize(task_id)
        @task_id = task_id
      end

      def open(host, port)
        sock = TCPSocket.open(host, port)

        ctx = OpenSSL::SSL::SSLContext.new
        ctx.set_params(verify_mode: OpenSSL::SSL::VERIFY_NONE)

        OpenSSL::SSL::SSLSocket.new(sock, ctx).tap do |socket|
          socket.extend(SSL2TCP)

          socket.sync_close = true
          socket.connect

          socket.write("GET / HTTP/1.1\r\n")
          socket.write("Host: #{@task_id}\r\n")
          socket.write("Upgrade: tcp\r\n")
          socket.write("Connection: Upgrade\r\n")
          socket.write("\r\n")
          socket.write("\r\n")
        end
      end
    end

    def connect(task, secure_token)
      Net::SSH.start(@host, task,
          :proxy => TCPForwardedSSHSocket.new(@task_id),
          :port => @port, :password => secure_token,
          :auth_methods => %w[password]) do |session|
        session.open_channel do |channel|
          channel.on_data do |ch, data|
            print data
          end
       
          cols, rows = HighLine::SystemExtensions.terminal_size
       
          channel.request_pty :term => "xterm", :chars_wide => cols, :chars_high => rows do |ch, success|
            raise "failed to request pty" unless success
       
            ch.send_channel_request "shell" do |ch, success|
              raise "failed to request shell" unless success
       
              trap("SIGWINCH") { set_terminal_size(ch) }
       
              Thread.new { forward_input(ch) }
            end
          end
        end
       
        session.loop(0.1)
      end
    end
  end
end
