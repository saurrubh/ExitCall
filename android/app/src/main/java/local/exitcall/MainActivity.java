package local.exitcall;

import android.Manifest;
import android.app.NotificationManager;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.telecom.TelecomManager;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;
import java.util.Map;

public class MainActivity extends FlutterActivity {
    static final String CHANNEL = "local.exitcall/calls";
    private static final int REQUEST_NOTIFICATIONS = 1;
    private MethodChannel.Result notificationRequest;

    @Override public void configureFlutterEngine(FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        MethodChannel channel = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler((call, result) -> {
            try {
                switch (call.method) {
                    case "status":
                        result.success(status());
                        break;
                    case "saveDesign":
                        CallAlarm.state(this).edit()
                                .putString("design", call.argument("design"))
                                .putInt("appearance", call.<Integer>argument("appearance")).apply();
                        result.success(null);
                        break;
                    case "setAppearance":
                        CallAlarm.state(this).edit().putInt("appearance", (Integer) call.arguments).apply();
                        result.success(null);
                        break;
                    case "openPhoneAccounts":
                        if (!SystemCallService.register(this)) {
                            result.error("SYSTEM_PHONE", "This device has no compatible Phone app.", null);
                            break;
                        }
                        try {
                            startActivity(new Intent(TelecomManager.ACTION_CHANGE_PHONE_ACCOUNTS));
                            result.success(null);
                        } catch (android.content.ActivityNotFoundException error) {
                            result.error("SYSTEM_PHONE", "Open Calling accounts in the Phone app to enable Exit Call.", null);
                        }
                        break;
                    case "previewSystemCall":
                        if (SystemCallService.isBusy()) {
                            result.error("SYSTEM_PHONE", "End the current Exit Call first.", null);
                        } else if (SystemCallService.ring(this, call.argument("name"), call.argument("number"), 0)) {
                            result.success(null);
                        } else {
                            result.error("SYSTEM_PHONE", "Enable Exit Call in Calling accounts, then try again.", null);
                        }
                        break;
                    case "schedule":
                        if (Integer.valueOf(SystemCallService.STYLE).equals(call.argument("style"))
                                && !SystemCallService.isReady(this)) {
                            result.error("SYSTEM_PHONE", "Enable Exit Call in Calling accounts first.", null);
                            break;
                        }
                        Number time = call.argument("time");
                        if (time == null || time.longValue() <= System.currentTimeMillis()) {
                            result.error("PAST_TIME", "Choose a future time.", null);
                            break;
                        }
                        CallAlarm.schedule(this, time.longValue(), call.argument("name"),
                                call.argument("number"), call.<Integer>argument("style"),
                                call.<Boolean>argument("full"), call.argument("design"),
                                Boolean.TRUE.equals(call.argument("repeat")));
                        result.success(status());
                        break;
                    case "cancel":
                        CallAlarm.cancel(this);
                        result.success(status());
                        break;
                    case "notifications":
                        enableNotifications(result);
                        break;
                    case "alarms":
                        openSettings(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM);
                        result.success(null);
                        break;
                    case "fullScreen":
                        openSettings(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT);
                        result.success(null);
                        break;
                    default:
                        result.notImplemented();
                }
            } catch (SecurityException | android.content.ActivityNotFoundException error) {
                result.error("ANDROID_SETTINGS", "Check the app’s permissions in Android settings.", null);
            }
        });
    }

    private Map<String, Object> status() {
        SharedPreferences saved = CallAlarm.state(this);
        NotificationManager manager = CallAlarm.notifications(this);
        Map<String, Object> status = new HashMap<>();
        status.put("notifications", manager.areNotificationsEnabled()
                && manager.getNotificationChannel(CallAlarm.CHANNEL).getImportance() != NotificationManager.IMPORTANCE_NONE);
        status.put("alarms", CallAlarm.canSchedule(this));
        status.put("systemPhoneReady", SystemCallService.isReady(this));
        status.put("systemCallFailed", saved.getBoolean("system_call_failed", false));
        status.put("fullScreen", Build.VERSION.SDK_INT < 34 || manager.canUseFullScreenIntent());
        status.put("time", saved.getLong("time", 0));
        status.put("repeat", saved.getBoolean("repeat", false));
        status.put("name", saved.getString("name", ""));
        status.put("number", saved.getString("number", ""));
        status.put("style", saved.getInt("appearance", saved.getInt("style", 0)));
        status.put("full", saved.getBoolean("full", true));
        status.put("design", saved.getString("design", null));
        return status;
    }

    private void openSettings(String action) {
        startActivity(new Intent(action, Uri.parse("package:" + getPackageName())));
    }

    private void enableNotifications(MethodChannel.Result result) {
        SharedPreferences saved = CallAlarm.state(this);
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED && !saved.getBoolean("asked", false)) {
            if (notificationRequest != null) {
                result.success(false);
                return;
            }
            notificationRequest = result;
            saved.edit().putBoolean("asked", true).apply();
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, REQUEST_NOTIFICATIONS);
        } else {
            startActivity(new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, getPackageName()));
            result.success(false);
        }
    }

    @Override public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grants) {
        super.onRequestPermissionsResult(requestCode, permissions, grants);
        if (requestCode == REQUEST_NOTIFICATIONS && notificationRequest != null) {
            notificationRequest.success(grants.length > 0 && grants[0] == PackageManager.PERMISSION_GRANTED);
            notificationRequest = null;
        }
    }
}
