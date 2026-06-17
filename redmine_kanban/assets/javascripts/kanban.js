(function () {
  'use strict';

  function csrfToken() {
    var el = document.querySelector('meta[name="csrf-token"]');
    return el ? el.getAttribute('content') : '';
  }

  function init() {
    var board = document.querySelector('.kanban-board');
    if (!board) return;

    initPanel(board);

    if (board.getAttribute('data-can-manage') === 'true') {
      initDragDrop(board);
    }
  }

  /* ---------------- Notion-style side panel ---------------- */

  function initPanel(board) {
    var panel = document.getElementById('kanban-panel');
    var backdrop = document.getElementById('kanban-panel-backdrop');
    if (!panel) return;

    var frame = panel.querySelector('.kb-panel-frame');
    var titleEl = panel.querySelector('.kb-panel-title');
    var openEl = panel.querySelector('.kb-panel-open');
    var closeBtn = panel.querySelector('.kb-panel-close');
    var loading = panel.querySelector('.kb-panel-loading');
    var resizer = panel.querySelector('.kb-panel-resizer');
    var base = board.getAttribute('data-issue-base') || '';

    function urlFor(id) { return base.replace('__ID__', id); }

    function open(issueId, subject) {
      var url = urlFor(issueId);
      titleEl.textContent = '#' + issueId + (subject ? '  ' + subject : '');
      openEl.setAttribute('href', url);
      loading.style.display = 'block';
      frame.style.visibility = 'hidden';
      frame.setAttribute('src', url);
      panel.classList.add('open');
      panel.setAttribute('aria-hidden', 'false');
      backdrop.hidden = false;
      document.body.classList.add('kb-panel-active');
    }

    function close() {
      panel.classList.remove('open');
      panel.setAttribute('aria-hidden', 'true');
      backdrop.hidden = true;
      document.body.classList.remove('kb-panel-active');
      frame.setAttribute('src', 'about:blank');
    }

    // strip Redmine chrome inside the iframe (same-origin)
    frame.addEventListener('load', function () {
      loading.style.display = 'none';
      frame.style.visibility = 'visible';
      try {
        var doc = frame.contentDocument;
        if (!doc) return;
        if (frame.getAttribute('src') === 'about:blank') return;
        var css = doc.createElement('style');
        css.textContent =
          '#top-menu,#header,#main-menu,#sidebar,#footer,#wrapper2>.flyout-menu{display:none!important}' +
          '#main{margin:0!important;padding:0!important;background:#fff!important}' +
          '#content{margin:0!important;width:auto!important;padding:16px 22px!important;' +
          'box-shadow:none!important;border:0!important;min-height:auto!important}' +
          'body{background:#fff!important}';
        doc.head.appendChild(css);
      } catch (e) { /* cross-origin or blocked: leave full page */ }
    });

    board.addEventListener('click', function (e) {
      var card = e.target.closest('.kanban-card');
      if (!card) return;
      // let modified clicks / middle-click open a new tab normally
      if (e.metaKey || e.ctrlKey || e.shiftKey || e.button === 1) return;
      e.preventDefault();
      var subjEl = card.querySelector('.kb-subject a');
      open(card.getAttribute('data-issue-id'), subjEl ? subjEl.textContent.trim() : '');
    });

    closeBtn.addEventListener('click', close);
    backdrop.addEventListener('click', close);
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && panel.classList.contains('open')) close();
    });

    // resize by dragging the left handle
    var resizing = false;
    function applyWidth(px) {
      var min = 340, max = window.innerWidth * 0.92;
      px = Math.max(min, Math.min(max, px));
      panel.style.width = px + 'px';
    }
    resizer.addEventListener('mousedown', function (e) {
      resizing = true;
      document.body.classList.add('kb-resizing');
      e.preventDefault();
    });
    document.addEventListener('mousemove', function (e) {
      if (!resizing) return;
      applyWidth(window.innerWidth - e.clientX);
    });
    document.addEventListener('mouseup', function () {
      if (resizing) {
        resizing = false;
        document.body.classList.remove('kb-resizing');
        try { localStorage.setItem('kbPanelWidth', parseInt(panel.style.width, 10)); } catch (e) {}
      }
    });
    try {
      var saved = parseInt(localStorage.getItem('kbPanelWidth'), 10);
      if (saved) applyWidth(saved);
    } catch (e) {}
  }

  /* ---------------- drag & drop ---------------- */

  function initDragDrop(board) {
    var updateUrl = board.getAttribute('data-update-url');
    var dragged = null;

    board.addEventListener('dragstart', function (e) {
      var card = e.target.closest('.kanban-card');
      if (!card) return;
      dragged = card;
      card.classList.add('dragging');
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/plain', card.getAttribute('data-issue-id'));
    });

    board.addEventListener('dragend', function () {
      if (dragged) dragged.classList.remove('dragging');
      dragged = null;
      board.querySelectorAll('.kanban-column.drop-target')
           .forEach(function (c) { c.classList.remove('drop-target'); });
    });

    board.querySelectorAll('.kanban-column').forEach(function (col) {
      var body = col.querySelector('.kanban-column-body');

      col.addEventListener('dragover', function (e) {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        col.classList.add('drop-target');
        var after = elementAfter(body, e.clientY);
        if (dragged) {
          if (after == null) body.appendChild(dragged);
          else body.insertBefore(dragged, after);
        }
      });

      col.addEventListener('dragleave', function (e) {
        if (!col.contains(e.relatedTarget)) col.classList.remove('drop-target');
      });

      col.addEventListener('drop', function (e) {
        e.preventDefault();
        col.classList.remove('drop-target');
        if (!dragged) return;
        var newStatus = col.getAttribute('data-status-id');
        var oldStatus = dragged.getAttribute('data-status-id');
        if (newStatus === oldStatus) return;
        commit(dragged, newStatus, oldStatus);
      });
    });

    function elementAfter(container, y) {
      var cards = Array.prototype.slice.call(
        container.querySelectorAll('.kanban-card:not(.dragging)')
      );
      var closest = { offset: -Infinity, el: null };
      cards.forEach(function (card) {
        var box = card.getBoundingClientRect();
        var offset = y - box.top - box.height / 2;
        if (offset < 0 && offset > closest.offset) {
          closest = { offset: offset, el: card };
        }
      });
      return closest.el;
    }

    function commit(card, newStatus, oldStatus) {
      var issueId = card.getAttribute('data-issue-id');
      card.classList.add('saving');
      var data = new URLSearchParams();
      data.append('id', issueId);
      data.append('status_id', newStatus);

      fetch(updateUrl, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrfToken(),
          'X-Requested-With': 'XMLHttpRequest',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        credentials: 'same-origin',
        body: data.toString()
      })
        .then(function (r) { return r.json().then(function (j) { return { ok: r.ok, body: j }; }); })
        .then(function (res) {
          card.classList.remove('saving');
          if (res.ok && res.body.ok) {
            card.setAttribute('data-status-id', newStatus);
            recount();
          } else {
            revert(card, oldStatus);
            alert((res.body && res.body.error) || 'Update failed');
          }
        })
        .catch(function () {
          card.classList.remove('saving');
          revert(card, oldStatus);
          alert('Network error');
        });
    }

    function revert(card, oldStatus) {
      var origin = board.querySelector('.kanban-column[data-status-id="' + oldStatus + '"] .kanban-column-body');
      if (origin) origin.appendChild(card);
      recount();
    }

    function recount() {
      board.querySelectorAll('.kanban-column').forEach(function (col) {
        var n = col.querySelectorAll('.kanban-card').length;
        var badge = col.querySelector('.kb-col-count');
        if (badge) badge.textContent = n;
      });
    }
  }

  document.addEventListener('DOMContentLoaded', init);
})();
