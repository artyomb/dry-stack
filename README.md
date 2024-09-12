# Dry-stack

This gem allows ...  

```
cat simple_stack.drs | dry-stack -e to_compose | docker stack deploy -c - simple_stack

$ dry-stack
Version: 0.1.16
Usage:
	dry-stack -s stackfile [options] COMMAND
	cat stackfile | dry-stack COMMAND
	dry-stack COMMAND < stack.drs

Commands:
     to_compose -  Print stack in docker compose format
                   [... to_compose <deploy name>] 
     swarm_deploy -  Call docker stack deploy & add config readme w/ description
                     [... swarm_deploy -- --prune  --resolve-image changed]

Options:
    -s, --stack STACK_NAME           Stack file
    -e, --env                        Load .env file
        --name STACK_NAME
                                     Define stack name
        --ingress
                                     Generate ingress labels
        --traefik
                                     Generate traefik labels
        --traefik-tls
                                     Generate traefik tls labels
        --tls-domain domain
                                     Domain for the traefik labels
        --host-sed /from/to/
                                     Sed ingress host  /\*/dev.*/
    -n, --no-env                     Deprecated
    -c, --configuration name         Configuration name
    -x, --context-endpoint host      Docker context host. Created if not exists
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
Description <<~DSC
  Stack description
DSC

Labels 'stack.product': 'product A'

PublishPorts admin: 5000
Ingress admin: { host: 'admin.*' }
Deploy admin: { replica: 2, 'resources.limits': { cpus: '4', memory: '500M' } }

Service :admin,     image: 'frontend', env: {APP: 'admin'},     ports: 5000

Service :backend,   image: 'backend', ports: 3000 do
  env APP_PORT: 3000, NODE_ENV: 'development', SKIP_GZ: true, DB_URL: '$DB_URL'
  volume 'database:/var/lib/postgresql/data'
end

Volume :database, driver: 'zfs', name: 'tank/volume1', driver_opts: { compression: 'lz4', dedup: 'on' }


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
      STACK_NAME: stack
      STACK_SERVICE_NAME: admin
    deploy:
      labels:
      - stack.product=product A
      - traefik.enable=true
      - traefik.http.routers.stack_admin-0.service=stack_admin-0
      - traefik.http.services.stack_admin-0.loadbalancer.server.port=5000
      - traefik.http.routers.stack_admin-0.rule=HostRegexp(`{name:admin\..*}`)
      replica: 2
      resources:
        limits:
          cpus: '4'
          memory: 500M
    networks:
      default:
      ingress_routing:
    image: frontend
    ports:
    - 5000:5000
  backend:
    environment:
      APP_PORT: 3000
      NODE_ENV: development
      SKIP_GZ: 'true'
      DB_URL: "$DB_URL"
      STACK_NAME: stack
      STACK_SERVICE_NAME: backend
    deploy:
      labels:
      - stack.product=product A
    image: backend
    volumes:
    - database:/var/lib/postgresql/data
volumes:
  database:
    driver: zfs
    name: tank/volume1
    driver_opts:
      compression: lz4
      dedup: 'on'
networks:
  ingress_routing:
    external: true
    name: ingress-routing

```
