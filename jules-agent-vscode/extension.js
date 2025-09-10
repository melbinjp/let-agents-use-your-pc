const vscode = require('vscode');
const cp = require('child_process');
const path = require('path');
const util = require('util');

const exec = util.promisify(cp.exec);

const DOCKER_IMAGE_NAME = 'jules-agent-image';
const DOCKER_CONTAINER_NAME = 'jules-agent';

/**
 * A helper function to execute a shell command and show output in an output channel.
 * @param {string} command The command to execute.
 * @param {vscode.OutputChannel} outputChannel The channel to show output in.
 */
async function executeCommand(command, outputChannel) {
	outputChannel.appendLine(`> ${command}`);
	try {
		const { stdout, stderr } = await exec(command);
		if (stderr) {
			outputChannel.appendLine(`stderr: ${stderr}`);
		}
		outputChannel.appendLine(`stdout: ${stdout}`);
		return { stdout, stderr, success: true };
	} catch (error) {
		outputChannel.appendLine(`Error executing command: ${error.message}`);
		outputChannel.show();
		vscode.window.showErrorMessage(`Failed to execute: ${command}. See the output channel for details.`);
		return { error, success: false };
	}
}

/**
 * @param {vscode.ExtensionContext} context
 */
async function activate(context) {
	console.log('Jules Agent extension is now active.');

	const outputChannel = vscode.window.createOutputChannel("Jules Agent");

	// Command to start the agent
	let startDisposable = vscode.commands.registerCommand('jules.agent.start', async function () {
		vscode.window.withProgress({
			location: vscode.ProgressLocation.Notification,
			title: "Starting Jules Agent",
			cancellable: false
		}, async (progress) => {
			try {
				progress.report({ message: "Checking for Docker..." });
				// 1. Check if Docker is running
				await exec('docker info');
			} catch (error) {
				vscode.window.showErrorMessage('Docker does not appear to be running. Please start Docker and try again.');
				return;
			}

			// 2. Ask user for tunnel type
			progress.report({ message: "Waiting for user input..." });
			const tunnelType = await vscode.window.showQuickPick(
				[
					{ label: 'Permanent Tunnel', description: 'Use a pre-configured Cloudflare Tunnel with a token.' },
					{ label: 'Temporary Tunnel', description: 'Create a new temporary tunnel. No account needed.' }
				],
				{
					placeHolder: 'Choose a Cloudflare Tunnel type',
					ignoreFocusOut: true
				}
			);

			if (!tunnelType) {
				vscode.window.showInformationMessage('Jules Agent startup cancelled.');
				return;
			}

			let cloudflareToken = '';
			if (tunnelType.label === 'Permanent Tunnel') {
				cloudflareToken = await vscode.window.showInputBox({
					prompt: 'Enter your Cloudflare Tunnel Token',
					password: true,
					ignoreFocusOut: true,
					placeHolder: 'Paste your token here'
				});
				if (!cloudflareToken) {
					vscode.window.showInformationMessage('Jules Agent startup cancelled.');
					return;
				}
			}

			const julesUsername = await vscode.window.showInputBox({
				prompt: 'Enter a username for the agent',
				ignoreFocusOut: true,
				placeHolder: 'e.g., jules'
			});
			if (!julesUsername) {
				vscode.window.showInformationMessage('Jules Agent startup cancelled.');
				return;
			}

			const julesPassword = await vscode.window.showInputBox({
				prompt: 'Enter a password for the agent',
				password: true,
				ignoreFocusOut: true,
				placeHolder: 'Enter a strong password'
			});
			if (!julesPassword) {
				vscode.window.showInformationMessage('Jules Agent startup cancelled.');
				return;
			}

            outputChannel.clear();
            outputChannel.show(true); // true to preserve focus
			outputChannel.appendLine("Starting Jules Agent setup...");

			// 3. Stop and remove existing container to avoid conflicts
			progress.report({ increment: 10, message: "Cleaning up old containers..." });
            outputChannel.appendLine("Checking for existing containers...");
			const { stdout: existingContainer } = await exec(`docker ps -q -f name=${DOCKER_CONTAINER_NAME}`);
			if (existingContainer) {
				outputChannel.appendLine(`Found existing container. Stopping and removing...`);
				await executeCommand(`docker stop ${DOCKER_CONTAINER_NAME}`, outputChannel);
				await executeCommand(`docker rm ${DOCKER_CONTAINER_NAME}`, outputChannel);
			}

			// 4. Build the Docker image
			progress.report({ increment: 30, message: "Building Docker image..." });
            const assetsPath = path.join(context.extensionPath, 'assets');
			const buildResult = await executeCommand(`docker build -t ${DOCKER_IMAGE_NAME} "${assetsPath}"`, outputChannel);
            if (!buildResult.success) {
                vscode.window.showErrorMessage('Failed to build Docker image. See "Jules Agent" output for details.');
                return;
            }

			// 5. Run the Docker container
			progress.report({ increment: 50, message: "Starting agent container..." });
			let runCommand = `docker run -d --name ${DOCKER_CONTAINER_NAME} --restart unless-stopped -p 8080:8080 -e JULES_USERNAME="${julesUsername}" -e JULES_PASSWORD="${julesPassword}"`;
			if (cloudflareToken) {
				runCommand += ` -e CLOUDFLARE_TOKEN="${cloudflareToken}"`;
			}
			runCommand += ` ${DOCKER_IMAGE_NAME}`;

            const runResult = await executeCommand(runCommand, outputChannel);
            if (!runResult.success) {
                vscode.window.showErrorMessage('Failed to start Docker container. See "Jules Agent" output for details.');
                return;
            }

			// 6. Handle tunnel URL
			if (tunnelType.label === 'Temporary Tunnel') {
				progress.report({ increment: 10, message: "Waiting for temporary tunnel URL..." });
				outputChannel.appendLine("Waiting for temporary tunnel URL... This can take up to 30 seconds.");

				// Poll logs for the URL
				let tunnelUrl = '';
				const startTime = Date.now();
				while (Date.now() - startTime < 30000 && !tunnelUrl) { // 30 second timeout
					await new Promise(resolve => setTimeout(resolve, 2000)); // wait 2s between checks
					const logResult = await executeCommand(`docker logs ${DOCKER_CONTAINER_NAME}`, outputChannel);
					if (logResult.success) {
						const urlMatch = logResult.stdout.match(/(https?:\/\/[a-zA-Z0-9-]+\.trycloudflare\.com)/);
						if (urlMatch) {
							tunnelUrl = urlMatch[0];
						}
					}
				}

				if (tunnelUrl) {
					vscode.window.showInformationMessage(`Jules Agent is running at: ${tunnelUrl}`);
				} else {
					vscode.window.showWarningMessage('Could not determine temporary tunnel URL. Please check the logs manually.');
				}
			} else {
				progress.report({ increment: 10, message: "Agent started successfully!" });
				vscode.window.showInformationMessage('Jules Agent started successfully! Your tunnel should be available at your configured Cloudflare address.');
			}
		});
	});

	// Command to stop the agent
	let stopDisposable = vscode.commands.registerCommand('jules.agent.stop', async function () {
        outputChannel.clear();
        outputChannel.show(true);
        outputChannel.appendLine("Stopping Jules Agent...");

		const stopResult = await executeCommand(`docker stop ${DOCKER_CONTAINER_NAME}`, outputChannel);
        if (!stopResult.success && !stopResult.error.message.includes('No such container')) {
            vscode.window.showErrorMessage('Failed to stop the agent. See "Jules Agent" output for details.');
            return;
        }

        const rmResult = await executeCommand(`docker rm ${DOCKER_CONTAINER_NAME}`, outputChannel);
        if (!rmResult.success && !rmResult.error.message.includes('No such container')) {
            vscode.window.showErrorMessage('Failed to remove the agent container. See "Jules Agent" output for details.');
            return;
        }

		vscode.window.showInformationMessage('Jules Agent stopped and removed successfully.');
	});

	// Command to view logs
	let logsDisposable = vscode.commands.registerCommand('jules.agent.logs', function () {
		const terminal = vscode.window.createTerminal("Jules Agent Logs");
		terminal.sendText(`docker logs -f ${DOCKER_CONTAINER_NAME}`);
		terminal.show();
	});

	context.subscriptions.push(startDisposable, stopDisposable, logsDisposable);
}

function deactivate() {
    // Here we could attempt to stop the container if the extension is deactivated,
    // but it's better to let the user manage it explicitly or rely on the --restart policy.
}

module.exports = {
	activate,
	deactivate
}
