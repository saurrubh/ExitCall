package local.exitcall;

import android.net.Uri;
import android.os.Bundle;
import android.view.WindowManager;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public final class CallActivity extends FlutterActivity {
    @Override protected void onCreate(Bundle saved) {
        if (android.os.Build.VERSION.SDK_INT < 27) {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);
        }
        super.onCreate(saved);
    }

    @Override public String getInitialRoute() {
        return new Uri.Builder().path("/call")
                .appendQueryParameter("name", getIntent().getStringExtra("name"))
                .appendQueryParameter("number", getIntent().getStringExtra("number"))
                .appendQueryParameter("style", Integer.toString(getIntent().getIntExtra("style", 0)))
                .appendQueryParameter("expires", Long.toString(getIntent().getLongExtra("expires", 0)))
                .appendQueryParameter("design", getIntent().getStringExtra("design"))
                .build().toString();
    }

    @Override public void configureFlutterEngine(FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), MainActivity.CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "silence":
                            CallAlarm.notifications(this).cancel(CallAlarm.ALERT);
                            result.success(null);
                            break;
                        case "finish":
                            CallAlarm.notifications(this).cancel(CallAlarm.ALERT);
                            result.success(null);
                            finish();
                            break;
                        default:
                            result.notImplemented();
                    }
                });
    }
}
