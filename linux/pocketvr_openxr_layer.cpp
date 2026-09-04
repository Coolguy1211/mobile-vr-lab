#define XR_NO_PROTOTYPES
#include <openxr/openxr.h>
#include <openxr/openxr_loader_negotiation.h>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <map>
#include <mutex>
#include <string>

namespace {
struct Pose {
    double yaw = 0, pitch = 0, roll = 0, x = 0, y = 0, z = 0;
    bool valid = false;
};

std::mutex g_lock;
std::map<XrInstance, PFN_xrGetInstanceProcAddr> g_gipa;
PFN_xrGetInstanceProcAddr g_next_gipa = nullptr;
PFN_xrLocateViews g_next_locate = nullptr;
PFN_xrCreateSession g_next_create_session = nullptr;
PFN_xrDestroySession g_next_destroy_session = nullptr;

std::string state_path() {
    const char* value = std::getenv("POCKETVR_STATE_FILE");
    return value && *value ? value : "/tmp/pocketvr_pose.json";
}

bool number(const std::string& source, const char* key, double& value) {
    const auto key_pos = source.find(std::string("\"") + key + "\"");
    if (key_pos == std::string::npos) return false;
    const auto colon = source.find(':', key_pos);
    if (colon == std::string::npos) return false;
    char* end = nullptr;
    value = std::strtod(source.c_str() + colon + 1, &end);
    return end != source.c_str() + colon + 1;
}

Pose read_pose() {
    Pose pose;
    std::ifstream file(state_path());
    const std::string source((std::istreambuf_iterator<char>(file)), {});
    if (source.empty()) return pose;
    const bool complete = number(source, "yaw", pose.yaw) && number(source, "pitch", pose.pitch) && number(source, "roll", pose.roll);
    number(source, "x", pose.x);
    number(source, "y", pose.y);
    number(source, "z", pose.z);
    pose.valid = complete;
    return pose;
}

XrQuaternionf quaternion_from_euler(double yaw, double pitch, double roll) {
    yaw *= M_PI / 180.0;
    pitch *= M_PI / 180.0;
    roll *= M_PI / 180.0;
    const double cy = std::cos(yaw * .5), sy = std::sin(yaw * .5);
    const double cp = std::cos(pitch * .5), sp = std::sin(pitch * .5);
    const double cr = std::cos(roll * .5), sr = std::sin(roll * .5);
    return {
        static_cast<float>(sr * cp * cy - cr * sp * sy),
        static_cast<float>(cr * sp * cy + sr * cp * sy),
        static_cast<float>(cr * cp * sy - sr * sp * cy),
        static_cast<float>(cr * cp * cy + sr * sp * sy)
    };
}

XrResult XRAPI_CALL layer_locate_views(XrSession session, const XrViewLocateInfo* info,
                                       XrViewState* view_state, uint32_t capacity,
                                       uint32_t* count, XrView* views) {
    if (!g_next_locate) return XR_ERROR_HANDLE_INVALID;
    XrResult result = g_next_locate(session, info, view_state, capacity, count, views);
    if (XR_FAILED(result) || !views || !count || *count == 0) return result;

    Pose pose;
    {
        std::lock_guard<std::mutex> guard(g_lock);
        pose = read_pose();
    }
    if (!pose.valid) return result;

    const XrQuaternionf orientation = quaternion_from_euler(pose.yaw, pose.pitch, pose.roll);
    const uint32_t view_count = capacity < *count ? capacity : *count;
    for (uint32_t i = 0; i < view_count; ++i) {
        views[i].pose.orientation = orientation;
        const float eye_offset = view_count >= 2 ? (i == 0 ? -0.032f : 0.032f) : 0.0f;
        views[i].pose.position = {static_cast<float>(pose.x) + eye_offset, static_cast<float>(pose.y), static_cast<float>(pose.z)};
    }
    if (view_state) {
        view_state->viewStateFlags |= XR_VIEW_STATE_ORIENTATION_VALID_BIT |
            XR_VIEW_STATE_POSITION_VALID_BIT | XR_VIEW_STATE_ORIENTATION_TRACKED_BIT |
            XR_VIEW_STATE_POSITION_TRACKED_BIT;
    }
    return result;
}

XrResult XRAPI_CALL layer_create_session(XrInstance instance, const XrSessionCreateInfo* info, XrSession* session) {
    if (!g_next_create_session) return XR_ERROR_HANDLE_INVALID;
    const XrResult result = g_next_create_session(instance, info, session);
    if (XR_SUCCEEDED(result) && g_next_gipa) {
        PFN_xrVoidFunction function = nullptr;
        if (XR_SUCCEEDED(g_next_gipa(instance, "xrLocateViews", &function))) {
            g_next_locate = reinterpret_cast<PFN_xrLocateViews>(function);
        }
        if (XR_SUCCEEDED(g_next_gipa(instance, "xrDestroySession", &function))) {
            g_next_destroy_session = reinterpret_cast<PFN_xrDestroySession>(function);
        }
    }
    return result;
}

XrResult XRAPI_CALL layer_destroy_session(XrSession session) {
    if (!g_next_destroy_session) return XR_ERROR_HANDLE_INVALID;
    return g_next_destroy_session(session);
}

XrResult XRAPI_CALL layer_destroy_instance(XrInstance instance) {
    const auto it = g_gipa.find(instance);
    if (it == g_gipa.end()) return XR_ERROR_HANDLE_INVALID;
    PFN_xrVoidFunction function = nullptr;
    XrResult result = it->second(instance, "xrDestroyInstance", &function);
    if (XR_SUCCEEDED(result)) result = reinterpret_cast<PFN_xrDestroyInstance>(function)(instance);
    g_gipa.erase(it);
    g_next_gipa = nullptr;
    g_next_locate = nullptr;
    g_next_create_session = nullptr;
    g_next_destroy_session = nullptr;
    return result;
}

XrResult XRAPI_CALL layer_get_instance_proc_addr(XrInstance instance, const char* name,
                                                  PFN_xrVoidFunction* function) {
    if (!name || !function) return XR_ERROR_VALIDATION_FAILURE;
    *function = nullptr;
    if (std::strcmp(name, "xrGetInstanceProcAddr") == 0) {
        *function = reinterpret_cast<PFN_xrVoidFunction>(layer_get_instance_proc_addr);
    } else if (std::strcmp(name, "xrCreateInstance") == 0) {
        *function = reinterpret_cast<PFN_xrVoidFunction>(+[](const XrInstanceCreateInfo*, XrInstance*) {
            return XR_ERROR_FUNCTION_UNSUPPORTED;
        });
    } else if (std::strcmp(name, "xrDestroyInstance") == 0) {
        *function = reinterpret_cast<PFN_xrVoidFunction>(layer_destroy_instance);
    } else if (std::strcmp(name, "xrCreateSession") == 0) {
        *function = reinterpret_cast<PFN_xrVoidFunction>(layer_create_session);
    } else if (std::strcmp(name, "xrDestroySession") == 0) {
        *function = reinterpret_cast<PFN_xrVoidFunction>(layer_destroy_session);
    } else if (std::strcmp(name, "xrLocateViews") == 0) {
        *function = reinterpret_cast<PFN_xrVoidFunction>(layer_locate_views);
    }
    if (*function) return XR_SUCCESS;
    const auto it = g_gipa.find(instance);
    if (it == g_gipa.end()) return XR_ERROR_HANDLE_INVALID;
    return it->second(instance, name, function);
}

XrResult XRAPI_CALL layer_create_api_layer_instance(const XrInstanceCreateInfo* info,
                                                     const XrApiLayerCreateInfo* layer_info,
                                                     XrInstance* instance) {
    if (!layer_info || !layer_info->nextInfo || !layer_info->nextInfo->nextCreateApiLayerInstance) {
        return XR_ERROR_INITIALIZATION_FAILED;
    }
    XrApiLayerCreateInfo next = *layer_info;
    next.nextInfo = layer_info->nextInfo->next;
    const XrResult result = layer_info->nextInfo->nextCreateApiLayerInstance(info, &next, instance);
    if (XR_FAILED(result)) return result;

    std::lock_guard<std::mutex> guard(g_lock);
    g_gipa[*instance] = layer_info->nextInfo->nextGetInstanceProcAddr;
    g_next_gipa = layer_info->nextInfo->nextGetInstanceProcAddr;
    PFN_xrVoidFunction function = nullptr;
    if (XR_SUCCEEDED(g_next_gipa(*instance, "xrCreateSession", &function))) {
        g_next_create_session = reinterpret_cast<PFN_xrCreateSession>(function);
    }
    return XR_SUCCESS;
}
}  // namespace

