// Linux device enumeration stub for the shared FFmpeg build.
// Avoids a runtime dependency on ALSA, X11 and Xrandr. FFmpeg's own v4l2,
// alsa and x11grab inputs still work when opened by name.
#include "../src/bindings/device.h"

namespace ffmpeg {

std::vector<DeviceInfo> enumerateDevices() { return {}; }
std::vector<DeviceMode> enumerateDeviceModes(const std::string&) { return {}; }
std::vector<AudioDeviceMode> enumerateAudioDeviceModes(const std::string&) { return {}; }
std::string getVideoInputFormat() { return "v4l2"; }
std::string getAudioInputFormat() { return "alsa"; }
std::string getScreenInputFormat() { return "x11grab"; }
bool hasScreenCapturePermission() { return true; }
bool requestScreenCaptureAccess() { return true; }

}  // namespace ffmpeg
