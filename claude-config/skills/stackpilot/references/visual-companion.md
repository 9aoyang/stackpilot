# Visual Companion

> Historical reference for browser companion behavior. The sprint server
> (`scripts/preview/server.cjs` + `references/views/` HTML templates) owns current
> browser views. Node 2 (Design) uses it only when the design decision needs
> visual layout, interaction, or diagram evidence.

Browser-based design visualization for design discussion phases. Use when a design question would be understood better visually than textually.

## When to Use

- **Use browser**: UI mockups, wireframes, layout comparisons, interactive prototypes, nontrivial architecture diagrams, dense dashboards, visual verification evidence
- **Use terminal**: requirements, conceptual choices, tradeoff lists, scope decisions, technical decisions, simple A/B/C approvals

Decide **per question**. Do NOT send a separate permission-seeking message; if the browser is eligible, start visual inline with the design question. If the content is prose, keep it terminal-only.

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
