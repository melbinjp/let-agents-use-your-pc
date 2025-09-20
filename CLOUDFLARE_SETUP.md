# Setting Up a Public SSH Endpoint with Cloudflare Tunnel

This guide provides a complete walkthrough for exposing the Docker-based agent to the internet, allowing secure SSH access from anywhere.

The process involves two main stages:
1.  **Server-Side Setup:** Creating a Cloudflare Tunnel and configuring the agent to use it.
2.  **Client-Side Setup:** Configuring your local machine to connect to the agent through the tunnel.

---

## Part 1: Server-Side Setup (Creating the Tunnel)

### Step 1: Create a Cloudflare Account and Add a Domain

1.  If you don't already have one, sign up for a [Cloudflare account](https://dash.cloudflare.com/sign-up).
2.  You must have a domain name registered to your account. You can either purchase one through Cloudflare or transfer an existing one.

### Step 2: Create a Cloudflare Tunnel

1.  Navigate to the [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/).
2.  On the sidebar, go to **Access** > **Tunnels**.
3.  Click the **Create a tunnel** button.
4.  You will be asked to choose a connector type. Select **Cloudflared** and click **Next**.
5.  Give your tunnel a descriptive name (e.g., `jules-agent-ssh`) and click **Save tunnel**.

### Step 3: Copy Your Tunnel Token

1.  After saving the tunnel, Cloudflare will show you commands to install the connector. You can **ignore these commands**, as our Docker setup handles the installation for you.
2.  The crucial piece of information on this page is the **tunnel token**. It's a long string of random characters shown in the command box.
    - An example command looks like this: `cloudflared.exe service install eyJhIjoi...<your-token-is-here>...ZTQ2h3In0=`
3.  **Copy only the token part** (the long string of characters) and save it somewhere safe. You will need it in a moment.

### Step 4: Configure a Public Hostname for the Tunnel

1.  On the same page, click **Next** to proceed to the **Public Hostnames** configuration.
2.  Click **Add a public hostname**.
3.  Configure the hostname as follows:
    - **Subdomain:** Choose a name for your SSH connection (e.g., `agent` or `ssh`).
    - **Domain:** Select your domain from the dropdown list.
    - **Service Type:** `SSH`
    - **URL:** `localhost:22`
4.  Click **Save hostname**. You have now told Cloudflare to route SSH traffic for `agent.your-domain.com` to port 22 on your future agent.

### Step 5: Configure and Run the Agent

1.  Navigate to the `docker/` directory in this repository.
2.  Open the `docker-compose.yml` file in a text editor.
3.  Find the `CLOUDFLARE_TOKEN` environment variable and paste the token you copied in Step 3.
4.  From your terminal, inside the `docker/` directory, run the agent:
    ```bash
    docker compose up --build -d
    ```
    *(Note: Your system may use the older `docker-compose` command instead of `docker compose`)*.

The agent is now running inside a Docker container and has created a secure tunnel to the Cloudflare network.

---

## Part 2: Client-Side Setup (Connecting to the Agent)

### Step 6: Install `cloudflared` on Your Local Machine

To connect to the tunnel, you also need the `cloudflared` tool on your own computer (e.g., your laptop).
-   Follow the official **[Cloudflare installation instructions](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/)** to install it on your operating system.

### Step 7: Configure Your Local SSH Client

1.  Open your local SSH configuration file. This is usually located at `~/.ssh/config`. If it doesn't exist, you can create it.
2.  Add the following block to the file, replacing `agent.your-domain.com` with the public hostname you configured in Step 4.

    ```
    Host agent.your-domain.com
        ProxyCommand /path/to/your/cloudflared access ssh --hostname %h
    ```
    *(**Important:** Replace `/path/to/your/cloudflared` with the actual path to the `cloudflared` executable on your machine. You can find this by running `which cloudflared` on macOS/Linux).*

### Step 8: Connect!

You can now connect to the agent with a standard SSH command:

```bash
ssh jules@agent.your-domain.com
```

-   The username is `jules`.
-   The password is `jules`.

You are now connected to the agent running inside the Docker container on your remote machine!
