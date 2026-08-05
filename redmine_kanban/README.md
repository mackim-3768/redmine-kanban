# Redmine Kanban

Notion/Trello-style Kanban board for Redmine **5.1.x** (tested on 5.1.3.stable, Rails 6.1, Ruby 3.2).

Each project gets a **Kanban** tab. Columns = issue statuses, cards = issues.
Drag a card to another column to change its status — the move is saved over AJAX
and recorded in the issue journal, respecting the tracker's workflow.

## Features

- Per-project board, columns ordered by issue-status position
- Current-week Close column plus read-only history columns for the previous four
  ISO weeks (for example, `31W Close`)
- HTML5 drag-and-drop (no external JS lib), optimistic UI with revert on failure
- Workflow-aware: only transitions allowed for the current user are accepted
- Status change writes a proper journal entry (`status_id: old -> new`)
- Filter by tracker and assignee; hide closed issues before the previous four weeks
  (enabled by default)
- Cards show tracker, id, subject, assignee, target version, due date (overdue
  highlighted), priority accent, and progress bar
- Permissions: `view_kanban` (read) and `manage_kanban` (move). Without
  `manage_kanban` the board is read-only.
- i18n: English + Korean

## Install

```bash
cp -r redmine_kanban <REDMINE>/plugins/redmine_kanban
cd <REDMINE>
bundle exec rake redmine:plugins:migrate RAILS_ENV=production   # no schema changes; mirrors assets
# restart Redmine
```

Then per project: **Settings → Modules → enable "Kanban"**, and grant the
`view_kanban` / `manage_kanban` permissions to the relevant roles
(**Administration → Roles and permissions**).

## Local test stack (Podman/Docker)

```bash
cd docker
podman compose -f compose.yml up -d          # Redmine 5.1.3 + Postgres 15 on :3001
# first boot only:
podman exec -e RAILS_ENV=production redmine-kanban-redmine-1 \
  bundle exec rake redmine:load_default_data REDMINE_LANG=en
podman exec -e RAILS_ENV=production redmine-kanban-redmine-1 \
  bundle exec rails runner /tmp/seed.rb       # dummy project + 12 issues
```

Open http://localhost:3001 (admin / admin). Board:
http://localhost:3001/projects/kanban-demo/kanban

## Files

| Path | Purpose |
|------|---------|
| `init.rb` | Plugin registration, project module, permissions, menu |
| `config/routes.rb` | `show` + `update_issue` routes |
| `app/controllers/kanban_controller.rb` | Board data + drag-drop status update |
| `app/views/kanban/show.html.erb` | Board layout + filters |
| `app/views/kanban/_card.html.erb` | Single issue card |
| `assets/javascripts/kanban.js` | Drag-and-drop + AJAX |
| `assets/stylesheets/kanban.css` | Board styling |
