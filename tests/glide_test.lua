-- the easing used by the settings window: from 0 to a 120 px target (two notches) at 60 fps
local pos, target, EASE, frames = 0, 120, 14, 0
while math.abs(target - pos) >= 0.5 do pos = pos + (target - pos) * math.min(1, (1 / 60) * EASE); frames = frames + 1 end
print(("two wheel notches: glides 120 px in %d frames (%.2f s) instead of jumping"):format(frames, frames / 60))
