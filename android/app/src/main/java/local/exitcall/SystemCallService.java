package local.exitcall;

import android.content.ComponentName;
import android.content.Context;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.telecom.Connection;
import android.telecom.ConnectionRequest;
import android.telecom.ConnectionService;
import android.telecom.DisconnectCause;
import android.telecom.PhoneAccount;
import android.telecom.PhoneAccountHandle;
import android.telecom.TelecomManager;

public final class SystemCallService extends ConnectionService {
    static final int STYLE = 5;
    private static final String ACCOUNT_ID = "exit-call-simulated";
    private static final String SCHEME = "exitcall";
    private static final String REGISTERED = "system_account_registered";
    private static final String CALLER = "local.exitcall.CALLER";
    private static final String EXPIRES = "local.exitcall.EXPIRES";
    private static final String NEXT_REPEAT = "local.exitcall.NEXT_REPEAT";
    private static SimulatedConnection current;
    private static long pendingExpires;

    private static PhoneAccountHandle account(Context context) {
        return new PhoneAccountHandle(new ComponentName(context, SystemCallService.class), ACCOUNT_ID);
    }

    static boolean register(Context context) {
        TelecomManager telecom = context.getSystemService(TelecomManager.class);
        try {
            if (telecom == null || telecom.getDefaultDialerPackage() == null) return false;
            telecom.registerPhoneAccount(PhoneAccount.builder(account(context), "Exit Call")
                    .setCapabilities(PhoneAccount.CAPABILITY_CALL_PROVIDER)
                    .setShortDescription("Simulated incoming calls")
                    // Keep Exit Call out of the choices for dialing a telephone number.
                    .addSupportedUriScheme(SCHEME)
                    .build());
            CallAlarm.state(context).edit().putBoolean(REGISTERED, true).apply();
            return true;
        } catch (SecurityException | UnsupportedOperationException | IllegalArgumentException error) {
            return false;
        }
    }

    static boolean isReady(Context context) {
        TelecomManager telecom = context.getSystemService(TelecomManager.class);
        PhoneAccountHandle handle = account(context);
        try {
            if (telecom == null || telecom.getDefaultDialerPackage() == null) return false;
            if (Build.VERSION.SDK_INT >= 35) {
                for (PhoneAccount phoneAccount : telecom.getRegisteredPhoneAccounts()) {
                    if (handle.equals(phoneAccount.getAccountHandle())) return phoneAccount.isEnabled();
                }
                return false;
            }
            if (Build.VERSION.SDK_INT < 31) {
                PhoneAccount phoneAccount = telecom.getPhoneAccount(handle);
                return phoneAccount != null && phoneAccount.isEnabled();
            }
        } catch (SecurityException | UnsupportedOperationException error) {
            return false;
        }
        // Android 12 to 14 require phone-number access to read even our own account.
        // Telecom checks whether the account is enabled when we submit a call.
        return CallAlarm.state(context).getBoolean(REGISTERED, false);
    }

    static boolean isBusy() {
        return current != null || pendingExpires > SystemClock.elapsedRealtime();
    }

    static boolean ring(Context context, String name, String number, long nextRepeat) {
        if (isBusy() || !isReady(context)) return false;

        String caller = name == null || name.isEmpty() ? "Unknown caller" : name;
        // A local address lets the Phone app display a name without a number.
        Uri address = number == null || number.isEmpty()
                ? Uri.fromParts(SCHEME, caller, null)
                : Uri.fromParts(PhoneAccount.SCHEME_TEL, number, null);
        Bundle extras = new Bundle();
        pendingExpires = SystemClock.elapsedRealtime() + CallAlarm.RING_MS;
        extras.putString(CALLER, caller);
        extras.putLong(EXPIRES, pendingExpires);
        extras.putLong(NEXT_REPEAT, nextRepeat);
        extras.putParcelable(TelecomManager.EXTRA_INCOMING_CALL_ADDRESS, address);
        CallAlarm.state(context).edit().remove("system_call_failed").apply();
        try {
            context.getSystemService(TelecomManager.class).addNewIncomingCall(account(context), extras);
            return true;
        } catch (SecurityException | UnsupportedOperationException | IllegalArgumentException error) {
            pendingExpires = 0;
            return false;
        }
    }

