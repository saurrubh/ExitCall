package local.exitcall;

import android.app.*;
import android.content.*;
import android.media.AudioAttributes;
import android.media.RingtoneManager;
import android.os.Build;

public final class CallAlarm extends BroadcastReceiver {
    static final String CHANNEL = "incoming_calls";
    static final String FIRE = "local.exitcall.FIRE";
    static final String DECLINE = "local.exitcall.DECLINE";
    static final int ALERT = 1;
    static final long RING_MS = 45_000;

    static SharedPreferences state(Context context) {
        return context.getSharedPreferences("calls", Context.MODE_PRIVATE);
    }

    static NotificationManager notifications(Context context) {
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        NotificationChannel channel = new NotificationChannel(CHANNEL, "Incoming calls",
                NotificationManager.IMPORTANCE_HIGH);
        channel.setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE),
                new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE).build());
        channel.enableVibration(true);
        manager.createNotificationChannel(channel);
        return manager;
    }

    static boolean canSchedule(Context context) {
        return Build.VERSION.SDK_INT < 31 ||
                context.getSystemService(AlarmManager.class).canScheduleExactAlarms();
    }

    static Intent screen(Context context, String name, String number, int style, long expires, String design) {
        return new Intent(context, CallActivity.class)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtra("name", name).putExtra("number", number)
                .putExtra("style", style).putExtra("expires", expires).putExtra("design", design);
    }

    private static PendingIntent alarm(Context context, long time) {
        return PendingIntent.getBroadcast(context, 1, new Intent(context, CallAlarm.class)
                .setAction(FIRE).putExtra("time", time),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    static void schedule(Context context, long time, String name, String number, int style,
                         boolean fullScreen, String design) {
        context.getSystemService(AlarmManager.class)
                .setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, alarm(context, time));
        state(context).edit().putLong("time", time).putString("name", name)
                .putString("number", number).putInt("style", style)
                .putBoolean("full", fullScreen).putString("scheduled_design", design).apply();
    }

    static void cancel(Context context) {
        state(context).edit().remove("time").remove("scheduled_design").apply();
        context.getSystemService(AlarmManager.class).cancel(alarm(context, 0));
    }

    @Override public void onReceive(Context context, Intent intent) {
        SharedPreferences saved = state(context);
        NotificationManager manager = notifications(context);
        if (DECLINE.equals(intent.getAction())) {
            manager.cancel(ALERT);
            return;
        }
        long time = saved.getLong("time", 0);
        if (!FIRE.equals(intent.getAction())) {
            if (time > System.currentTimeMillis() && canSchedule(context)) {
                context.getSystemService(AlarmManager.class)
                        .setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, alarm(context, time));
            }
            return;
        }
        if (time == 0 || time != intent.getLongExtra("time", 0)) return;
        String design = saved.getString("scheduled_design", null);
        saved.edit().remove("time").remove("scheduled_design").apply();
        String name = saved.getString("name", "Unknown caller");
        int style = saved.getInt("style", 0);
        PendingIntent open = PendingIntent.getActivity(context, 1,
                screen(context, name, saved.getString("number", ""), style,
                        System.currentTimeMillis() + RING_MS, design),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        PendingIntent decline = PendingIntent.getBroadcast(context, 2,
                new Intent(context, CallAlarm.class).setAction(DECLINE), PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder alert = new Notification.Builder(context, CHANNEL)
                .setSmallIcon(local.exitcall.R.drawable.phone).setContentTitle(name)
                .setContentText("Incoming call").setCategory(Notification.CATEGORY_CALL)
                .setVisibility(Notification.VISIBILITY_PUBLIC).setTimeoutAfter(RING_MS)
                .setContentIntent(open).setAutoCancel(true)
                .addAction(new Notification.Action.Builder(null, "Decline", decline).build())
                .addAction(new Notification.Action.Builder(null, "Open call", open).build());
        if (saved.getBoolean("full", true) &&
                (Build.VERSION.SDK_INT < 34 || manager.canUseFullScreenIntent())) {
            alert.setFullScreenIntent(open, true);
        }
        Notification ringing = alert.build();
        ringing.flags |= Notification.FLAG_INSISTENT;
        manager.notify(ALERT, ringing);
    }
}
