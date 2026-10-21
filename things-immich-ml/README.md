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

   The model loads should list `OpenVINOExecutionProvider`. The built-in
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

## Known limits

- **Model compatibility:** a few models run slower or fail on OpenVINO; if a
  job errors, the fallback URL takes over for that request. Check the log
  above.
- **Two ML containers:** the built-in one keeps running (Umbrel starts it
  with Immich), but it only loads models when the fallback is used; idle
  models are unloaded after 5 minutes.
