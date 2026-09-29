# gpu-screen-recorder with region capture right under cosmic-comp. The recorder takes
# its monitor size from wl_output.mode, and its handler keeps whichever mode it hears
# last. cosmic-comp advertises every mode the monitor has, current first and 640x480
# last, so the recorder scaled a region by 640/2560 and a window recording was its
# top-left quarter (2026-09-29). Only the mode flagged current counts. Upstream 6.1.3
# has the same handler; drop the patch when it takes the flag.
{ gpu-screen-recorder }:
gpu-screen-recorder.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./patches/gpu-screen-recorder-current-mode.patch ];
})
