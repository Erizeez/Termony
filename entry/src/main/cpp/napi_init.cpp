#include "napi/native_api.h"
#include "terminal.h"
#include "log.h"
#include <EGL/egl.h>
#include <GLES3/gl32.h>
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <deque>
#include <map>
#include <set>
#include <string>
#include <vector>
#include <fcntl.h>
#include <poll.h>
#include <pty.h>
#include <sys/time.h>
#include <unistd.h>
#include <native_window/external_window.h>

static EGLDisplay egl_display;
static EGLConfig egl_config;

// init egl display once
void init_egl_display() {
    if (egl_display != EGL_NO_DISPLAY) {
        // already initialized
        return;
    }
    
    egl_display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    assert(egl_display != EGL_NO_DISPLAY);
    
    // initialize egl
    EGLint major_version;
    EGLint minor_version;
    EGLBoolean egl_res = eglInitialize(egl_display, &major_version, &minor_version);
    assert(egl_res == EGL_TRUE);
    
    const EGLint attrib[] = {
        EGL_SURFACE_TYPE,
        EGL_WINDOW_BIT,
        EGL_RENDERABLE_TYPE,
        EGL_OPENGL_ES2_BIT,
        EGL_RED_SIZE,
        8,
        EGL_GREEN_SIZE,
        8,
        EGL_BLUE_SIZE,
        8,
        EGL_ALPHA_SIZE,
        8,
        EGL_DEPTH_SIZE,
        24,
        EGL_STENCIL_SIZE,
        8,
        EGL_SAMPLE_BUFFERS,
        1,
        EGL_SAMPLES,
        4, // Request 4 samples for multisampling
        EGL_NONE
    };

    const EGLint max_config_size = 1;
    EGLint num_configs;
    
    egl_res = eglChooseConfig(egl_display, attrib, &egl_config, max_config_size, &num_configs);
    assert(egl_res == EGL_TRUE);
}

struct SurfaceContext {
    int64_t session_id;
    int64_t surface_id;
    
    OHNativeWindow* native_window;
    EGLSurface egl_surface;
    EGLContext egl_context;
    
    pthread_t render_thread;
    std::atomic<bool> should_exit{false};
};

// -------------------------
// Tool functions for SurfaceContext
// -------------------------
int64_t GetSessionIdFromCtx(void* ctx) {
    SurfaceContext *surface_ctx = (SurfaceContext *)ctx;
    
    return surface_ctx->session_id;
}

bool ShouldExitFromCtx(void* ctx) {
    SurfaceContext *surface_ctx = (SurfaceContext *)ctx;
    
    return surface_ctx->should_exit.load();
}

static std::map<int64_t, SurfaceContext*> g_surfaces;

// called before drawing to activate egl context
void BeforeDraw(void* ctx) {
    SurfaceContext *surface_ctx = (SurfaceContext *)ctx;
    
    if (!eglMakeCurrent(egl_display, surface_ctx->egl_surface, 
                   surface_ctx->egl_surface, surface_ctx->egl_context)) {
        EGLint err = eglGetError();
        LOG_ERROR("eglMakeCurrent failed: 0x%x", err);
    }
}

// called after drawing to swap buffers
void AfterDraw(void* ctx) {
    SurfaceContext *surface_ctx = (SurfaceContext *)ctx;
    
    if (!eglSwapBuffers(egl_display, surface_ctx->egl_surface)) {
        EGLint err = eglGetError();
        LOG_ERROR("eglSwapBuffers failed: 0x%x", err);
    }
}

// called when terminal want to change width
void ResizeWidth(int new_width) {}

// -------------------------
// Session
// -------------------------
static napi_value CreateSession(napi_env env, napi_callback_info info) {
    int64_t session_id = CreateTerminalContext();
    
    napi_value result;
    napi_status status = napi_create_bigint_int64(env, session_id, &result);

    if (status != napi_ok) {
        napi_throw_error(env, nullptr, "Failed to create BigInt for session_id");
        return nullptr;
    }

    return result;
}

