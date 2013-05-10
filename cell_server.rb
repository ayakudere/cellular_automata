require 'json'
require 'webrick'

class Game
  attr_reader :state

  def initialize(state, rule)
    @state = state
    @table = {}
    (0..7).each do |i|
      @table[dec_to_bin(i)] = rule % 2
      rule /= 2
    end
  end
  
  def new_state
    padded_state = [0,0] + @state + [0,0]
    new_state = []
    (@state.size + 2).times do
      s = padded_state[0..2]
      new_state << @table[s]
      padded_state.shift
    end
    new_state
  end

  def new_state!
    @state = new_state
  end
  
  private
  
  def dec_to_bin(a)
    ([a % 2] + Array.new(2).map { a /= 2; a % 2 }).reverse
  end
end

def compress_state(state)
  compressed_state = [[state.shift, 1]]
  until state.empty?
    t = state.shift
    if compressed_state[-1][0] == t
      compressed_state[-1][1] += 1
    else
      compressed_state << [t, 1]
    end
  end
  compressed_state
end

def compress_states(states)
  states.map { |state| compress_state(state) }
end

def decompress_state(state)
  state.reduce([]) { |s,t| s + ([t[0]] * t[1]) }
end

server = WEBrick::HTTPServer.new :Port => 8000

server.mount_proc '/' do |req, res|
  begin
    res.header["Access-Control-Allow-Origin"] = "*"
    state = decompress_state(JSON.parse(req.query['state']))
    rule = req.query['rule'].to_i
    n = (req.query['n'] || 0).to_i
    g = Game.new(state, rule)
    new_states = []
    n.times { new_states << g.new_state! }
    res.body = JSON.generate(compress_states(new_states))
  rescue Exception => err
    res.set_error(err)
  end
end

Signal.trap('INT') { server.shutdown }

server.start