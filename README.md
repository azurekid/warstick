# WarStick

Portable, local-first AI tooling designed to run from a removable drive on macOS, Linux, and Windows. WarStick combines a terminal command console, a browser interface, local GGUF inference, optional image generation, and extensible tactical modules without sending prompts to a hosted model API.

<p align="center">
	<img width="1024" height="559" alt="WarStick command console" src="https://github.com/user-attachments/assets/0bebecf3-b4c6-4320-9e61-eeb84d824494" />
</p>

> [!IMPORTANT]
> WarStick can generate and execute system commands. Use it only on systems and networks you own or are explicitly authorized to test, and review commands before execution.

## Features

- **Runs locally** with `llama.cpp` and GGUF models.
- **Portable across operating systems** with launchers for macOS, Linux, and Windows.
- **Hardware-aware setup** selects Metal, CUDA, Vulkan, or CPU inference.
- **Web command console** with streaming responses, stop controls, persistent history, and responsive layout.
- **Live model switching** discovers local models and loads the selected model on demand.
- **Model registry** downloads the starter model or a GGUF file from a direct HTTPS URL.
- **War Mode** provides concise defensive-security guidance through a toggle, `/war`, or `/normal`.
- **Optional image generation** uses Z-Image Turbo and `stable-diffusion.cpp` entirely on-device.
- **Tactical modules** add reusable shell, PowerShell, or Python-based lookups and workflows.
- **Portable logs and output** remain on the WarStick drive.

## Screenshots

| Web command console | Terminal console |
| --- | --- |
| _Screenshot placeholder: `docs/screenshots/web-console.png`_ | _Screenshot placeholder: `docs/screenshots/terminal-console.png`_ |

| Image generation |
| --- |
| _Screenshot placeholder: `docs/screenshots/image-generation.png`_ |

Replace a placeholder with an image after adding the corresponding file:

```html
<img alt="WarStick Web command console" src="docs/screenshots/web-console.png">
```

## Quick Start

Clone or copy the repository to the drive from which you want to run WarStick. Run setup once for each target platform, then use its launcher.

### macOS

```bash
./setup-mac.command
./run-mac.command
```

### Linux

```bash
chmod +x setup-linux.sh run-linux.sh
./setup-linux.sh
./run-linux.sh
```

### Windows

From PowerShell:

```powershell
.\setup-windows.ps1
.\run-windows.ps1
```

Alternatively, double-click `run-windows.bat` after setup.

Setup downloads a compatible inference backend and, when no GGUF model is present, the Qwen2.5 Coder 0.5B starter model. Internet access is required during setup and for modules that query external services; local chat works offline afterward.

## Command Console

The terminal interface provides prepared host-recon and audit prompts, custom objectives, tactical modules, model management, the Web UI launcher, and local audit logs.

Choose **Open Interactive Web UI Dashboard** from the menu, or open [http://127.0.0.1:9931](http://127.0.0.1:9931) while WarStick is running.

## Models

Place compatible `.gguf` files directly in `models/`. The Web UI discovers them automatically and switches models on demand while limiting the router to one loaded text model at a time.

The terminal model registry can also:

1. Download the curated Qwen2.5 Coder starter model.
2. Download a model from a direct HTTPS `.gguf` URL.
3. Select and activate any discovered model.

Model compatibility depends on the bundled `llama.cpp` release. Rerun the platform setup script after updating WarStick to install the required backend version.

## Image Generation

Image generation is optional. During setup, accept the Z-Image Turbo installation prompt to download approximately 6 GB of model and engine files.

The Web UI then provides:

- Chat and Image generation modes.
- Multiple output sizes.
- CPU offload for systems with limited GPU memory.
- Persistent PNG output in `generated-images/`.

The native backend uses Metal on Apple Silicon, CUDA or Vulkan where supported, and CPU as a fallback. Prebuilt image generation is not available on Intel macOS. Text chat remains available when the image bundle is not installed.

## Tactical Modules

Modules live in `tactics/` and appear under menu option 4. They can also be invoked directly from a custom prompt:

```text
/geo_ip_lookup 8.8.8.8
/dns_over_https example.com
/url_intelligence https://example.com
```

See [tactics/README.md](tactics/README.md) for the module format, metadata headers, and examples.

## Local Services

| Port | Service | Purpose |
| ---: | --- | --- |
| `9931` | `llama-server` | Web UI and OpenAI-compatible text inference API |
| `9932` | History service | Portable Web chat history |
| `9933` | Image service | Model discovery, image generation, and generated PNG files |

The text server listens on `0.0.0.0` by default so other devices may be able to reach port `9931`. Keep WarStick on a trusted network and do not expose these ports to the internet.

## Project Layout

```text
command-core/     Runtime scripts, shared libraries, Web UI, and state
models/           Local GGUF text models and optional image model bundles
bin/              Platform-specific native inference binaries
tactics/          User-maintained tactical modules
generated-images/ Persistent image output
warstick-logs/    Runtime and audit logs
```

## Requirements

- A 64-bit supported operating system: macOS, Linux, or Windows.
- Enough free storage for the selected models and native backend.
- `curl` and `tar` on macOS/Linux for setup.
- Perl on macOS/Linux for portable Web history and the image service.
- Windows PowerShell on Windows.
- A compatible GPU is optional; CPU inference is supported.

## Privacy

Prompts, chat history, models, generated images, and logs are stored locally. Tactical modules may contact the external services named in their implementations, so review a module before running it when network privacy matters.

## License

WarStick is available under the [MIT License](LICENSE).
