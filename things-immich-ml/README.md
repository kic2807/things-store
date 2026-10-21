# things-immich-ml

Runs Immich's machine learning (smart search, face detection and
recognition, OCR) on an **Intel GPU** with OpenVINO, for the **official
Umbrel Immich app**. It does not replace or modify Immich.

Umbrel's Immich ships the CPU-only `immich-machine-learning` image. umbrelOS
already maps the GPU (`/dev/dri`) into Immich's containers, but that image
cannot use it, and app settings cannot change an app's image. This app runs
the `-openvino` image of the same version; Immich sends its ML requests here
first and falls back to its own container.

No web UI: the manifest port 30109 is a placeholder.

| Service | Image | What |
|---------|-------|------|
| `server` | `ghcr.io/immich-app/immich-machine-learning:<version>-openvino` | ML API on `things-immich-ml_server_1:3003`, models in `data/model-cache` |

The manifest's `GPU` permission makes umbrelOS add `/dev/dri` and the
render group to the container (as for Immich). Upstream's OpenVINO setup
(`docker/hwaccel.ml.yml`) needs nothing more.

## Requirements

- An Intel GPU with a `/dev/dri/renderD*` device: UHD/Iris Xe (11th gen or
  newer works best), Alder Lake-N (N100/N150), Arc.
- The official Immich app, installed.

## Setup

1. Install the app. On the first request it downloads the models into
   `data/model-cache` (a few hundred MB) and OpenVINO compiles them, so the
   first jobs are slow.
2. Immich → **Administration → Settings → Machine Learning Settings** →
   URL:
   1. `http://things-immich-ml_server_1:3003`
   2. `http://immich_machine-learning_1:3003` (fallback)

   Save. Immich uses the first URL that answers.
3. **Check it runs on the GPU:** Administration → Jobs → **Smart Search** →
   *Missing* (or *All* to redo every photo), then:

   ```sh
   sudo docker logs things-immich-ml_server_1 2>&1 | grep -i -E "provider|openvino|error" | tail
   ```

   The model loads should list `OpenVINOExecutionProvider`. Give it a few
   minutes: each model is first downloaded and compiled for the GPU
   (`Preparing … for OpenVINOExecutionProvider`, about 30 s each, on the
   CPU), so CPU load stays high and the GPU idle until that is done. The
   compiled models are cached in `data/model-cache`, so later starts are
   quick. The log looks the same if OpenVINO cannot open the GPU (it then
   runs on the CPU); to check, the device list must include `GPU`:
   `sudo docker exec things-immich-ml_server_1 python -c "import onnxruntime as o; print(o.capi._pybind_state.get_available_openvino_device_ids())"`. The built-in
   container should stay idle:
   `sudo docker logs --since 5m immich_machine-learning_1` shows no new
   model loads.

## Updates

Keep the version equal to Umbrel's Immich (shown in the Umbrel app store, or
`sudo docker inspect immich_server_1 --format '{{.Config.Image}}'`). The
store's update job opens a PR for every new Immich release and never merges
it on its own: merge it once Umbrel's Immich has the same version. If the
versions drift apart and Immich's ML requests fail, Immich falls back to its
own CPU container.

## Test results

2026-10-22, Intel Alder Lake-N, 3.3.4: umbrelOS mapped `/dev/dri`; face
detection and recognition and smart search ran on the GPU once the models
were compiled (a few minutes after the first job).

## Known limits

- **Model compatibility:** a few models run slower or fail on OpenVINO; if a
  job errors, the fallback URL takes over for that request. Check the log
  above.
- **Two ML containers:** the built-in one keeps running (Umbrel starts it
  with Immich), but it only loads models when the fallback is used; idle
  models are unloaded after 5 minutes.
