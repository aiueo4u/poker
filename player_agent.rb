require 'socket'
require 'json'
require './poker'

class PlayerAgent
  attr_accessor :player_name, :player_stack

  def initialize
    @sock = Client.new('localhost', 12345)
    res = @sock.gets
    @player_name = "Player#{res[:no]}"
    @sock.puts(name: player_name)
    res = @sock.gets
    @player_stack = res[:stack]
  end

  def gets; @sock.gets; end
  def puts(hash); @sock.puts(hash); end
  def close; @sock.close; end

  def ping
    @sock.puts(cmd: 'ping')
  end

  #
  # actions
  #

  def bet(amount)
    @sock.puts(cmd: 'bet', action: 'bet', amount: amount)
  end

  def call
    @sock.puts(cmd: 'call', action: 'call')
  end

  def check
    @sock.puts(cmd: '', action: 'check')
  end

  def raise(amount)
    @sock.puts(cmd: 'raise', action: 'raise', amount: amount)
  end

  def win(amount)
  end
end
