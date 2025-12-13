#ifndef __TERMINAL_H__
#define __TERMINAL_H__

#include <cstdint>
#include <deque>
#include <string>
#include <vector>
#include <stdlib.h>
#include <optional>
#include <pthread.h>

// font weight, italic
enum font_class {
    regular = 0,
    bold = 1,
    italic = 2,
    bolditalic = 3,
    NUM_FONT_CLASS,
};

struct font_spec {
    const char *path;
    struct {
        font_class type = font_class::regular;
        int ttc_index = 0;
        std::optional<long> variable_width;
        std::optional<long> variable_weight;
    } opts;
};

// make sure conform to ANSI
enum term_colors {
    black, red, green, yellow, blue, magenta, cyan, white,
    brblack, brred, brgreen, bryellow, brblue, brmagenta, brcyan, brwhite,
    NUM_TERM_COLORS
};

#define PACK_RGB(r,g,b) ((uint32_t(r&0xff)<<16) | (uint32_t(g&0xff)<<8) | uint32_t(b)&0xff)
// maintain terminal status
struct term_style {
    struct color {
        union {
            uint32_t value;
            struct {
                uint8_t blue;
                uint8_t green;
                uint8_t red;
                uint8_t zero;
            } u;
            uint8_t bgrz[4];
        };
        inline void set_rgb(uint8_t r, uint8_t g, uint8_t b) {
            bgrz[0] = b;
            bgrz[1] = g;
            bgrz[2] = r;
            bgrz[3] = 0;
        }
        inline void put_f3(float * pf3) const {
            pf3[0] = bgrz[2] / 255.0;
            pf3[1] = bgrz[1] / 255.0;
            pf3[2] = bgrz[0] / 255.0;
        }
        color() : value(0) {}
        color(uint32_t rgb) : value(rgb) {}
        color & operator=(uint32_t val) {
            value = val;
            return * this;
        }
    };
    color fore, back;
    font_class type = regular;
    // blinking
    bool blink = false;
    // constuctor
    term_style();
};

// character in terminal
struct term_char {
    // way beyond valid utf8
    static constexpr uint32_t
        WIDE_TAIL = 'wcht';
    uint32_t code = ' ';
    term_style style;
};

// escape sequence state machine
enum escape_states {
    state_idle,
    state_esc,
    state_csi,
    state_osc,
    state_dcs,
};

// utf8 decode state machine
enum utf8_states {
    state_initial,
    state_2byte_2,        // expected 2nd byte of 2-byte sequence
    state_3byte_2_e0,     // expected 2nd byte of 3-byte sequence starting with 0xe0
    state_3byte_2_non_e0, // expected 2nd byte of 3-byte sequence starting with non-0xe0
    state_3byte_3,        // expected 3rd byte of 3-byte sequence
    state_4byte_2_f0,     // expected 2nd byte of 4-byte sequence starting with 0xf0
    state_4byte_2_f1_f3,  // expected 2nd byte of 4-byte sequence starting with 0xf1 to 0xf3
    state_4byte_2_f4,     // expected 2nd byte of 4-byte sequence starting with 0xf4
    state_4byte_3,        // expected 3rd byte of 4-byte sequence
    state_4byte_4,        // expected 4th byte of 4-byte sequence
};

struct terminal_context {
    int64_t session_id;
    
    // protect multithreaded usage
    pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

    // pty
    int fd = -1;

    // escape sequence state machine
    escape_states escape_state = state_idle;
    std::string escape_buffer;

    // utf8 decode state machine
    utf8_states utf8_state = state_initial;
    uint32_t current_utf8 = 0;

    // DEC private modes
    // DECTCEM, Show cursor
    bool show_cursor = true;
    // DECAWM, Autowrap Mode
    bool enable_wrap = true;
    // DECSCNM, Reverse Video
    bool reverse_video = false;
    // DECOM, Origin Mode
    bool origin_mode = false;
    // IRM, Insert Mode
    bool insert_mode = false;

    // tab handling
    int tab_size = 8;
    // columns where tab stops
    std::vector<bool> tab_stops;

    // save/restore feature
    int save_row = 0;
    int save_col = 0;
    term_style save_style;
    // current text style, see CSI Pm M, SGR
    term_style current_style;

