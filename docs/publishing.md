# Publishing

## First publish (bootstrap)

The first version must be published before trusted publishing can be configured.
Use a granular access token with publish rights, or `npm login`:

```bash
npm publish --access public
```

## Trusted publishing (recommended)

This repository uses npm trusted publishing with GitHub Actions OIDC.
No long-lived npm token is stored in the repository.

Configure it once, after the package exists:

```bash
npm trust github \
  --file publish.yml \
  --repo AquariusCZ/opencode-agent-doctrine \
  --allow-publish
```

Or use the npm web UI: package Settings -> Trusted publishing -> GitHub Actions,
with:

- Organization/user: `AquariusCZ`
- Repository: `opencode-agent-doctrine`
- Workflow filename: `publish.yml`
- Environment: leave empty
- Allowed actions: `npm publish`

The workflow uses:

```yaml
permissions:
  contents: read
  id-token: write
```

and runs `npm publish --access public --provenance`.

## Release process

1. Bump the version:
   ```bash
   npm version patch --no-git-tag-version
   ```
2. Update `CHANGELOG.md`.
3. Commit and push `main`.
4. Create a GitHub release (or run the `publish` workflow manually).
5. The workflow publishes to npm with provenance.

Do not commit an npm token. Trusted publishing uses a short-lived OIDC token.

## Token rotation

If a bootstrap token was used, revoke it after the first trusted-publishing
release succeeds. A token that bypasses 2FA is a long-lived secret and npm is
restricting those for direct publishing.
