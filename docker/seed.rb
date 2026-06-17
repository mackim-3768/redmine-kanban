# Seed dummy project + issues for Kanban verification
admin = User.find_by_login('admin')
User.current = admin

Setting.rest_api_enabled = '1'

identifier = 'kanban-demo'
project = Project.find_by_identifier(identifier)
unless project
  project = Project.new(name: 'Kanban Demo', identifier: identifier,
                        description: 'Dummy project for Kanban plugin verification')
  project.trackers = Tracker.all
  project.save!
end

# enable modules incl. kanban
mods = (project.enabled_module_names | %w[issue_tracking kanban])
project.enabled_module_names = mods
project.trackers = Tracker.all if project.trackers.empty?
project.save!

statuses = IssueStatus.sorted.to_a
trackers = Tracker.all.to_a
prio = IssuePriority.active.to_a

subjects = [
  'Set up CI pipeline', 'Fix login redirect bug', 'Design Kanban card layout',
  'Write API documentation', 'Refactor auth middleware', 'Add dark mode',
  'Optimize DB queries', 'User onboarding flow', 'Email notification bug',
  'Upgrade to Rails 7', 'Add export to CSV', 'Mobile responsive board'
]

if project.issues.count < subjects.size
  subjects.each_with_index do |subj, i|
    issue = Issue.new(
      project: project,
      tracker: trackers[i % trackers.size],
      subject: subj,
      description: "Auto-generated dummy issue ##{i + 1}",
      status: statuses[i % statuses.size],
      priority: prio[i % prio.size],
      author: admin,
      assigned_to: (i.even? ? admin : nil),
      done_ratio: (i * 7) % 100
    )
    issue.save!
  end
end

puts "PROJECT=#{project.identifier} ISSUES=#{project.issues.count} STATUSES=#{statuses.map(&:name).join(',')}"
puts "MODULES=#{project.enabled_module_names.sort.join(',')}"
