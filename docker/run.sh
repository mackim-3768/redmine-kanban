#!/usr/bin/env bash
# Bring up Redmine 5.1.3 + plugin, load default data, seed dummy issues.
set -euo pipefail
export PATH="$PATH:/opt/podman/bin"
cd "$(dirname "$0")"
C=redmine-kanban-redmine-1

podman compose -f compose.yml up -d
echo "waiting for redmine..."
for i in $(seq 1 60); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3001/ || true)" = "200" ] && break
  sleep 5
done

# load default config data once (statuses, trackers, priorities, workflows)
if [ "$(podman exec -e RAILS_ENV=production "$C" bundle exec rails runner 'print IssueStatus.count' 2>/dev/null)" = "0" ]; then
  podman exec -e RAILS_ENV=production -e REDMINE_LANG=en "$C" bundle exec rake redmine:load_default_data
fi

podman cp seed.rb "$C:/tmp/seed.rb"
podman exec -e RAILS_ENV=production "$C" bundle exec rails runner /tmp/seed.rb

echo
echo "Redmine:  http://localhost:3001  (admin/admin)"
echo "Board:    http://localhost:3001/projects/kanban-demo/kanban"
