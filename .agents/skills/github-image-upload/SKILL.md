---
name: github-image-upload
description: >-
  Upload local images and other files (PDF, zip, log, …) to GitHub and embed them
  in a pull request description, an issue, or a comment — producing canonical
  github.com/user-attachments URLs (private-repo uploads stay private). Use when
  asked to "attach a screenshot to the PR", "add an image to the PR description",
  "put this image in the issue", "attach this PDF/log/zip to the issue", "show test
  results in the PR", "embed before/after screenshots", or any request to visually
  document or attach files to changes on GitHub. Powered by the `gh-image` gh CLI
  extension.
license: MIT
---

# Upload images and files to GitHub (gh-image)

GitHub has **no public API** for attachment uploads — the web UI uses an internal
endpoint that mints `user-attachments` URLs scoped to the repo's visibility.
[`gh-image`](https://github.com/drogers0/gh-image) (MIT, © drogers0) replicates
that flow as a `gh` CLI extension, so you can upload images or other files (PDF,
zip, log, …) from the terminal and get a ready-to-paste reference back — an
`![name](url)` embed for images, a bare URL for videos (GitHub renders it as an
inline player), or a `[name](url)` download link for other files.

This skill drives `gh-image` and then embeds the result into a PR/issue/comment.

## Prerequisites — verify these before uploading

Run these checks; only act on the ones that fail.

1. **`gh` CLI installed & authenticated**

   ```bash
   gh auth status
   ```
   If it fails, tell the user to run `gh auth login` (do not attempt it unattended).

2. **The `gh-image` extension installed** (idempotent — skip if already present)

   ```bash
   gh extension list | grep -q 'drogers0/gh-image' || gh extension install drogers0/gh-image
   ```

3. **A GitHub session for the upload.** `gh-image` does NOT use the `gh` token for
   the upload (that endpoint rejects tokens); it needs the browser `user_session`
   cookie. Resolution order (first match wins):
   - `--token <value>` flag, or
   - `GH_SESSION_TOKEN` env var (use this in CI / headless), or
   - the cookie store of a logged-in browser (Chrome/Brave/Chromium/Edge/Firefox/
     Opera/Safari) — the default for local use. On macOS the first read may show a
     Keychain prompt; the user should click **Always Allow**.

   > ⚠️ A `user_session` cookie grants **full account access** (it is not scoped
   > like a PAT). Treat it like a password; in CI use a dedicated bot account.

## Step 1 — Normalize the file path

Use an **absolute path**. If a glob is given, resolve it first. Paths with spaces
or Unicode (e.g. CleanShot's narrow spaces) work, but quote them.

## Step 2 — Upload

```bash
# One or more files (images or PDF/zip/log/…); --repo is optional inside a repo
# working dir (inferred from the remote).
gh image "/abs/path/screenshot.png" --repo <owner>/<repo>
```

`gh image` prints the reference to **stdout** — an image embed for images, a bare
URL for videos (GitHub renders it as an inline player), and a download link for
other files, e.g.:

```
![screenshot.png](https://github.com/user-attachments/assets/<uuid>)
https://github.com/user-attachments/assets/<uuid>
[report.pdf](https://github.com/user-attachments/files/<id>/report.pdf)
```

Capture that output — it is the embeddable reference. For multiple files it prints
one line per file.

## Step 3 — Embed into the PR / issue / comment

`gh-image` only prints the markdown; you embed it. Pick the target the user asked for.

**Append to a PR description** (preserves the existing body):

```bash
MD="$(gh image "/abs/path/shot.png" --repo owner/repo)"
BODY="$(gh pr view <pr> --repo owner/repo --json body -q .body)"
printf '%s\n\n## Screenshots\n\n%s\n' "$BODY" "$MD" \
  | gh pr edit <pr> --repo owner/repo --body-file -
```

**Post as a new PR comment:**

```bash
MD="$(gh image "/abs/path/shot.png" --repo owner/repo)"
printf '## Screenshots\n\n%s\n' "$MD" | gh pr comment <pr> --repo owner/repo --body-file -
```

**Add to an issue body / comment:** same pattern with `gh issue edit <n> --body-file -`
or `gh issue comment <n> --body-file -`.

Always use `--body-file -` (not inline `--body`) so multi-line bodies and special
characters can't break shell quoting.

## Step 4 — Verify

```bash
gh pr view <pr> --repo owner/repo --json body -q .body   # confirm the URL is present
```

The `user-attachments` URL inherits the repo's visibility, so on a **private** repo
it renders only for authorized viewers (an anonymous fetch returns 404/403 — that is
expected, not a failure).

## Sizing (optional)

To control display size, embed an HTML tag instead of the bare markdown:

```html
<img width="800" alt="screenshot" src="https://github.com/user-attachments/assets/<uuid>" />
```

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `<org> enforces SAML SSO and your session is not authorized…` | The org requires SSO and your session isn't authorized. Open the `https://github.com/orgs/<org>/sso` URL from the message in a browser, authorize (lasts ~24h), then retry. Write access alone is not enough — this is not a permissions problem. |
| `uploadToken not found … do you have write access?` | The generic no-token case. Confirm you have write access; if the repo's org uses SSO, authorize at `https://github.com/orgs/<org>/sso` (the message includes this hint) and retry. |
| No `user_session` cookie found | Log into GitHub in a supported browser, or set `GH_SESSION_TOKEN`. |
| Windows + Chrome 127+ can't read cookies | Known cookie-library limitation — use another browser or `GH_SESSION_TOKEN`. |
| CI / headless run | Set `GH_SESSION_TOKEN` (dedicated bot account); the browser cookie path won't exist. |
| `gh: command not found` | Install the GitHub CLI (`brew install gh`, etc.). |
