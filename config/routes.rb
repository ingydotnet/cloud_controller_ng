Rails.application.routes.draw do
  # apps
  get '/apps', to: 'apps_v3#index',
    summary: 'List all apps'
  post '/apps', to: 'apps_v3#create',
    summary: 'Create a new app'
  get '/apps/:guid', to: 'apps_v3#show',
    summary: 'Get an app'
  put '/apps/:guid', to: 'apps_v3#update',
    summary: 'Update an app'
  patch '/apps/:guid', to: 'apps_v3#update',
    summary: 'Patch an app'
  delete '/apps/:guid', to: 'apps_v3#destroy',
    summary: 'Destroy an app'
  put '/apps/:guid/start', to: 'apps_v3#start',
    summary: 'Start an app'
  put '/apps/:guid/stop', to: 'apps_v3#stop',
    summary: 'Stop an app'
  get '/apps/:guid/env', to: 'apps_v3#show_environment',
    summary: 'Get an app environment'
  put '/apps/:guid/droplets/current', to: 'apps_v3#assign_current_droplet',
    summary: 'Set current droplet for app'
  get '/apps/:guid/droplets/current', to: 'apps_v3#current_droplet',
    summary: 'Get current droplet'

  # processes
  get '/processes', to: 'processes#index',
    summary: 'List all processes'
  get '/processes/:process_guid', to: 'processes#show',
    summary: 'Get a process'
  patch '/processes/:process_guid', to: 'processes#update',
    summary: 'Patch a process'
  delete '/processes/:process_guid/instances/:index', to: 'processes#terminate',
    summary: 'Terminate a process'
  put '/processes/:process_guid/scale', to: 'processes#scale',
    summary: 'Scale a process'
  get '/processes/:process_guid/stats', to: 'processes#stats',
    summary: 'Get process statistics'
  get '/apps/:app_guid/processes', to: 'processes#index',
    summary: 'List all processes for an app'
  get '/apps/:app_guid/processes/:type', to: 'processes#show',
    summary: 'Show process for an app'
  put '/apps/:app_guid/processes/:type/scale', to: 'processes#scale',
    summary: 'Update scale for app process'
  delete '/apps/:app_guid/processes/:type/instances/:index', to: 'processes#terminate',
    summary: 'Terminate process instance for an app'
  get '/apps/:app_guid/processes/:type/stats', to: 'processes#stats',
    summary: 'Get process statistics for an app'

  # packages
  get '/packages', to: 'packages#index',
    summary: 'List all packages'
  get '/packages/:guid', to: 'packages#show',
    summary: 'Show a package'
  post '/packages/:guid/upload', to: 'packages#upload',
    summary: 'Upload a package'
  get '/packages/:guid/download', to: 'packages#download',
    summary: 'Download a package'
  delete '/packages/:guid', to: 'packages#destroy',
    summary: 'Destroy a package'
  get '/apps/:app_guid/packages', to: 'packages#index',
    summary: 'List all packages for an app'
  post '/apps/:app_guid/packages', to: 'packages#create',
    summary: 'Create a new package for an app'

  # droplets
  post '/packages/:package_guid/droplets', to: 'droplets#create',
    summary: 'Create a new droplet for a package'
  post '/droplets/:guid/copy', to: 'droplets#copy',
    summary: 'Copy a droplet'
  get '/droplets', to: 'droplets#index',
    summary: 'List all droplets'
  get '/droplets/:guid', to: 'droplets#show',
    summary: 'Show a droplet'
  delete '/droplets/:guid', to: 'droplets#destroy',
    summary: 'Destroy a droplet'
  get '/apps/:app_guid/droplets', to: 'droplets#index',
    summary: 'List droplets for an app'
  get '/packages/:package_guid/droplets', to: 'droplets#index',
    summary: 'List droplets for a package'

  # route_mappings
  post '/route_mappings', to: 'route_mappings#create',
    summary: 'Create a new route mapping'
  get '/route_mappings', to: 'route_mappings#index',
    summary: 'List all route mappings'
  get '/route_mappings/:route_mapping_guid', to: 'route_mappings#show',
    summary: 'Show a route mapping'
  delete '/route_mappings/:route_mapping_guid', to: 'route_mappings#destroy',
    summary: 'Destroy a route mapping'
  get '/apps/:app_guid/route_mappings', to: 'route_mappings#index',
    summary: 'List all route mappings for an app'

  # tasks
  get '/tasks', to: 'tasks#index',
    summary: 'List all tasks'
  get '/tasks/:task_guid', to: 'tasks#show',
    summary: 'Show a task'
  put '/tasks/:task_guid/cancel', to: 'tasks#cancel',
    summary: 'Cancel a task'

  post '/apps/:app_guid/tasks', to: 'tasks#create',
    summary: 'Create a new task for an app'
  get '/apps/:app_guid/tasks', to: 'tasks#index',
    summary: 'List all tasks for an app'

  # service_bindings
  post '/service_bindings', to: 'service_bindings#create',
    summary: 'Create a new service binding'
  get '/service_bindings/:guid', to: 'service_bindings#show',
    summary: 'Show a service binding'
  get '/service_bindings', to: 'service_bindings#index',
    summary: 'List all service bindings'
  delete '/service_bindings/:guid', to: 'service_bindings#destroy',
    summary: 'Destroy a service binding'

  # openapi
  get '/openapi', to: 'openapi#show',
    summary: 'Show the openapi spec'

  # errors
  match '404', to: 'errors#not_found', via: :all
  match '500', to: 'errors#internal_error', via: :all
  match '400', to: 'errors#bad_request', via: :all
end
