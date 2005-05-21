# Copyright (c) 2004 SASADA Koichi <ko1 at atdot.net>
#
# This program is free software with ABSOLUTELY NO WARRANTY.
# You can re-distribute and/or modify this program under
# the same terms of the Ruby's lisence.
#
#
# $Id$
# Create : K.S. 04/05/01 02:04:18

require 'thread'
require 'kconv'

module Nadoka
  
  class NDK_Logger
    def initialize manager, config
      @manager = manager
      @config  = config
      @dlog    = @config.debug_log
      @lock    = Mutex.new
    end
    
    # debug message
    def dlog msg
      if @config.loglevel >= 3
        write_log(@dlog, msg)
      end
    end

    # system message
    def slog msg, nostamp = false
      str = "[NDK] #{msg}"
      if @config.loglevel >= 2
        write_log(make_logfilename(@config.system_log), str, nostamp)
      end
      @manager.send_to_clients Cmd.notice(@manager.state.nick, str) if @manager.state
      dlog msg
    end

    # channel message
    def clog ch, msg, nostamp = false
      logfile = (@config.channel_info[ch] && @config.channel_info[ch][:log]) ||
                 @config.default_log
      logfile = make_logfilename(logfile, ch)
      write_log(logfile, msg, nostamp)
    end

    # other irc log message
    def log msg
      if @config.loglevel >= 1
        write_log(make_logfilename(@config.system_log), msg)
      end
    end

    # logging
    def logging msg
      user = @manager.nick_of(msg)
      ch_ = ch = @config.canonical_channel_name(msg.params[0])
      
      unless /\A[\&\#\+\!]/ =~ ch
        if ch == @config.canonical_channel_name(@manager.state.nick)
          ch_ = @config.canonical_channel_name(user)
        end
      end
      
      case msg.command
      when 'PRIVMSG'
        str = "<#{ch}:#{user}> #{msg.params[1]}"
        clog ch_, str
        
      when 'NOTICE'
        str = "{#{ch}:#{user}} #{msg.params[1]}"
        clog ch_, str
        
      when 'JOIN', 'PART', 'NICK', 'QUIT'
        # ignore
        
      when /^\d+/
        # reply
        str = msg.command + ' ' + msg.params.join(' ')
        log str
        
      else
        # other command
        log msg.to_s
      end
    end
    

    ###

    def write_log io, msg, nostamp = false
      msg = "#{Time.now.strftime(@config.log_timeformat)} #{msg}" unless nostamp

      begin
        if io.respond_to? :puts
          @lock.synchronize{
            io.puts msg
          }
        else
          bdir = File.expand_path(@config.log_dir)
          
          @lock.synchronize{
            open(File.expand_path(io, bdir), 'a'){|f|
              f.puts msg
            }
          }
        end
      rescue IOError
        # ignore IOError
      end
    end
    
    RName = {        # ('&','#','+','!')
      '#' => 'Cs-',
      '&' => 'Ca-',
      '+' => 'Cp-',
      '!' => 'Ce-',
    }
    def make_logfilename(tmpl, ch='')

      case (@config.filenameencoding || '')[0]
      when ?e
        ch = ch.toeuc
      when ?s
        ch = ch.tosjis
      end
      
      ch  = ch.sub(/^[\&\#\+\!]|/){|c|
        RName[c]
      }
      ch  = URI.encode(ch) unless @config.filenameencoding
      ch  = ch.gsub(/\*|\:/, '_')
      ch  = ch.gsub(/\//, 'I')
      str = Time.now.strftime(tmpl)

      str.gsub!(/\$\{setting_name\}/, @config.setting_name)
      str.gsub!(/\$\{channel_name\}/, ch)
      str
    end
  end
end

