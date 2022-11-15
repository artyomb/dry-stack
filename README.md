# Dry-stack

This gem allows ...  

```
cat simple_stack.drs | dry-stack -e to_compose | docker stack deploy -c - simple_stack

$ dry-stack
Version: 0.0.16
Usage:
	dry-stack -s stackfile [options] COMMAND
	cat stackfile | dry-stack COMMAND
	dry-stack COMMAND < stack.drs

Commands:
     to_compose -  Print stack in docker compose format

Options:
    -s, --stack STACK_NAME           Stack file
    -e, --env                        Load .env file
        --name STACK_NAME
                                     Define stack name
        --ingress
                                     Generate ingress labels
        --traefik
                                     Generate traefik labels
        --traefik_tls
                                     Generate traefik tls labels
    -n, --no-env                     Do not process env variables
    -h, --help

```

https://rdoc.info/gems/dry-stack
https://rubydoc.info/gems/dry-stack
https://gemdocs.org/gems/dry-stack/

## Installation
To install the gem

    $ gem install dry-stack

## Usage
Create the file `stack.drs` which describes the stack
```ruby
PublishPorts admin: 5000
Ingress admin: { host: 'admin.*' }
Deploy admin: { replica: 2, 'resources.limits': { cpus: '4', memory: '500M' } }

Service :admin,     image: 'frontend', env: {APP: 'admin'},     ports: 5000

Service :backend,   image: 'backend', ports: 3000 do
  env APP_PORT: 3000, NODE_ENV: 'development', SKIP_GZ: true, DB_URL: '$DB_URL'
end


```
Then run in the current directory

    $ dry-stack stack.drs -n --traefik to_compose

This will ...

```yaml
version: '3.8'
services:
  admin:
    environment:
      APP: admin
    image: frontend
    ports:
    - 5000:5000
    deploy:
      labels:
      - traefik.enable=true
      - traefik.http.routers.stack_admin.service=stack_admin
      - traefik.http.services.stack_admin.loadbalancer.server.port=5000
      - traefik.http.routers.stack_admin.rule=HostRegexp(`{name:admin\..*}`)
      replica: 2
      resources:
        limits:
          cpus: '4'
          memory: 500M
    networks:
    - default
    - ingress_routing
  backend:
    environment:
      APP_PORT: 3000
      NODE_ENV: development
      SKIP_GZ: true
      DB_URL: "$DB_URL"
    image: backend
networks:
  ingress_routing:
    external: true
    name: ingress-routing

```