    static void stopRepeatingRing() {
        if (current != null && current.repeating && current.getState() == Connection.STATE_RINGING) {
            current.finish(DisconnectCause.CANCELED);
        }
    }

    private boolean isCurrentRequest(long nextRepeat) {
        if (nextRepeat == 0) return true;
        SharedPreferences saved = CallAlarm.state(this);
        return saved.getBoolean("repeat", false) && saved.getLong("time", 0) == nextRepeat;
    }

    @Override public Connection onCreateIncomingConnection(
            PhoneAccountHandle connectionManagerPhoneAccount, ConnectionRequest request) {
        Bundle extras = request.getExtras();
        long expires = extras == null ? 0 : extras.getLong(EXPIRES);
        if (pendingExpires == expires) pendingExpires = 0;
        long remaining = expires - SystemClock.elapsedRealtime();
        long nextRepeat = extras == null ? 0 : extras.getLong(NEXT_REPEAT);
        if (remaining <= 0 || current != null || !isCurrentRequest(nextRepeat)) {
            return Connection.createFailedConnection(new DisconnectCause(DisconnectCause.CANCELED));
        }
        String name = extras.getString(CALLER, "Unknown caller");
        current = new SimulatedConnection(request.getAddress(), name, remaining, nextRepeat != 0);
        return current;
    }

    @Override public void onCreateIncomingConnectionFailed(
            PhoneAccountHandle connectionManagerPhoneAccount, ConnectionRequest request) {
        Bundle extras = request.getExtras();
        if (extras == null) return;
        if (pendingExpires == extras.getLong(EXPIRES)) pendingExpires = 0;
        if (isCurrentRequest(extras.getLong(NEXT_REPEAT))) {
            CallAlarm.state(this).edit().putBoolean("system_call_failed", true).apply();
        }
    }

    @Override public Connection onCreateOutgoingConnection(
            PhoneAccountHandle connectionManagerPhoneAccount, ConnectionRequest request) {
        return Connection.createFailedConnection(new DisconnectCause(DisconnectCause.ERROR));
    }

    @Override public void onDestroy() {
        if (current != null) current.finish(DisconnectCause.ERROR);
        super.onDestroy();
    }

    private static final class SimulatedConnection extends Connection {
        private final Handler handler = new Handler(Looper.getMainLooper());
        private final Runnable timeout = () -> finish(DisconnectCause.MISSED);
        private final boolean repeating;

        SimulatedConnection(Uri address, String name, long remaining, boolean repeating) {
            this.repeating = repeating;
            setAddress(address, address == null
                    ? TelecomManager.PRESENTATION_UNKNOWN : TelecomManager.PRESENTATION_ALLOWED);
            setCallerDisplayName(name, TelecomManager.PRESENTATION_ALLOWED);
            setAudioModeIsVoip(true);
            setConnectionCapabilities(CAPABILITY_HOLD | CAPABILITY_SUPPORT_HOLD);
            setRinging();
            handler.postDelayed(timeout, remaining);
        }

        @Override public void onAnswer(int videoState) { onAnswer(); }

        @Override public void onAnswer() {
            if (getState() == STATE_RINGING) {
                handler.removeCallbacks(timeout);
                setActive();
            }
        }

        @Override public void onHold() {
            if (getState() == STATE_ACTIVE) setOnHold();
        }

        @Override public void onUnhold() {
            if (getState() == STATE_HOLDING) setActive();
        }

        @Override public void onReject() { finish(DisconnectCause.REJECTED); }

        @Override public void onReject(int reason) { onReject(); }

        @Override public void onReject(String replyMessage) { onReject(); }

        @Override public void onDisconnect() { finish(DisconnectCause.LOCAL); }

        @Override public void onAbort() { finish(DisconnectCause.CANCELED); }

        private void finish(int cause) {
            if (getState() == STATE_DISCONNECTED) return;
            handler.removeCallbacks(timeout);
            setDisconnected(new DisconnectCause(cause));
            destroy();
            if (current == this) current = null;
        }
    }
}
