# Notes for AI agents

Compositor is a macOS image editor for compositing and photo work, written in Swift (SwiftUI and AppKit, with some C for pixel work).

## Read this first: another agent is working in this repository

**More than one AI works on this checkout at the same time.** Read [SYNC.md](SYNC.md) before
touching anything, and update it before you stop. It is the coordination board: who is editing
what right now, what has been verified and how, which traps are already known, and which
decisions the user has already made so you do not ask twice.

The four rules that keep two agents from destroying each other's work:

1. `git fetch origin && git status` first. Read SYNC.md's "正在做" and "待对方回答" sections.
2. **Register what you are about to edit** in SYNC.md before you edit it. Two agents editing one
   file is a guaranteed conflict.
3. **Push often.** Uncommitted work is invisible to the other agent. Never `checkout`, `reset` or
   `stash` over changes you did not make.
4. Before stopping: move your claim to "刚完成", add anything you verified to "已核实的事实",
   and leave questions for the other agent in "待对方回答".

## Assigned work

[TASKS.md](TASKS.md) is the work queue, written by whichever agent is reviewing. Claim a task in
SYNC.md before starting it, do one at a time, and meet the definition of done in TASKS.md section 0
before calling it finished — that section also lists what the reviewer will check independently.

## Project status

- [STATUS.md](STATUS.md) is the long-form history: what has been built, what was verified, what
  remains. Read it for context; check its claims against the code when they matter.
- Before finishing, update `STATUS.md` with actual progress, validation results, remaining issues,
  and next steps. Keep completed work distinct from plans and unverified claims.

## Designing or editing a Compositor project

If you've been asked to make or change an image in a `.comp` project, you don't need the app's source code. Read [docs/writing-comp-files.md](docs/writing-comp-files.md): it covers the file format, the rules that make a project load, and how to write it safely while it's open, so the person can watch the canvas update as you work.

## Working on the app itself

- Build: open `Compositor.xcodeproj` and run the **Compositor** scheme, or `xcodebuild -project Compositor.xcodeproj -scheme Compositor -destination 'platform=macOS' build`.
- Tests: the `CompositorTests` target (`xcodebuild ... test -only-testing:CompositorTests`). CI runs these on every push.
- Match the surrounding code: its naming, its comment style and density.
- American spelling in code, comments and UI ("color", not "colour").
- The project file format is described in [docs/project-format.md](docs/project-format.md). A change to what's saved means a format version bump there and in `ProjectManifest.current`.
