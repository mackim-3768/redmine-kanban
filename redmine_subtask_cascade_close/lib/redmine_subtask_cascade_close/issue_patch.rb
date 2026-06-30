module RedmineSubtaskCascadeClose
  # File name issue_patch.rb must define IssuePatch (zeitwerk convention).
  module IssuePatch
    # Prepended: lets a parent be closed even when it still has open subtasks.
    # The descendants are then closed automatically by the cascade callback.
    module Closable
      def closable?
        if blocked?
          @transition_warning = l(:notice_issue_not_closable_by_blocking_issue)
          return false
        end
        true
      end
    end

    module Cascade
      def self.included(base)
        base.after_save :cascade_close_open_subtasks
      end

      # When this issue moves to a closed status, close its still-open direct
      # children with the same status. Each child save recurses, so whole
      # subtrees close. Parent/child is acyclic, so recursion terminates.
      def cascade_close_open_subtasks
        return unless saved_change_to_status_id?
        return unless status&.is_closed?

        closed_ids = IssueStatus.where(is_closed: true).pluck(:id)
        open_children = Issue.where(parent_id: id).where.not(status_id: closed_ids).to_a
        return if open_children.empty?

        target = status_id
        open_children.each do |child|
          child.init_journal(User.current, "Auto-closed: parent ##{id} closed (cascade)")
          child.status_id = target
          child.save(validate: false)
        end
      end
    end
  end
end
