set step to 2
set currentVolume to output volume of (get volume settings)
set targetVolume to currentVolume - step
if targetVolume < 0 then set targetVolume to 0
set volume output volume targetVolume output muted false
