# Visual Companion

> **DEPRECATED in v2.0** — folded into the sprint server (`scripts/preview/server.cjs`
> + `references/views/` HTML templates). Node 2 (Design) in SKILL.md now starts the
> sprint server itself and renders `design-options.html` via the same infrastructure.
> This file is kept one release for back-compat; will be removed in v2.1.

Browser-based design visualization for design discussion phases. Use when a design question would be understood better visually than textually.

## When to Use

- **Use browser**: UI mockups, wireframes, layout comparisons, architecture diagrams, side-by-side visual designs
- **Use terminal**: requirements, conceptual choices, tradeoff lists, scope decisions, technical decisions

Decide **per question**. Do NOT send a separate permission-seeking message — start visual inline with the design question.

## Server Setup

```bash
# Start preview server (HTML goes to /tmp, auto-cleaned when server stops)
bash ~/Documents/github/stackpilot/scripts/preview/start-server.sh

# Returns JSON: {"port":52341,"url":"http://localhost:52341","screen_dir":"/tmp/brainstorm-.../content","state_dir":"/tmp/brainstorm-.../state"}
# Save screen_dir, state_dir, and the full session_dir from the response
```

## Visual Loop

1. Write HTML content fragment to a new file in `screen_dir` (semantic name like `layout.html`, never reuse names)
2. Tell user what's on screen, remind them of the URL, ask for feedback
3. On next turn, read `$STATE_DIR/events` for browser click data (JSON lines), merge with terminal text
4. Iterate (e.g. `layout-v2.html`) or advance to next question
5. When returning to terminal questions, push a waiting screen to clear stale content

## HTML Content Fragments

Write content only, server auto-wraps in frame template:

```html
<!-- Available CSS classes: .options, .cards, .mockup, .split, .pros-cons -->
<!-- Mock elements: .mock-nav, .mock-sidebar, .mock-content, .mock-button, .mock-input -->
<h2>Which layout works better?</h2>
<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content"><h3>Single Column</h3><p>Clean, focused reading</p></div>
  </div>
  <div class="option" data-choice="b" onclick="toggleSelect(this)">
    <div class="letter">B</div>
    <div class="content"><h3>Two Column</h3><p>Sidebar + main content</p></div>
  </div>
</div>
```

## Stop Server

After design is finalized:
```bash
bash ~/Documents/github/stackpilot/scripts/preview/stop-server.sh $SESSION_DIR
```
