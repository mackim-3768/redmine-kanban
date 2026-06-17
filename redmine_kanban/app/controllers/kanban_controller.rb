class KanbanController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize

  helper :issues
  helper :queries
  include QueriesHelper

  def show
    @trackers = @project.trackers.sorted
    @statuses = workflow_statuses

    # Defaults on first load (no filter submitted): tracker = all, assignee = me.
    # Once the filter form is submitted, params are present (empty string = "all").
    @selected_tracker = params.key?(:tracker_id) ? params[:tracker_id].to_s : ''
    @selected_assignee = if params.key?(:assigned_to_id)
                           params[:assigned_to_id].to_s
                         else
                           User.current.logged? ? User.current.id.to_s : ''
                         end

    scope = @project.issues.visible
                    .includes(:status, :tracker, :priority, :assigned_to, :fixed_version)
    scope = scope.where(tracker_id: @selected_tracker) if @selected_tracker.present?
    scope = scope.where(assigned_to_id: @selected_assignee) if @selected_assignee.present?

    @issues_by_status = Hash.new { |h, k| h[k] = [] }
    scope.find_each do |issue|
      @issues_by_status[issue.status_id] << issue
    end
    @issues_by_status.each_value do |list|
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
