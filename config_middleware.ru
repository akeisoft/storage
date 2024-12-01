require 'rack'
require 'json'

class LoggerMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    start_time = Time.now
    puts "Incoming request: #{env['REQUEST_METHOD']} #{env['PATH_INFO']}"
    status, headers, response = @app.call(env)
    duration = Time.now - start_time
    puts "Response status: #{status}, Time taken: #{duration.round(4)}s"
    [ status, headers, response ]
  end
end

class AuthMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    req = Rack::Request.new(env)
    token = req.params['token']
    if token == 'secret-token'
      env['authenticated'] = true
      @app.call(env)
    else
      [ 401, { 'Content-Type' => 'application/json' }, [ { error: 'Unauthorized' }.to_json ] ]
    end
  end
end

class Router
  def call(env)
    req = Rack::Request.new(env)

    case [ req.request_method, req.path_info ]
    when [ 'GET', '/' ]
      handle_root(env)
    when [ 'GET', '/users' ]
      handle_users(env)
    when [ 'POST', '/users' ]
      handle_create_user(env)
    else
      [ 404, { 'Content-Type' => 'application/json' }, [ { error: 'Not Found' }.to_json ] ]
    end
  end

  private

  def handle_root(env)
    [ 200, { 'Content-Type' => 'application/json' }, [ { message: 'Welcome to the API' }.to_json ] ]
  end

  def handle_users(env)
    users = [
      { id: 1, name: 'Alice' },
      { id: 2, name: 'Bob' }
    ]
    [ 200, { 'Content-Type' => 'application/json' }, [ users.to_json ] ]
  end

  def handle_create_user(env)
    req = Rack::Request.new(env)
    begin
      body = JSON.parse(req.body.read)
      name = body['name']

      if name.nil? || name.strip.empty?
        return [ 400, { 'Content-Type' => 'application/json' }, [ { error: 'Name is required' }.to_json ] ]
      end

      new_user = { id: rand(1000), name: name }
      [ 201, { 'Content-Type' => 'application/json' }, [ new_user.to_json ] ]
    rescue JSON::ParserError
      [ 400, { 'Content-Type' => 'application/json' }, [ { error: 'Invalid JSON' }.to_json ] ]
    end
  end
end


class ErrorHandlingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    begin
      @app.call(env)
    rescue StandardError => e
      puts "Error: #{e.message}"
      [ 500, { 'Content-Type' => 'application/json' }, [ { error: 'Internal Server Error' }.to_json ] ]
    end
  end
end

class SessionMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    req = Rack::Request.new(env)
    env['rack.session'] ||= {}

    if req.path_info == '/set_session'
      env['rack.session'][:example] = 'session_value'
      [ 200, { 'Content-Type' => 'application/json' }, [ { message: 'Session set' }.to_json ] ]
    elsif req.path_info == '/get_session'
      session_value = env['rack.session'][:example]
      [ 200, { 'Content-Type' => 'application/json' }, [ { session_value: session_value }.to_json ] ]
    else
      @app.call(env)
    end
  end
end

app = Rack::Builder.new do
  use Rack::Session::Cookie, key: 'rack.session', secret: 'super_secret_key'
  use LoggerMiddleware
  use ErrorHandlingMiddleware
  use AuthMiddleware
  use SessionMiddleware
  run Router.new
end

run app
