# Cloudflare Tunnel Setup Guide

Cloudflare Tunnel provides a secure way to connect your local services to the internet without opening public inbound ports. It runs a lightweight daemon (`cloudflared`) on your machine that creates a secure, outbound-only connection to the Cloudflare network. This means you can expose your Jules Endpoint Agent to the internet without making it vulnerable to attacks on open ports.

This guide provides a comprehensive, step-by-step walkthrough for setting up a Cloudflare Tunnel for the Jules Endpoint Agent. The instructions are based on the latest official [Cloudflare Tunnels documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) and are designed to be easy to follow for both beginners and experienced users.

---

## 🛑 Security Warning

**This is extremely important.** By following this guide, you are creating a bridge between the public internet and a shell on your machine. The Jules Endpoint Agent is designed to execute arbitrary commands sent to it.

**Please follow these security best practices:**
- **Run this on a dedicated, sandboxed machine or VM.** Do not run it on your primary personal or work machine.
- **Always use the secure Cloudflare tunnel.** Never expose any ports directly.
- **Review the installation scripts before running them** to understand what they do.

---

## Choosing Your Setup Path

There are two ways to set up a Cloudflare Tunnel for the Jules Endpoint Agent. Please choose the one that best suits your needs:

### 1. Quick Tunnel (Temporary & No Account Needed)

- **Use this if:** You want to quickly test the agent or do not have a Cloudflare account or a custom domain.
- **How it works:** This method creates a temporary tunnel with a random public URL (e.g., `your-random-name.trycloudflare.com`). The tunnel is active only as long as the command is running.
- **Limitations:** The URL is not permanent, and you get less configuration flexibility.

### 2. Standard Tunnel (Permanent & Account Required)

- **Use this if:** You need a permanent, stable, and secure setup for regular use. This is the **recommended** method.
- **How it works:** This method creates a permanent tunnel linked to your Cloudflare account and a custom domain that you own. You can configure it to run as a service, so it starts automatically.
- **Prerequisites:** You will need a Cloudflare account and a registered domain.

---

## Path 1: Quick Tunnel Setup Guide

This guide will walk you through setting up a temporary tunnel. This is the fastest way to get started, but the tunnel will be disabled as soon as you stop the command.

### Step 1: Install `cloudflared`

First, you need to install the `cloudflared` command-line tool.

#### macOS

If you're on macOS, you can install `cloudflared` using [Homebrew](https://brew.sh/):

```bash
brew install cloudflared
```

#### Windows

On Windows, you can use [Winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) to install `cloudflared`:

```bash
winget install --id Cloudflare.cloudflared
```

#### Linux

For Debian-based distributions like Ubuntu, you can install `cloudflared` using `apt`:

```bash
# Add Cloudflare's package signing key
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

# Add Cloudflare's apt repo
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflared.list

# Update repositories and install
sudo apt-get update
sudo apt-get install cloudflared
```

For Red Hat-based distributions like CentOS or Fedora, you can use `yum` or `dnf`:

```bash
# Add Cloudflare's repository
curl -fsSL https://pkg.cloudflare.com/cloudflared-ascii.repo | sudo tee /etc/yum.repos.d/cloudflared.repo

# Update repositories and install
sudo yum update
sudo yum install cloudflared
# Or, if you are using dnf:
# sudo dnf update
# sudo dnf install cloudflared
```

For other operating systems, please refer to the official [Cloudflare downloads page](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/).

### Step 2: Start the Tunnel

Once `cloudflared` is installed, you can start a tunnel by running the following command. This command assumes that the Jules Endpoint Agent is running and listening on port `8080`. If you have configured the agent to use a different port, please change the port in the command below.

```bash
cloudflared tunnel --url http://localhost:8080
```

### Step 3: Get Your Public URL

After running the command, `cloudflared` will print a public URL that now points to your local agent. The output will look something like this:

```
2023-10-27T18:44:54Z INF Thank you for trying Cloudflare Tunnel. Your free tunnel has been created!
2023-10-27T18:44:54Z INF Your tunnel's public URL is: https://your-random-name.trycloudflare.com
```

You can now use this URL to access your Jules Endpoint Agent from anywhere. The tunnel will remain active as long as you keep the `cloudflared tunnel` command running. To stop the tunnel, simply press `Ctrl+C` in the terminal.

---

## Path 2: Standard Tunnel Setup Guide

This guide will walk you through setting up a permanent, production-ready tunnel. This is the recommended method for regular use, as it provides a stable public URL and can be configured to run as a service.

### Prerequisites

Before you begin, make sure you have:

