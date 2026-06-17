RedmineApp::Application.routes.draw do
  get 'projects/:project_id/kanban', to: 'kanban#show', as: 'project_kanban'
  post 'projects/:project_id/kanban/update_issue', to: 'kanban#update_issue', as: 'project_kanban_update_issue'
end
