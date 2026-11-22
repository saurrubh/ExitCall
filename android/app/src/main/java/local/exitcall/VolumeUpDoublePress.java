package local.exitcall;

import android.view.KeyEvent;

final class VolumeUpDoublePress {
    private static final long WINDOW_MS = 500;
    private long lastPress = -1;

    boolean matches(KeyEvent event) {
        if (event.getAction() != KeyEvent.ACTION_DOWN) return false;

        int key = event.getKeyCode();
        if (key != KeyEvent.KEYCODE_VOLUME_UP || event.getRepeatCount() != 0) {
            if (key == KeyEvent.KEYCODE_VOLUME_UP || key == KeyEvent.KEYCODE_VOLUME_DOWN) reset();
            return false;
        }

        long time = event.getEventTime();
        boolean doublePress = lastPress >= 0 && time - lastPress <= WINDOW_MS;
        lastPress = doublePress ? -1 : time;
        return doublePress;
    }

    void reset() {
        lastPress = -1;
    }
}