    // scrollback history, only if exceeds buffer
    std::deque<std::vector<term_char>> history;
    // terminal content, limited to rows & cols
    std::vector<std::vector<term_char>> buffer;
    // terminal size
    int num_cols = 0;
    int num_rows = 0;
    // cursor location
    int row = 0;
    int col = 0;

    // DECSTBM, scrolling region
    int scroll_top = 0;
    int scroll_bottom = num_rows - 1;
    
    int buffer_width = 0;
    int buffer_height = 0;
    
    pthread_t terminal_thread;
    std::atomic<bool> should_exit{false};
    std::atomic<bool> is_rendering{false};

    void ResizeTo(int new_term_row, int new_term_col);

    void DropFirstRowIfOverflow();

    void InsertUtf8(uint32_t codepoint);

    // clamp cursor to valid range
    void ClampCursor();

    // set absolute cursor location
    void SetCursor(int new_row, int new_col);

    // move cursor in relative position
    void MoveCursor(int row_diff, int col_diff);

    // write data to pty until fully sent
    void WriteFull(uint8_t *data, size_t length);

    // handle CSI escape sequences
    void HandleCSI(uint8_t current);


    void Parse(uint8_t input);

    // wrapper that calls ctx->Worker
    static void *TerminalWorker(void * data);
    // poll fds and feed to terminal Parse
    void Worker();

    // fork & create pty
    // assume lock is held
    void Fork();
};

// create a new terminal context
int64_t CreateTerminalContext();
// destroy existing terminal context
void DestroyTerminalContext(int64_t session_id);
// start a terminal
void Start(int64_t session_id);
// start rendering
void StartRender(pthread_t *render_thread, void* ctx);
// send data to terminal
void SendData(int64_t session_id, uint8_t *data, size_t length);
// resize window
void Resize(int64_t session_id, int width, int height);
void ScrollBy(int64_t session_id, double offset);

// implemented by code in napi/glfw
extern void BeforeDraw(void* ctx);
extern void AfterDraw(void* ctx);
extern void ResizeWidth(int new_width);
// copy/paste with base64 encoded string
extern void Copy(std::string base64);
extern void RequestPaste();
extern std::string GetPaste();

extern int64_t GetSessionIdFromCtx(void* ctx);
extern bool ShouldExitFromCtx(void* ctx);

