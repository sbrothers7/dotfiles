/* LD_PRELOAD shim: shorten GTK3's hardcoded 500 ms tooltip hover delay.
 *
 * gtktooltip.c starts the hover timer with
 *   gdk_threads_add_timeout_full(0, 500, tooltip_popup_timeout, g_object_ref(display), g_object_unref)
 * so only that exact call (500 ms, GdkDisplay data, g_object_unref notify) is changed.
 * Delay comes from $GTK_TOOLTIP_DELAY (ms, default 150).
 *
 * Build: gcc -shared -fPIC -O2 -o tooltip-delay.so tooltip-delay.c $(pkg-config --cflags --libs gdk-3.0) -ldl
 * (if the .so is missing, ld.so just warns and the program starts with the stock delay)
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdlib.h>
#include <gdk/gdk.h>

typedef guint (*add_timeout_fn)(gint, guint, GSourceFunc, gpointer, GDestroyNotify);

static add_timeout_fn real_add_timeout;
static guint delay = 150;

__attribute__((constructor)) static void init(void)
{
    real_add_timeout = (add_timeout_fn)dlsym(RTLD_NEXT, "gdk_threads_add_timeout_full");
    const char *env = getenv("GTK_TOOLTIP_DELAY");
    if (env)
        delay = (guint)atoi(env);
    /* keep the shim out of child processes (module scripts, nvidia-smi) */
    unsetenv("LD_PRELOAD");
}

guint gdk_threads_add_timeout_full(gint priority, guint interval, GSourceFunc function,
                                   gpointer data, GDestroyNotify notify)
{
    if (interval == 500 && notify == (GDestroyNotify)g_object_unref && GDK_IS_DISPLAY(data))
        interval = delay;
    return real_add_timeout(priority, interval, function, data, notify);
}