extern "C" __attribute__((visibility("default"))) XRAPI_ATTR XrResult XRAPI_CALL
xrNegotiateLoaderApiLayerInterface(const XrNegotiateLoaderInfo* loader, const char*,
                                   XrNegotiateApiLayerRequest* request) {
    if (!loader || !request || loader->structType != XR_LOADER_INTERFACE_STRUCT_LOADER_INFO ||
        request->structType != XR_LOADER_INTERFACE_STRUCT_API_LAYER_REQUEST ||
        loader->structVersion != XR_LOADER_INFO_STRUCT_VERSION ||
        request->structVersion != XR_API_LAYER_INFO_STRUCT_VERSION ||
        loader->structSize != sizeof(XrNegotiateLoaderInfo) ||
        request->structSize != sizeof(XrNegotiateApiLayerRequest) ||
        loader->minInterfaceVersion > XR_CURRENT_LOADER_API_LAYER_VERSION ||
        loader->maxInterfaceVersion < XR_CURRENT_LOADER_API_LAYER_VERSION) {
        return XR_ERROR_INITIALIZATION_FAILED;
    }
    request->layerInterfaceVersion = XR_CURRENT_LOADER_API_LAYER_VERSION;
    request->layerApiVersion = XR_MAKE_VERSION(1, 0, 0);
    request->getInstanceProcAddr = layer_get_instance_proc_addr;
    request->createApiLayerInstance = layer_create_api_layer_instance;
    return XR_SUCCESS;
}
