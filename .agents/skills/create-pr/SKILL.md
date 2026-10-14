---
name: create-pr
description: Open a pull request on rubyevents/rubyevents from the current branch. Use when asked to create, open, or update a pull request, or to add screenshots to one.
metadata:
  opencode/slash: "true"
---

# Workflow

- [ ] Check `gh auth status` and fix auth before anything else. Without it `gh pr create` fails and no amount of retrying helps.
- [ ] Check `git status`. Commit the work first, and leave unrelated untracked files alone.
- [ ] Push the branch: `git push -u origin <branch>`.
- [ ] Find the real base. This repo will probably be a fork, so `origin/main` is often stale. Use `git log --oneline upstream/main..HEAD` to see only your commits.
- [ ] Write the PR body to a file outside the repo, for example `/tmp/pr-body.md`. Writing it inside the repo dirties the tree.
- [ ] Create the PR as a draft.
- [ ] Attach screenshots, if there are any.
- [ ] Verify what GitHub actually stored.

## The template

The template lives at `.github/pull_request_template.md` (all lowercase). Read it every time and keep
its section headings and order.

You can copy the template into a /tmp/ directory and edit the pull request body there - good for lots of edits.

```bash

## Opening as a draft

Target the upstream repo, not the fork:

```bash
gh pr create --draft \
  --repo rubyevents/rubyevents \
  --base main \
  --head <owner>:<branch> \
  --title "Short imperative title" \
  --body-file /tmp/pr-body.md
```

Leave it as a draft unless the human asks for it to be marked ready.

## Screenshots

Ask for the screenshot file inside the repo (`tmp/` is gitignored) or ask them to drag and drop it into the terminal.

Copy it into the repo under a plain filename first, and reference that exact path in the body:

```bash
cp /rails/tmp/Screenshot*.png ./tmp/shot.png
```

```markdown
![what the screenshot shows](./tmp/shot.png)
```

Then upload and rewrite the reference in one step:

```bash
gh pr edit <number> \
  --repo rubyevents/rubyevents \
  --body-file /tmp/pr-body.md \
  --attach "./tmp/shot.png#alt text after the hash"
```

`--attach` takes up to 50 files. The text after `#` becomes the alt text; without it the filename is
used.

## Verifying

```bash
gh pr view <number> --repo rubyevents/rubyevents --json state,isDraft,baseRefName,headRefName,url
gh pr diff <number> --repo rubyevents/rubyevents --name-only
gh pr view <number> --repo rubyevents/rubyevents --json body -q .body
```

Check that the body has the image under `## Screenshots` and that no image was appended to the
bottom.

# Gotchas

- **`--attach` only rewrites a reference that matches the path you attach.** If the body says `./tmp/shot.png` and you attach `./tmp/screenshot.png`, the reference stays a dead relative link and `gh` appends the upload to the end of the body instead. Match them exactly, then verify.
- **If it already went wrong**, the uploaded asset has a real URL. Find it in the appended line, use
  it in the section where you want the image, and drop the appended line.
- **`gh pr edit` without a body flag keeps the existing body**, which is handy for a follow-up tweak.
- **Screenshots are GitHub-hosted, not committed.** Nothing is added to the repo, so leave the working tree clean afterwards.