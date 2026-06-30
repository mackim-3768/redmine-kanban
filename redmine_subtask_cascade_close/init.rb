require 'redmine'

Redmine::Plugin.register :redmine_subtask_cascade_close do
  name 'Subtask Cascade Close'
  author 'dgkim'
  description 'Allow closing a parent issue with open subtasks; closes the open subtasks automatically (cascade).'
  version '0.1.0'
  requires_redmine version_or_higher: '5.0.0'
end

# Apply the patch immediately. Referencing Issue triggers zeitwerk autoload of
# the model and the patch module; prepend/include are idempotent.
unless Issue.included_modules.include?(RedmineSubtaskCascadeClose::IssuePatch::Cascade)
  Issue.include(RedmineSubtaskCascadeClose::IssuePatch::Cascade)
end
unless Issue.ancestors.include?(RedmineSubtaskCascadeClose::IssuePatch::Closable)
  Issue.prepend(RedmineSubtaskCascadeClose::IssuePatch::Closable)
end