static napi_value DestroySession(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    // Get session_id
    int64_t session_id = 0;
    bool lossless = true;
    napi_status res = napi_get_value_bigint_int64(env, args[0], &session_id, &lossless);
    assert(res == napi_ok);
    
    DestroyTerminalContext(session_id);
   
    return nullptr;
}

// start a terminal
static napi_value RunSession(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    // Get session_id
    int64_t session_id = 0;
    bool lossless = true;
    napi_status res = napi_get_value_bigint_int64(env, args[0], &session_id, &lossless);
    assert(res == napi_ok);
    
    Start(session_id);
    return nullptr;
}

// -------------------------
// Surface
// -------------------------
static napi_value CreateSurface(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    
    // Get session_id
    int64_t session_id = 0;
    bool lossless = true;
    napi_status res = napi_get_value_bigint_int64(env, args[0], &session_id, &lossless);
    assert(res == napi_ok);

    int64_t surface_id = 0;
    lossless = true;
    res = napi_get_value_bigint_int64(env, args[1], &surface_id, &lossless);
    assert(res == napi_ok);

    auto *ctx = new SurfaceContext();
    ctx->session_id = session_id;
    ctx->surface_id = surface_id;

    init_egl_display();

    // create windows and display
    OHNativeWindow *native_window;
    OH_NativeWindow_CreateNativeWindowFromSurfaceId(surface_id, &native_window);
    assert(native_window);
    EGLNativeWindowType egl_window = (EGLNativeWindowType)native_window;
    
    ctx->egl_surface = eglCreateWindowSurface(egl_display, egl_config, egl_window, NULL);

    EGLint context_attributes[] = {EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE};
    ctx->egl_context = eglCreateContext(egl_display, egl_config, EGL_NO_CONTEXT, context_attributes);

    // start render thread
    StartRender(&ctx->render_thread, ctx);

    g_surfaces[surface_id] = ctx;

    return nullptr;
}

void DestroySurfaceInternal(SurfaceContext *ctx) {
    if (!ctx) return;

    // stop render thread
    if (ctx->render_thread) {
        ctx->should_exit.store(true);
        pthread_join(ctx->render_thread, nullptr);
        ctx->render_thread = 0;
    }

    // destroy EGLSurface
    if (ctx->egl_surface != EGL_NO_SURFACE) {
        eglDestroySurface(egl_display, ctx->egl_surface);
        ctx->egl_surface = EGL_NO_SURFACE;
    }

    // destroy EGLContext
    if (ctx->egl_context != EGL_NO_CONTEXT) {
        eglDestroyContext(egl_display, ctx->egl_context);
        ctx->egl_context = EGL_NO_CONTEXT;
    }

    // destroy NativeWindow
    if (ctx->native_window) {
        OH_NativeWindow_DestroyNativeWindow(ctx->native_window);
        ctx->native_window = nullptr;
    }

    delete ctx;
}

static napi_value DestroySurface(napi_env env, napi_callback_info info) { 
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int64_t surface_id = 0;
    bool lossless = true;
    napi_status res = napi_get_value_bigint_int64(env, args[0], &surface_id, &lossless);
    assert(res == napi_ok);

    auto it = g_surfaces.find(surface_id);
    if (it == g_surfaces.end()) {
        // already destroyed or invalid id
        return nullptr;
    }

    SurfaceContext *ctx = it->second;
    g_surfaces.erase(it);

    DestroySurfaceInternal(ctx);
    return nullptr;
}

static napi_value ResizeSurface(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    
    // Get session_id
    int64_t session_id = 0;
    bool lossless = true;
    napi_status res = napi_get_value_bigint_int64(env, args[0], &session_id, &lossless);
    assert(res == napi_ok);

    int width, height;
    napi_get_value_int32(env, args[1], &width);
    napi_get_value_int32(env, args[2], &height);
    
    LOG_INFO("ResizeSurface: session_id=%d, buffer=%d x %d",
        session_id, width, height);

    Resize(session_id, width, height);
    return nullptr;
}

