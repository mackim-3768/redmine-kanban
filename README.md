# Redmine Kanban

A Notion / Trello-style Kanban board plugin for **Redmine 5.1.x** (tested on
`5.1.3.stable` — Rails 6.1, Ruby 3.2, PostgreSQL).

Each project gains a **Kanban** tab. Columns are issue statuses, cards are
issues. Drag a card to another column to change its status — the move is saved
over AJAX, validated against the tracker's workflow, and recorded in the issue
journal. Click a card to open a resizable side panel that renders the full issue
inline.

```
┌──────────┬──────────────┬───────────┬──────────┐        ┌───────────────────────┐
│   New    │ In Progress  │ Resolved  │  Closed  │  ⇠drag │  #12  Mobile board    │ ✕
├──────────┼──────────────┼───────────┼──────────┤        │  Status: In Progress  │
│ ▌ #1     │ ▌ #4         │ ▌ #7      │ ▌ #11    │        │  Assignee: …          │
│ ▌ #2     │ ▌ #5         │           │          │        │  ───────────────────  │
│ ▌ #3     │ ▌ #6  ◀──────┼───────────┘          │        │  Description, history │
└──────────┴──────────────┴───────────┴──────────┘        └───────────────────────┘
         board (status columns)                                resizable side panel
```

## Features

- **Per-project board** — columns are issue statuses, ordered by status position
- **Drag-and-drop** status changes (native HTML5, no JS dependency); optimistic
  UI with automatic revert on failure
- **Workflow-aware** — only transitions allowed for the current user are accepted;
  every move writes a proper journal entry (`status_id: old -> new`)
- **Notion-style side panel** — click a card to open a resizable right-side panel
  (drag the left edge; width is remembered). Renders the issue in a same-origin
  `iframe` with Redmine's header/menu/sidebar/footer stripped, so editing and
  commenting work inline. `⤢` opens the full page in a new tab.
- **Smart default filters** — tracker defaults to *all*, assignee defaults to the
  *current user*, and closed issues older than two weeks are hidden by default;
  all are adjustable. The assignee list always includes you plus anyone already
  assigned, even when the project has no formal members.
- **Rich cards** — tracker, id, subject, assignee, target version, due date
  (overdue highlighted), priority accent, progress bar
- **Permissions** — `view_kanban` (read) and `manage_kanban` (move). Without
  `manage_kanban` the board is read-only but the side panel still opens.
- **i18n** — English and Korean

## Requirements

- Redmine **5.0.0+** (developed and verified on 5.1.3.stable)
- No database migrations — the plugin adds no tables

## Install

```bash
cp -r redmine_kanban <REDMINE_ROOT>/plugins/redmine_kanban
cd <REDMINE_ROOT>
bundle exec rake redmine:plugins:migrate RAILS_ENV=production   # mirrors plugin assets
# restart Redmine
```

Then, per project:

1. **Settings → Modules** → enable **Kanban**
2. **Administration → Roles and permissions** → grant `view_kanban` /
   `manage_kanban` to the relevant roles

Open the project's **Kanban** tab.

## Try it with Docker / Podman

A throwaway stack (Redmine 5.1.3 + Postgres 15) lives in `docker/`:

```bash
cd docker
./run.sh          # brings up the stack on :3001, loads default data, seeds dummy issues
```

Then open <http://localhost:3001> (login `admin` / `admin`) and visit the
**Kanban Demo** project's board:
<http://localhost:3001/projects/kanban-demo/kanban>

`run.sh` uses `podman compose` (it falls back to `docker compose` transparently).
Note: the official Redmine image ships **without** default configuration data, so
`run.sh` runs `rake redmine:load_default_data` on first boot to create statuses,
trackers, priorities, and workflows before seeding.

## Layout

| Path | Purpose |
|------|---------|
| `redmine_kanban/init.rb` | Plugin registration, project module, permissions, menu |
| `redmine_kanban/config/routes.rb` | `show` + `update_issue` routes |
| `redmine_kanban/app/controllers/kanban_controller.rb` | Board data + drag-drop status update |
| `redmine_kanban/app/views/kanban/show.html.erb` | Board layout, filters, side panel |
| `redmine_kanban/app/views/kanban/_card.html.erb` | Single issue card |
| `redmine_kanban/assets/javascripts/kanban.js` | Drag-and-drop, AJAX, side panel |
| `redmine_kanban/assets/stylesheets/kanban.css` | Board + panel styling |
| `redmine_kanban/config/locales/{en,ko}.yml` | Translations |
| `docker/` | Local test stack (`compose.yml`, `run.sh`, `seed.rb`) |

## Known limitations (MVP)

- Card order **within** a column is not persisted (resets on reload)
- No swimlanes
- No WIP limits

## License

GPL-2.0 (same as Redmine).
