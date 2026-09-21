# Multiplayer delivery plan

## Public endpoint

- Competitive PvP remains dedicated-server-only: client UDP reaches
  `lobby.joeyslime.com:443`, where the reverse proxy forwards it privately to
  the arena server on UDP 5999. Friends co-op remains Steam-hosted and uses
  Steam networking relays rather than this public endpoint.

## 1. Steam friends co-op

- Create a friends-only Steam lobby for the host.
- Open Steam's invite overlay once the lobby exists.
- Join accepted Steam invites through `SteamMultiplayerPeer`, including Steam relay fallback.
- Keep co-op peer-to-peer; it does not depend on the public PvP server or a router port-forward.

## 2. Shared game state

- Use one replicated arena scene for both Steam co-op and dedicated PvP.
- Spawn and despawn every player consistently on every peer.
- Synchronize movement, facing, animation state, attacks, Hero Form, damage, death, respawn and interactable state.
- Make the host/server validate PvP damage before broadcasting it to the victim.

## 3. Dedicated PvP server

- Replace the current per-player solo game stub with a persistent shared arena on UDP 5999.
- Deploy it as a service on `marc-a2` and verify the process, port and two-client match flow.
- Keep the HTTP reverse proxy out of game traffic; ENet is UDP, not HTTP.

## 4. Daily item API and Steam transfers

- Trace `api.joeyslime.com` daily-item scheduling/cache behavior and fix automatic daily refresh.
- Identify players by Steam ID/persona lookup for transfers instead of a manually copied UUID.
- Require an in-game Steam friend relationship and server-side ownership checks before a transfer.
- Test item receipt, duplicate protection and failure recovery.

## 5. Release verification

- Run a local host plus joined Steam client test on this Mac, covering movement, combat, Hero Form, interactions and an item transfer.
- Run a dedicated-server PvP test with two clients.
- Push to `dev`, fast-forward `main`, push both branches, build Windows/Linux/macOS, then upload the tested build to Steam.
