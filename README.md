# Dry-stack

This gem allows ...  

```
cat simple_stack.drs | dry-stack -e to_compose | docker stack deploy -c - simple_stack

$ dry-stack
Usage:
        dry-stack -s stackfile [options] COMMAND
        cat stackfile | dry-stack COMMAND
        dry-stack COMMAND < stack.drs

Commands:
     to_compose -  Print stack in docker compose format

Options:
    -s, --stack STACK_NAME           Stack file
    -e, --env                        Load .env file
        --name STACK_NAME            Define stack name
        --ingress                    Generate ingress labels
        --traefik                    Generate traefik labels
        --traefik_tls                Generate traefik tls labels
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
HttpFront services: {admin: 'admin.*', operator: 'operator.*', reports: 'reports.*',
                   navigator: 'navigator.*', backend: 'admin.*, operator.*, navigator.*'}

PublishPorts admin: 4000, operator: 4001, navigator: 4002, reports: 7000 # mode: ingress, protocol: tcp

Service :admin,     image: 'frontend', env: {APP: 'admin'},     ports: 5000
Service :operator,  image: 'frontend', env: {APP: 'operator'},  ports: 5000
Service :navigator, image: 'frontend', env: {APP: 'navigator'}, ports: 5000

Service :backend,   image: 'backend', ports: 3000 do
  env APP_PORT: 3000, NODE_ENV: 'development', SKIP_GZ: true, DB_URL: '$DB_URL'
end

Service :reports, image: 'reports:0.1', env: {DB_URL: '$DB_URL'}, ports: 7000

Network :default, attachable: true

```
Then run in the current directory

    $ dry-stack stack.drs -e to_compose

This will ...

```yaml
---
name: :simple_stack
services:
  admin:
    environment:
      APP: admin
    image: frontend
    ports:
      - 4000:5000
  operator:
    environment:
      APP: operator
    image: frontend
    ports:
      - 4001:5000
  navigator:
    environment:
      APP: navigator
    image: frontend
    ports:
      - 4002:5000
  backend:
    environment:
      APP_PORT: 3000
      NODE_ENV: development
      SKIP_GZ: true
      DB_URL: "$DB_URL"
    image: backend
  reports:
    environment:
      DB_URL: "$DB_URL"
    image: reports:0.1
    ports:
      - 7000:7000
networks:
  default:
    attachable: true
```