1.  **A Cloudflare Account:** If you don't have one, you can sign up for free at [dash.cloudflare.com](https://dash.cloudflare.com).
2.  **A Registered Domain:** You will need a domain name (e.g., `example.com`) that you own.
3.  **Your Domain Added to Cloudflare:** Follow this [guide to add your website to Cloudflare](https://developers.cloudflare.com/fundamentals/manage-domains/add-site/).

### Step 1: Install `cloudflared`

If you haven't already installed `cloudflared` in the "Quick Tunnel" guide, please follow the instructions in [Step 1 of the Quick Tunnel Setup Guide](#step-1-install-cloudflared).

### Step 2: Log In to Cloudflare

Next, you need to authenticate `cloudflared` with your Cloudflare account. Run the following command:

```bash
cloudflared tunnel login
```

This will open a browser window asking you to log in to your Cloudflare account. After you log in, you'll be asked to authorize the tunnel for one of your domains. Choose the domain you want to use for the Jules Endpoint Agent.

This will create a `cert.pem` file in the default `cloudflared` directory (usually `~/.cloudflared/` on Linux/macOS or `C:\Users\<YourUser>\.cloudflared` on Windows).

### Step 3: Create a Tunnel

Now, create a tunnel and give it a name. Choose a descriptive name, for example, `jules-agent`.

```bash
cloudflared tunnel create jules-agent
```

This command will output the tunnel's UUID and the path to its credentials file. **Make sure to copy the UUID and the credentials file path**, as you will need them in the next step.

You can verify that the tunnel was created by running:

```bash
cloudflared tunnel list
```

### Step 4: Create a Configuration File

Next, you need to create a configuration file to tell `cloudflared` how to route traffic to your agent.

1.  Navigate to the `cloudflared` directory.
2.  Create a new file named `config.yml`.
3.  Add the following content to the `config.yml` file, replacing `<TUNNEL_UUID>` with the UUID from the previous step:

```yaml
tunnel: <TUNNEL_UUID>
credentials-file: /path/to/your/credentials/file.json # e.g., /root/.cloudflared/<TUNNEL_UUID>.json
ingress:
  - hostname: jules.your-domain.com
    service: http://localhost:8080
  - service: http_status:404
```

**Important:**
- Replace `<TUNNEL_UUID>` with your tunnel's UUID.
- Make sure the `credentials-file` path is correct.
- Change `jules.your-domain.com` to the hostname you want to use.
- The `service: http://localhost:8080` line assumes your agent is running on port 8080. Change this if needed.
- The final `service: http_status:404` is a catch-all rule that prevents the tunnel from exposing other services.

### Step 5: Create a DNS Record

Now, you need to create a DNS CNAME record to route traffic from your chosen hostname to the tunnel.

Replace `jules-agent` with your tunnel's name and `jules.your-domain.com` with your chosen hostname.

```bash
cloudflared tunnel route dns jules-agent jules.your-domain.com
```

### Step 6: Run the Tunnel

Finally, you can run the tunnel:

```bash
cloudflared tunnel run jules-agent
```

If you named your configuration file something other than `config.yml` or placed it in a different directory, you can specify its path with the `--config` flag:

```bash
cloudflared tunnel --config /path/to/your/config.yml run jules-agent
```

You should now be able to access your Jules Endpoint Agent at the hostname you configured (e.g., `https://jules.your-domain.com`).

---

## Optional: Running the Tunnel as a Service

To ensure your tunnel is always running, you can install `cloudflared` as a system service. This will automatically start the tunnel on boot.

### Linux

On Linux, you can manage the `cloudflared` service using `systemd`.

1.  **Install the service:**

    ```bash
    sudo cloudflared service install
    ```

2.  **Start the service:**

    ```bash
    sudo systemctl start cloudflared
    ```

3.  **Check the status of the service:**

    ```bash
    sudo systemctl status cloudflared
    ```

4.  **Enable the service to start on boot:**

    ```bash
    sudo systemctl enable cloudflared
    ```

### macOS

On macOS, `cloudflared` can be managed as a Launch Agent.

1.  **Install the service:**

    ```bash
    sudo cloudflared service install
    ```

2.  **Start the service:**

    ```bash
    launchctl start com.cloudflare.cloudflared
    ```

3.  **Check the status of the service:**

    ```bash
    launchctl list | grep com.cloudflare.cloudflared
    ```

### Windows

On Windows, you can manage the `cloudflared` service from the command line or the Services app.

1.  **Install the service (run in an administrator PowerShell or Command Prompt):**

    ```powershell
    cloudflared.exe service install
    ```

2.  **Start the service:**

    ```powershell
    sc.exe start cloudflared
    ```

3.  **Check the status of the service:**

    ```powershell
    sc.exe query cloudflared
    ```

By running the tunnel as a service, your Jules Endpoint Agent will remain accessible as long as your machine is running.