// huge it is intentionally kept here
static constexpr uint32_t color_map_256[] = {
    0x000000,
    0x800000,
    0x008000,
    0x808000,
    0x000080,
    0x800080,
    0x008080,
    0xc0c0c0,
    0x808080,
    0xff0000,
    0x00ff00, 
    0xffff00, 
    0x0000ff,
    0xff00ff,
    0x00ffff,
    0xffffff,
    0x000000,
    0x00005f,
    0x000087,
    0x0000af,
    0x0000d7,
    0x0000ff,
    0x005f00,
    0x005f5f,
    0x005f87,
    0x005faf,
    0x005fd7,
    0x005fff,
    0x008700,
    0x00875f,
    0x008787,
    0x0087af,
    0x0087d7,
    0x0087ff,
    0x00af00,
    0x00af5f,
    0x00af87,
    0x00afaf,
    0x00afd7,
    0x00afff,
    0x00d700,
    0x00d75f,
    0x00d787,
    0x00d7af,
    0x00d7d7,
    0x00d7ff,
    0x00ff00,
    0x00ff5f,
    0x00ff87,
    0x00ffaf,
    0x00ffd7,
    0x00ffff,
    0x5f0000,
    0x5f005f,
    0x5f0087,
    0x5f00af,
    0x5f00d7,
    0x5f00ff,
    0x5f5f00,
    0x5f5f5f,
    0x5f5f87,
    0x5f5faf,
    0x5f5fd7,
    0x5f5fff,
    0x5f8700,
    0x5f875f,
    0x5f8787,
    0x5f87af,
    0x5f87d7,
    0x5f87ff,
    0x5faf00,
    0x5faf5f,
    0x5faf87,
    0x5fafaf,
    0x5fafd7,
    0x5fafff,
    0x5fd700,
    0x5fd75f,
    0x5fd787,
    0x5fd7af,
    0x5fd7d7,
    0x5fd7ff,
    0x5fff00,
    0x5fff5f,
    0x5fff87,
    0x5fffaf,
    0x5fffd7,
    0x5fffff,
    0x870000,
    0x87005f,
    0x870087,
    0x8700af,
    0x8700d7,
    0x8700ff,
    0x875f00,
    0x875f5f,
    0x875f87,
    0x875faf,
    0x875fd7,
    0x875fff,
    0x878700, 
    0x87875f, 
    0x878787, 
    0x8787af, 
    0x8787d7, 
    0x8787ff,
    0x87af00, 
    0x87af5f, 
    0x87af87, 
    0x87afaf, 
    0x87afd7, 
    0x87afff,
    0x87d700, 
    0x87d75f, 
    0x87d787, 
    0x87d7af, 
    0x87d7d7, 
    0x87d7ff,
    0x87ff00, 
    0x87ff5f, 
    0x87ff87, 
    0x87ffaf, 
    0x87ffd7, 
    0x87ffff,
    0xaf0000, 
    0xaf005f, 
    0xaf0087, 
    0xaf00af, 
    0xaf00d7, 
    0xaf00ff,
    0xaf5f00, 
    0xaf5f5f, 
    0xaf5f87, 
    0xaf5faf, 
    0xaf5fd7, 
    0xaf5fff,
    0xaf8700, 
    0xaf875f, 
    0xaf8787, 
    0xaf87af, 
    0xaf87d7, 
    0xaf87ff,
    0xafaf00, 
    0xafaf5f, 
    0xafaf87, 
    0xafafaf, 
    0xafafd7, 
    0xafafff,
    0xafd700, 
    0xafd75f, 
    0xafd787, 
    0xafd7af, 
    0xafd7d7, 
    0xafd7ff,
    0xafff00, 
    0xafff5f, 
    0xafff87, 
    0xafffaf, 
    0xafffd7, 
    0xafffff,
    0xd70000, 
    0xd7005f, 
    0xd70087, 
    0xd700af, 
    0xd700d7, 
    0xd700ff,
    0xd75f00, 
    0xd75f5f, 
    0xd75f87, 
    0xd75faf, 
    0xd75fd7, 
    0xd75fff,
    0xd78700, 
    0xd7875f, 
    0xd78787, 
    0xd787af, 
    0xd787d7, 
    0xd787ff,
    0xd7af00, 
    0xd7af5f, 
    0xd7af87, 
    0xd7afaf, 
    0xd7afd7, 
    0xd7afff,
    0xd7d700, 
    0xd7d75f, 
    0xd7d787, 
    0xd7d7af, 
    0xd7d7d7, 
    0xd7d7ff,
    0xd7ff00, 
    0xd7ff5f, 
    0xd7ff87, 
    0xd7ffaf, 
    0xd7ffd7, 
    0xd7ffff,
    0xff0000, 
    0xff005f, 
    0xff0087, 
    0xff00af, 
    0xff00d7, 
    0xff00ff,
    0xff5f00, 
    0xff5f5f, 
    0xff5f87, 
    0xff5faf, 
    0xff5fd7, 
    0xff5fff,
    0xff8700, 
    0xff875f, 
    0xff8787, 
    0xff87af, 
    0xff87d7, 
    0xff87ff,
    0xffaf00, 
    0xffaf5f, 
    0xffaf87, 
    0xffafaf, 
    0xffafd7, 
    0xffafff,
    0xffd700, 
    0xffd75f, 
    0xffd787, 
    0xffd7af, 
    0xffd7d7, 
    0xffd7ff,
    0xffff00, 
    0xffff5f, 
    0xffff87, 
    0xffffaf, 
    0xffffd7, 
    0xffffff,
    0x080808, 
    0x121212, 
    0x1c1c1c, 
    0x262626, 
    0x303030, 
    0x3a3a3a,
    0x444444, 
    0x4e4e4e, 
    0x585858, 
    0x606060, 
    0x666666, 
    0x767676,
    0x808080, 
    0x8a8a8a, 
    0x949494, 
    0x9e9e9e, 
    0xa8a8a8, 
    0xb2b2b2,
    0xbcbcbc, 
    0xc6c6c6, 
    0xd0d0d0, 
    0xdadada, 
    0xe4e4e4, 
    0xeeeeee
};

#endif