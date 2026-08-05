class KanbanController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize

  helper :issues
  helper :queries
  include QueriesHelper

  def show
    @trackers = @project.trackers.sorted
    @recent_close_weeks = RedmineKanban::WeeklyCloseColumns.recent_weeks(Time.zone.today)
    @columns = add_recent_close_columns(build_columns)

    # Defaults on first load (no filter submitted): tracker = all, assignee = me.
    # Once the filter form is submitted, params are present (empty string = "all").
    @selected_tracker = params.key?(:tracker_id) ? params[:tracker_id].to_s : ''
    @selected_assignee = if params.key?(:assigned_to_id)
                           params[:assigned_to_id].to_s
                         else
                           User.current.logged? ? User.current.id.to_s : ''
                         end
    @hide_old_closed = params.fetch(:hide_old_closed, '1').to_s != '0'

    scope = @project.issues.visible
                    .includes(:status, :tracker, :priority, :assigned_to, :fixed_version)
    scope = scope.where(tracker_id: @selected_tracker) if @selected_tracker.present?
    scope = scope.where(assigned_to_id: @selected_assignee) if @selected_assignee.present?
    scope = hide_old_closed_issues(scope) if @hide_old_closed

    # Map each status id to the column that owns it.
    status_to_col = {}
    @columns.each { |c| c[:status_ids].each { |sid| status_to_col[sid] ||= c[:key] } }

    @issues_by_column = Hash.new { |h, k| h[k] = [] }
    unmapped = []
    scope.find_each do |issue|
      key = recent_close_column_key(issue) || status_to_col[issue.status_id]
      key ? (@issues_by_column[key] << issue) : (unmapped << issue)
    end

    # Never lose issues: statuses not covered by the column map fall into a
    # read-only "Other" column (no commit target, so it is not a drop zone).
    if unmapped.any?
      @columns << { key: 'other', name: l(:label_kanban_other), status_ids: [], commit_id: nil }
      @issues_by_column['other'] = unmapped
    end

    @issues_by_column.each_value do |list|
      list.sort_by! { |i| [-(i.priority.try(:position) || 0), i.id] }
    end

    # Dropdown must always contain "me" and anyone already assigned, even if the
    # project has no explicit members (assignable_users would be empty then).
    users = @project.assignable_users.to_a
    assigned_ids = @project.issues.where.not(assigned_to_id: nil).distinct.pluck(:assigned_to_id)
    users |= User.where(id: assigned_ids).to_a
    users |= [User.current] if User.current.logged?
    @assignee_options = users.uniq.sort_by { |u| u.name.to_s.downcase }
  end

  def update_issue
    @issue = @project.issues.visible.find(params[:id])
    unless @issue.editable?(User.current)
      return render json: { error: l(:notice_not_authorized) }, status: :forbidden
    end

    new_status_id = params[:status_id].to_i
    if new_status_id > 0 && @issue.status_id != new_status_id
      new_status = IssueStatus.find_by(id: new_status_id)
      allowed = @issue.new_statuses_allowed_to(User.current).map(&:id)
      unless allowed.include?(new_status_id)
        return render json: { error: l(:error_status_not_allowed) }, status: :unprocessable_entity
      end
      @issue.init_journal(User.current)
      @issue.status = new_status
    end

    if @issue.save
      render json: {
        ok: true,
        id: @issue.id,
        status_id: @issue.status_id,
        done_ratio: @issue.done_ratio
      }
    else
      render json: { error: @issue.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  private

  # Keep open issues, the current week, and the previous four completed weeks.
  # Closed issues without a closed_on value remain visible because their age is
  # unknown.
  def hide_old_closed_issues(scope)
    return scope if closed_status_ids.empty?

    scope.where(
      'issues.status_id NOT IN (:closed_status_ids) ' \
      'OR issues.closed_on IS NULL OR issues.closed_on >= :cutoff',
      closed_status_ids: closed_status_ids,
      cutoff: @recent_close_weeks.last[:start_on]
    )
  end

  # Insert four read-only history columns immediately after the last configured
  # column that contains a closed status. The original closed column remains a
  # drop target and holds issues closed during the current week.
  def add_recent_close_columns(columns)
    close_index = columns.rindex do |column|
      (column[:status_ids] & closed_status_ids).any?
    end
    return columns unless close_index

    history_columns = @recent_close_weeks.map do |week|
      {
        key: week[:key],
        name: l(:label_kanban_week_close, week: format('%02d', week[:week])),
        status_ids: [],
        commit_id: nil
      }
    end
    @recent_close_columns_enabled = true
    columns.insert(close_index + 1, *history_columns)
  end

  def recent_close_column_key(issue)
    return unless @recent_close_columns_enabled
    return unless closed_status_ids.include?(issue.status_id)

    RedmineKanban::WeeklyCloseColumns.key_for(issue.closed_on, @recent_close_weeks)
  end

  def closed_status_ids
    @closed_status_ids ||= IssueStatus.where(is_closed: true).pluck(:id)
  end

  # Build the board columns. Without a configured column_map, every workflow
  # status becomes its own column (original behaviour). With a column_map, the
  # listed statuses are grouped into the named buckets; dropping a card into a
  # bucket sets the issue to that bucket's `commit_to` status.
  #
  # Each column: { key:, name:, status_ids: [Integer], commit_id: Integer|nil }
  def build_columns
    raw = Setting.plugin_redmine_kanban['column_map'].to_s.strip
    return per_status_columns(workflow_statuses) if raw.empty?

    parsed = begin
      YAML.safe_load(raw)
    rescue => e
      Rails.logger.warn("redmine_kanban: invalid column_map YAML: #{e.message}")
      nil
    end
    unless parsed.is_a?(Array)
      flash.now[:warning] = 'Kanban: column_map is not valid YAML; falling back to one column per status.'
      return per_status_columns(workflow_statuses)
    end

    by_name = IssueStatus.all.index_by { |s| s.name.to_s.downcase }
    cols = []
    parsed.each_with_index do |c, i|
      next unless c.is_a?(Hash)
      sids = Array(c['statuses']).map { |n| by_name[n.to_s.strip.downcase]&.id }.compact.uniq
      commit = by_name[c['commit_to'].to_s.strip.downcase]&.id || sids.first
      next unless commit
      cols << { key: "c#{i}", name: c['name'].to_s.presence || "Column #{i + 1}",
                status_ids: sids, commit_id: commit }
    end
    cols.presence || per_status_columns(workflow_statuses)
  end

  def per_status_columns(statuses)
    statuses.map { |s| { key: "s#{s.id}", name: s.name, status_ids: [s.id], commit_id: s.id } }
  end

  # Statuses to render as columns: union of statuses used by project trackers'
  # workflows plus statuses already present on issues, ordered by position.
  def workflow_statuses
    ids = WorkflowTransition.where(tracker_id: @project.trackers.ids)
                            .pluck(:old_status_id, :new_status_id).flatten.uniq
    ids += @project.issues.distinct.pluck(:status_id)
    ids = ids.compact.uniq
    statuses = IssueStatus.where(id: ids).order(:position).to_a
    statuses = IssueStatus.sorted.to_a if statuses.empty?
    statuses
  end
end
