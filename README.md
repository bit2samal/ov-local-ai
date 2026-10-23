# Local AI model server

This Docker Compose setup runs Intel OpenVINO Model Server (OVMS) with an
OpenAI-compatible HTTP API. It downloads the selected model from Hugging Face
the first time the service starts and keeps the downloaded files in `./models`.
The GPU-enabled OVMS image supports CPU, Intel GPU, and Intel NPU inference.
The default model is `OpenVINO/Qwen3.5-9B-int8-ov`.

## Requirements

- Docker Engine or Docker Desktop with Docker Compose v2
- Internet access for the initial image and model downloads
- Enough system memory and disk space for the selected model

## Start on CPU (default)

```powershell
docker compose up --build
```

The first start can take a while while Docker downloads the image and model.
The API is available locally at `http://localhost:8000`.

Check the available model:

```powershell
curl.exe http://localhost:8000/v1/models
```

Send a chat completion request:

```powershell
$body = '{"model":"OpenVINO/Qwen3.5-9B-int8-ov","messages":[{"role":"user","content":"Explain what OpenVINO does in one sentence."}],"chat_template_kwargs":{"enable_thinking":false}}'
$requestPath = Join-Path $env:TEMP "ovms-request.json"
[IO.File]::WriteAllText($requestPath, $body, (New-Object System.Text.UTF8Encoding($false)))
curl.exe http://localhost:8000/v1/chat/completions `
  -H "Content-Type: application/json" `
  --data-binary "@$requestPath"
Remove-Item $requestPath
```

The model name in requests must match the configured model ID. The API is bound
to `127.0.0.1` so it is not exposed to other machines on the network.

## Use Intel GPU on Linux

Use a Linux host with the Intel GPU driver installed and `/dev/dri` available.
Set `RENDER_GROUP_ID` to the host render group's ID so the container can access
the GPU:

```sh
export TARGET_DEVICE=GPU
export MODEL_ID=OpenVINO/Qwen3.5-9B-int8-ov
export RENDER_GROUP_ID="$(stat -c '%g' /dev/dri/render*)"
docker compose -f docker-compose.yml -f docker-compose.gpu.yml up --build -d
```

The GPU overlays enable larger GPU allocations because some supported Intel
GPUs otherwise reject model weights larger than a single allocation limit. This
setting can reduce performance.

## Use Intel GPU with WSL 2

OpenVINO's documented WSL 2 GPU path uses `/dev/dxg` and mounts `/usr/lib/wsl`.
The paths must be available to the Docker daemon. Confirm the device can be
passed through before starting the service:

```sh
docker run --rm --device=/dev/dxg --volume /usr/lib/wsl:/usr/lib/wsl:ro \
  --entrypoint sh openvino/model_server:latest-gpu \
  -lc 'ls -l /dev/dxg && ls /usr/lib/wsl'
```

Then select GPU inference and start OVMS:

```sh
export TARGET_DEVICE=GPU
export MODEL_ID=OpenVINO/Qwen3.5-9B-int8-ov
docker compose -f docker-compose.yml -f docker-compose.wsl-gpu.yml up --build -d
```

If `/dev/dxg` is missing where the Docker daemon runs, use Docker Engine inside
WSL 2 or run the GPU setup on Linux.

## Use Intel NPU on Linux

NPU passthrough requires a supported Linux host with the Intel NPU driver
installed and `/dev/accel` available to the Docker daemon. Docker Desktop/WSL 2
generally does not expose `/dev/accel`; this profile requires native Linux NPU
passthrough. The Qwen3.5-9B int8 model is large, so NPU inference depends on
the device's available memory and support for the model's operations.

```sh
export RENDER_GROUP_ID="$(stat -c '%g' /dev/dri/render*)"
docker compose -f docker-compose.yml -f docker-compose.npu.yml up --build -d
```

The NPU profile selects `TARGET_DEVICE=NPU` explicitly. Confirm the device is
available before starting:

```sh
test -e /dev/accel/accel0
stat -c '%g' /dev/dri/render*
```

If OVMS reports that it cannot compile the model for NPU, use the GPU or CPU
profile instead.

The accelerator overlays expose host device nodes to the container. Only use
them on a trusted local machine.

## Select another model

Create a `.env` file in this directory and set `MODEL_ID`, for example:

```dotenv
MODEL_ID=OpenVINO/Qwen3.5-9B-int8-ov
```

Then restart the service. The Qwen3.5 9B int8 model is also the default if
`MODEL_ID` is not set:

```powershell
docker compose up --build
```

The model publisher recommends a 2 GB KV cache for this deployment. Check
system memory and disk space before selecting a different model. Model
licenses and usage terms are provided by their publishers on Hugging Face.

## Stop

```powershell
docker compose down
```

Downloaded model files remain in `./models` between runs. Remove that directory
manually if you want to reclaim the disk space.
