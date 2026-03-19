# dev-browser

Browser automation with persistent page state via Playwright. Navigate websites, fill forms, take screenshots, extract web data, test web apps, and automate browser workflows.

## Skills

| Skill | Trigger | Description |
|---|---|---|
| **dev-browser** | "go to [url]", "click on", "take a screenshot", "scrape" | Full browser automation with persistent named pages |

## Setup

### Standalone Mode (Default)

Launches a new Chromium browser:

```bash
${CLAUDE_PLUGIN_ROOT}/server.sh &
```

Wait for the `Ready` message before running scripts. Add `--headless` for headless mode.

### Extension Mode

Connects to your existing Chrome browser (useful for authenticated sessions):

```bash
cd ${CLAUDE_PLUGIN_ROOT} && npm i && npm run start-extension &
```

Wait for `Extension connected` in the console.

## Writing Scripts

Run scripts from the plugin root using heredocs:

```bash
cd ${CLAUDE_PLUGIN_ROOT} && npx tsx <<'EOF'
import { connect, waitForPageLoad } from "@/client.js";

const client = await connect();
const page = await client.page("my-page");
await page.goto("https://example.com");
await waitForPageLoad(page);

console.log({ title: await page.title(), url: page.url() });
await client.disconnect();
EOF
```

## Key APIs

| Method | Description |
|---|---|
| `client.page("name")` | Create or reconnect to a named page |
| `client.getAISnapshot("name")` | Get ARIA accessibility tree for element discovery |
| `client.selectSnapshotRef("name", "e5")` | Get element by snapshot reference |
| `page.goto(url)` | Navigate to URL |
| `page.screenshot()` | Capture screenshot |
| `waitForPageLoad(page)` | Wait for network idle |

## Approach

- **Local/source-available sites**: Read source code first, write selectors directly
- **Unknown layouts**: Use `getAISnapshot()` to discover elements
- **Visual feedback**: Take screenshots to see what the user sees

## License

MIT
