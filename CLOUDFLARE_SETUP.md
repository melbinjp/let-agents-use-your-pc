# Setting Up Cloudflare Tunnels for a Public Endpoint

This guide provides comprehensive instructions for exposing the agent's endpoint to the internet using Cloudflare Tunnels. This allows you to interact with the agent from anywhere, securely.

## Which Method Should I Use?

The options described in this guide apply when you are using the **VS Code Extension** to run the agent inside Docker.

-   **If you are using the VS Code Extension (Recommended for most users):**
    -   Choose **Method 1 (Permanent Tunnel)** if you have a Cloudflare account and want a stable, predictable URL for your agent.
    -   Choose **Method 2 (Temporary Tunnel)** if you want to get started as quickly as possible, without needing a Cloudflare account.

-   **If you are using the standalone installer scripts (`linux/install.sh`, `macos/install.sh`, etc.):**
    -   These scripts install the agent as a permanent, long-running service on your machine. They use an interactive `cloudflared login` flow that requires a Cloudflare account. For this reason, the temporary tunnel option has not been implemented for this workflow yet.

---

## Method 1: Permanent Tunnel (for the VS Code Extension)

This method provides you with a stable, named endpoint (e.g., `my-agent.trycloudflare.com`) that is tied to your Cloudflare account.

### Step 1: Log in to the Cloudflare Dashboard

1.  Navigate to the [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/).
2.  Log in with your Cloudflare account. If you don't have one, you'll need to sign up first.

### Step 2: Navigate to the Tunnels Section

1.  On the sidebar, go to **Networks** > **Tunnels**.

### Step 3: Create a New Tunnel

1.  Click the **Create a tunnel** button.
2.  You will be asked to choose a connector type. Select **Cloudflared** and click **Next**.
3.  Give your tunnel a descriptive name (e.g., `jules-dev-agent`) and click **Save tunnel**.

### Step 4: Copy Your Tunnel Token

1.  After saving the tunnel, you will be presented with a page showing commands to install the connector. You can ignore the installation steps, as the Docker setup handles that for you.
2.  **The crucial piece of information here is the tunnel token.** It's a long string of random characters shown in the command box.
3.  An example command looks like this: `cloudflared.exe service install eyJhIjoi...<your-token-is-here>...ZTQ2h3In0=`
4.  **Copy only the token part** (the long string of characters).

![Cloudflare Tunnel Token Location](https://i.imgur.com/your-image-placeholder.png)
*(Note: A placeholder image would go here showing where to find the token. For now, please refer to the text description.)*

### Step 5: Start the Agent with the Token

1.  In Visual Studio Code, run the command **"Jules: Start Agent"**.
2.  When prompted to choose a tunnel type, select **"Permanent Tunnel"**.
3.  When asked for your **Cloudflare Tunnel Token**, paste the token you copied from the dashboard.
4.  Provide a username and password for your agent.
5.  The agent will start, and the tunnel will be connected. You can now access your agent at the public URL associated with your tunnel (e.g., `https://your-tunnel-name.trycloudflare.com`). You can find this URL in your Cloudflare Tunnels dashboard.

---

## Method 2: Temporary "Quick" Tunnel (for the VS Code Extension)

This method is the fastest way to get started. It requires no setup in Cloudflare and is ideal for quick testing.

### Step 1: Start the Agent

1.  In Visual Studio Code, run the command **"Jules: Start Agent"**.
2.  When prompted to choose a tunnel type, select **"Temporary Tunnel"**.
3.  Provide a username and password for your agent.

### Step 2: Get Your Public URL

1.  The agent will start in a Docker container. In the background, it will automatically create a temporary, secure tunnel to the Cloudflare network.
2.  After a few moments (it can sometimes take up to 30 seconds), a notification will appear in VS Code with your unique, randomly generated public URL.
3.  The URL will look something like this: `https://some-random-words.trycloudflare.com`
4.  You can now use this URL to interact with the agent.

**Important:** This URL is temporary. If you stop and restart the agent, a new, different URL will be generated.