// -------------------------
// Terminal Operations
// -------------------------
// send data to terminal
static napi_value Send(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    // Get session_id
    int64_t session_id = 0;
    bool lossless = true;
    napi_status res = napi_get_value_bigint_int64(env, args[0], &session_id, &lossless);
    assert(res == napi_ok);
    
    void *data;
    size_t length;
    res = napi_get_arraybuffer_info(env, args[1], &data, &length);
    assert(res == napi_ok);

    SendData(session_id, (uint8_t *)data, length);
    return nullptr;
}

static napi_value Scroll(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    
    // Get session_id
    int64_t session_id = 0;
    bool lossless = true;
    napi_status res = napi_get_value_bigint_int64(env, args[0], &session_id, &lossless);
    assert(res == napi_ok);

    double offset = 0;
    res = napi_get_value_double(env, args[1], &offset);
    assert(res == napi_ok);

    ScrollBy(session_id, offset);
    return nullptr;
}

// TODO
static pthread_mutex_t pasteboard_lock = PTHREAD_MUTEX_INITIALIZER;
static std::deque<std::string> copy_queue;
static int paste_requests = 0;
static std::deque<std::string> paste_queue;

static napi_value CheckCopy(napi_env env, napi_callback_info info) {
    napi_value res = nullptr;
    pthread_mutex_lock(&pasteboard_lock);
    if (!copy_queue.empty()) {
        std::string content = copy_queue.front();
        copy_queue.pop_front();
        napi_create_string_utf8(env, content.c_str(), content.size(), &res);
    }
    pthread_mutex_unlock(&pasteboard_lock);

    return res;
}

static napi_value CheckPaste(napi_env env, napi_callback_info info) {
    napi_value res = nullptr;
    pthread_mutex_lock(&pasteboard_lock);
    bool has_paste = false;
    if (paste_requests > 0) {
        has_paste = true;
        paste_requests --;
    }
    pthread_mutex_unlock(&pasteboard_lock);

    napi_get_boolean(env, has_paste, &res);
    return res;
}

static napi_value PushPaste(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    size_t size = 0;
    napi_status res = napi_get_value_string_utf8(env, args[0], NULL, 0, &size);
    assert(res == napi_ok);
    std::vector<char> buffer(size + 1);

    res = napi_get_value_string_utf8(env, args[0], buffer.data(), buffer.size(),
                                        &size);
    assert(res == napi_ok);
    std::string s(buffer.data(), size);

    pthread_mutex_lock(&pasteboard_lock);
    paste_queue.push_back(s);
    pthread_mutex_unlock(&pasteboard_lock);

    return nullptr;
}

void Copy(std::string base64) {
    pthread_mutex_lock(&pasteboard_lock);
    copy_queue.push_back(base64);
    pthread_mutex_unlock(&pasteboard_lock);
}

void RequestPaste() {
    pthread_mutex_lock(&pasteboard_lock);
    paste_requests++;
    pthread_mutex_unlock(&pasteboard_lock);
}

std::string GetPaste() {
    std::string res;
    pthread_mutex_lock(&pasteboard_lock);
    if (!paste_queue.empty()) {
        res = paste_queue.front();
        paste_queue.pop_front();
    }
    pthread_mutex_unlock(&pasteboard_lock);
    return res;
}

napi_value OnForeground(napi_env env, napi_callback_info info) {
    return nullptr;
}

napi_value OnBackground(napi_env env, napi_callback_info info) {
    return nullptr;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        // Session
        {"createSession", nullptr, CreateSession, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"destroySession", nullptr, DestroySession, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"runSession", nullptr, RunSession, nullptr, nullptr, nullptr, napi_default, nullptr},
        // Surface
        {"createSurface", nullptr, CreateSurface, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"destroySurface", nullptr, DestroySurface, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"resizeSurface", nullptr, ResizeSurface, nullptr, nullptr, nullptr, napi_default, nullptr},
        // Terminal Operations
        {"send", nullptr, Send, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"scroll", nullptr, Scroll, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"checkCopy", nullptr, CheckCopy, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"checkPaste", nullptr, CheckPaste, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"pushPaste", nullptr, PushPaste, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"onForeground", nullptr, OnForeground, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"onBackground", nullptr, OnBackground, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = ((void *)0),
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) { napi_module_register(&demoModule); }
