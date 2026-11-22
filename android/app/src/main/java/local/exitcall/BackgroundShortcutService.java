package local.exitcall;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.content.ComponentName;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityManager;

public final class BackgroundShortcutService extends AccessibilityService {
    static final String CALLER = "shortcut_caller";
    static final String NUMBER = "shortcut_number";
    static final String FULL = "shortcut_full";
    private static final long DELAY_MS = 10_000;

    private final VolumeUpDoublePress shortcut = new VolumeUpDoublePress();
    private final Handler handler = new Handler(Looper.getMainLooper());

    static boolean isEnabled(Context context) {
        AccessibilityManager manager = context.getSystemService(AccessibilityManager.class);
        if (manager == null || !manager.isEnabled()) return false;

        ComponentName component = new ComponentName(context, BackgroundShortcutService.class);
        for (AccessibilityServiceInfo service :
                manager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)) {
            if (component.equals(ComponentName.unflattenFromString(service.getId()))) return true;
        }
        return false;
    }

    @Override protected boolean onKeyEvent(KeyEvent event) {
        if (MainActivity.hasShortcutFocus()) {
            shortcut.reset();
        } else if (shortcut.matches(event)) {
            handler.post(this::scheduleCall);
        }
        return false;
    }

    private void scheduleCall() {
        SharedPreferences saved = CallAlarm.state(this);
        long time = saved.getLong("time", 0);
        long now = System.currentTimeMillis();
        if (time > now || (time > 0 && saved.getBoolean("repeat", false))
                || CallActivity.hasVisibleAnsweredCall() || SystemCallService.isBusy()
                || !CallAlarm.canSchedule(this)) return;

        int style = saved.getInt("appearance", saved.getInt("style", 0));
        boolean ready = style == SystemCallService.STYLE
                ? SystemCallService.isReady(this)
                : CallAlarm.canNotify(CallAlarm.notifications(this));
        if (!ready) return;

        String name = saved.getString(CALLER, saved.getString("name", "")).trim();
        String number = saved.getString(NUMBER, saved.getString("number", "")).trim();
        boolean full = saved.getBoolean(FULL, saved.getBoolean("full", true));
        try {
            CallAlarm.schedule(this, now + DELAY_MS, name.isEmpty() ? "Unknown caller" : name,
                    number, style, full, saved.getString("design", null), false);
        } catch (SecurityException ignored) {
            // Android can revoke exact alarm access after the readiness check.
        }
    }

    @Override public void onAccessibilityEvent(AccessibilityEvent event) {}

    @Override public void onInterrupt() {
        shortcut.reset();
        handler.removeCallbacksAndMessages(null);
    }

    @Override public void onDestroy() {
        onInterrupt();
        super.onDestroy();
    }
}
