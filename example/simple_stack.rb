require 'dry-stack'
include Dry

Stack :simple_stack do

  HttpFront services: {admin: 'admin.*', backend: 'admin.*, operator.*'}

  PublishPorts admin: 4000, operator: 4001, backend: 3000

  Service :admin,     image: 'frontend', env: {APP: 'admin'},     ports: 5000
  Service :operator,  image: 'frontend', env: {APP: 'operator'},  ports: 5000

  Service :backend,   image: 'backend', ports: 3000 do
    env APP_PORT: 3000, NODE_ENV: 'development', SKIP_GZ: true, DB_URL: '$DB_URL'
  end

  Network :default, attachable: true
end

puts Stack.last_stack.to_compose

