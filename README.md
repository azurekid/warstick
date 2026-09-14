<img width="1024" height="559" alt="image" src="https://github.com/user-attachments/assets/0bebecf3-b4c6-4320-9e61-eeb84d824494" />

# warstick
pendrive hosted AI WarStick

During setup, WarStick detects the available GPU and installs the matching llama.cpp backend. It uses Metal on macOS, CUDA or Vulkan on Windows when supported, Vulkan on Linux when a working GPU driver is available, and otherwise falls back to CPU.

Web chat history is stored in `command-core/chat_history.json` on the WarStick drive, so the same conversation is restored across macOS, Linux, and Windows. The local history service uses the system Perl runtime on macOS/Linux and PowerShell on Windows; no Python runtime or additional package is required.

The web console supports War Mode through its toggle or the `/war` and `/normal` prompt commands. War Mode keeps responses concise and focused on defensive security actions, risks, and next steps. The runtime model registry can download the curated starter model or any direct HTTPS `.gguf` URL, then activate it immediately.

## Image Generation

Setup can optionally install Z-Image Turbo and the native `stable-diffusion.cpp` engine. The bundle is about 6 GB and uses Metal on Apple Silicon, CUDA or Vulkan on supported Linux and Windows GPUs, and CPU otherwise. Python is not required. Prebuilt image generation is not offered on Intel macOS.

Run the platform setup script and accept the Z-Image prompt. The model bundle is stored in `models/image/z-image-turbo`, and the platform engine is stored below `bin/<platform>/image`. At runtime, the local image service listens on port `9933`; switch the Web UI from Chat to Image to select a size, enable CPU offload when GPU memory is limited, and render an image. PNG files persist in `generated-images` on the WarStick drive.

Z-Image Turbo setup is optional. If the bundle is absent or the image service cannot start, text chat on port `9931` and portable history on port `9932` continue to work normally.

## Tactical Modules

User-maintained extensions live in [tactics/README.md](tactics/README.md).
