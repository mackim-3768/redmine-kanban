require 'redmine'
require_relative 'lib/redmine_kanban/weekly_close_columns'

Redmine::Plugin.register :redmine_kanban do
  name 'Redmine Kanban'
  author 'dgkim'
  description 'Notion-style Kanban board for Redmine projects. Drag-and-drop issues across status columns.'
  version '0.2.0'
  url 'https://github.com/dgkim/redmine_kanban'
  author_url 'https://github.com/dgkim'

  requires_redmine version_or_higher: '5.0.0'

  # Optional status -> column grouping. Empty = one column per status.
  settings default: { 'column_map' => '' },
           partial: 'settings/redmine_kanban'

  project_module :kanban do
    permission :view_kanban, { kanban: [:show] }, read: true
    permission :manage_kanban, { kanban: [:update_issue] }
  end

  menu :project_menu, :kanban,
       { controller: 'kanban', action: 'show' },
       caption: :label_kanban,
       param: :project_id,
       after: :activity,
       html: { class: 'icon icon-issue' }
end
