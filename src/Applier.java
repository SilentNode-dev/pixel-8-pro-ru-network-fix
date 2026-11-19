import android.os.IBinder;
import android.os.PersistableBundle;
import android.system.Os;
import java.io.File;
import java.io.FileInputStream;
import java.io.PrintStream;
import java.lang.reflect.Method;
import java.util.Iterator;
import org.json.JSONArray;
import org.json.JSONObject;

public class Applier {
    private static final String CONFIG_PATH = "/data/adb/carrier_ims/config.json";
    private static final String K_5G_ICON = "5g_icon_configuration_string";
    private static final String K_MCC_OVERRIDE = "country_mcc_override";
    private static final String K_NR_ADV_BANDS = "additional_nr_advanced_bands_int_array";
    private static final String K_NR_INC_LTE = "include_lte_for_nr_advanced_threshold_bandwidth_bool";
    private static final String K_NR_PCO = "nr_advanced_capable_pco_id_int";
    private static final String K_NR_THR_BW = "nr_advanced_threshold_bandwidth_khz_int";
    private static final String MCC_CN = "460";
    private static final int[] NR_BANDS_CN = new int[]{1, 2, 3, 5, 7, 8, 20, 28, 38, 40, 41, 66, 71, 77, 78, 79};
    private static final String NR_ICON_5GA = "connected_mmwave:5G_Plus,connected:5G,connected_rrc_idle:5G,not_restricted_rrc_idle:5G,not_restricted_rrc_con:5G";
    private static final int NR_THR_5GA = 0; // 0 = no minimum bandwidth threshold for 5G+ icon

    private static String readFile(File file) throws Exception {
        FileInputStream fis = new FileInputStream(file);
        byte[] data = new byte[(int) file.length()];
        int offset = 0;
        while (offset < data.length) {
            int read = fis.read(data, offset, data.length - offset);
            if (read < 0) break;
            offset += read;
        }
        fis.close();
        return new String(data, "UTF-8");
    }

    private static Object getService(String serviceName, String stubClass) throws Exception {
        Class<?> sm = Class.forName("android.os.ServiceManager");
        Method getServiceMethod = sm.getMethod("getService", String.class);
        IBinder binder = (IBinder) getServiceMethod.invoke(null, serviceName);
        if (binder == null) {
            return null;
        }
        String[] prefixes = new String[]{
            "android.telephony.",
            "com.android.internal.telephony.",
            "com.android.internal.telephony.ims."
        };
        for (String prefix : prefixes) {
            try {
                Class<?> cls = Class.forName(prefix + stubClass + "$Stub");
                Method asInterface = cls.getMethod("asInterface", IBinder.class);
                return asInterface.invoke(null, binder);
            } catch (ClassNotFoundException ignored) {
            }
        }
        return null;
    }

    private static boolean imsRegistered(Object telephony, int subId) {
        if (telephony == null) return false;
        try {
            Method m = telephony.getClass().getMethod("isImsRegistered", int.class);
            return (Boolean) m.invoke(telephony, subId);
        } catch (Exception e1) {
            try {
                Method m2 = telephony.getClass().getMethod("isImsRegisteredForSubscriber", int.class);
                return (Boolean) m2.invoke(telephony, subId);
            } catch (Exception e2) {
                try {
                    Method m3 = telephony.getClass().getMethod("isImsRegistered");
                    return (Boolean) m3.invoke(telephony);
                } catch (Exception ignored) {
                    return false;
                }
            }
        }
    }

    private static void overrideConfig(Object carrierConfigLoader, int subId, PersistableBundle bundle, boolean persistent) throws Exception {
        try {
            Method m = carrierConfigLoader.getClass().getMethod("overrideConfig", int.class, PersistableBundle.class, boolean.class);
            m.invoke(carrierConfigLoader, subId, bundle, persistent);
        } catch (NoSuchMethodException e) {
            Method m2 = carrierConfigLoader.getClass().getMethod("overrideConfig", int.class, PersistableBundle.class);
            m2.invoke(carrierConfigLoader, subId, bundle);
        }
    }

    private static PersistableBundle buildBundle(JSONObject slot) {
        PersistableBundle b = new PersistableBundle();

        if (slot.optBoolean("tiktokNetworkFix", false)) {
            b.putString("sim_country_iso_override_string", "cn");
            b.putString(K_MCC_OVERRIDE, MCC_CN);
        }

        if (slot.optBoolean("volte", true)) {
            b.putBoolean("carrier_volte_available_bool", true);
            b.putBoolean("editable_enhanced_4g_lte_bool", true);
            b.putBoolean("hide_enhanced_4g_lte_bool", false);
            b.putBoolean("hide_lte_plus_data_icon_bool", false);
        }

        if (slot.optBoolean("show4gForLte", true)) {
            b.putBoolean("show_4g_for_lte_data_icon_bool", true);
        }

        if (slot.optBoolean("vt", true)) {
            b.putBoolean("carrier_vt_available_bool", true);
        }

        if (slot.optBoolean("ut", true) || slot.optBoolean("ssOverUt", true)) {
            b.putBoolean("carrier_supports_ss_over_ut_bool", true);
        }

        if (slot.optBoolean("crossSim", true) || slot.optBoolean("crossSimIms", true)) {
            b.putBoolean("carrier_cross_sim_ims_available_bool", true);
            b.putBoolean("enable_cross_sim_calling_on_opportunistic_data_bool", true);
        }

        if (slot.optBoolean("vowifi", true) || slot.optBoolean("wfc", true)) {
            b.putBoolean("carrier_wfc_ims_available_bool", true);
            b.putBoolean("carrier_wfc_supports_wifi_only_bool", true);
            b.putBoolean("editable_wfc_mode_bool", true);
            b.putBoolean("editable_wfc_roaming_mode_bool", true);
            b.putBoolean("show_wifi_calling_icon_in_status_bar_bool", true);
            b.putInt("wfc_spn_format_idx_int", 1);
        }

        if (slot.optBoolean("vonr", true)) {
            b.putBoolean("vonr_enabled_bool", true);
            b.putBoolean("vonr_setting_visibility_bool", true);
        }

        if (slot.optBoolean("fiveGnr", true)) {
            b.putIntArray("carrier_nr_availabilities_int_array", new int[]{1, 2});
        }

        if (slot.optBoolean("fiveGPlusIcon", true)) {
            b.putInt(K_NR_THR_BW, NR_THR_5GA);
            b.putBoolean(K_NR_INC_LTE, false);
            b.putIntArray(K_NR_ADV_BANDS, NR_BANDS_CN);
            b.putString(K_5G_ICON, NR_ICON_5GA);
            b.putInt(K_NR_PCO, 0);
        }

        if (slot.optBoolean("fiveGThresholds", true)) {
            b.putIntArray("5g_nr_ssrsrp_thresholds_int_array", new int[]{-140, -115, -105, -90});
        }

        // RCS enhancements (Google Jibe dual-registration bypass)
        if (slot.optBoolean("rcs", true)) {
            b.putBoolean("carrier_supports_rcs_bool", true);
            b.putBoolean("carrier_single_registration_for_all_ims_services_enabled_bool", false);
            b.putBoolean("ims.rcs_request_forbidden_by_sip_489_bool", false);
        }

        // CDMA battery drain prevention
        if (slot.optBoolean("cdmaDisable", true)) {
            b.putBoolean("carrier_cdma_available_bool", false);
            b.putBoolean("support_cdma_1x_voice_calls_bool", false);
            b.putBoolean("support_pause_ims_calling_bool", false);
        }

        // Emergency call optimization
        if (slot.optBoolean("emergencyOptimization", true)) {
            b.putInt("emergency_notification_delay_int", 0);
        }

        // Custom properties override support
        JSONObject custom = slot.optJSONObject("custom");
        if (custom != null) {
            Iterator<String> keys = custom.keys();
            while (keys.hasNext()) {
                String key = keys.next();
                Object val = custom.opt(key);
                if (val instanceof Boolean) {
                    b.putBoolean(key, (Boolean) val);
                } else if (val instanceof Integer) {
                    b.putInt(key, (Integer) val);
                } else if (val instanceof String) {
                    b.putString(key, (String) val);
                }
            }
        }

        return b;
    }

    public static void main(String[] args) {
        String action = args.length > 0 ? args[0] : "apply";
        File configFile = new File(CONFIG_PATH);

        if ("status".equals(action)) {
            try {
                Object isub = getService("isub", "ISub");
                Object phone = getService("phone", "ITelephony");
                JSONObject res = new JSONObject();
                JSONArray slotsArr = new JSONArray();

                for (int slot = 0; slot < 2; slot++) {
                    int subId = -1;
                    if (isub != null) {
                        try {
                            Method getSubIdMethod = isub.getClass().getMethod("getSubId", int.class);
                            Object subRes = getSubIdMethod.invoke(isub, slot);
                            if (subRes instanceof int[]) {
                                int[] arr = (int[]) subRes;
                                if (arr.length > 0) subId = arr[0];
                            } else if (subRes instanceof Integer) {
                                subId = (Integer) subRes;
                            }
                        } catch (Exception ignored) {
                        }
                    }
                    JSONObject slotObj = new JSONObject();
                    slotObj.put("slotIndex", slot);
                    slotObj.put("subId", subId);
                    slotObj.put("imsRegistered", imsRegistered(phone, subId));
                    slotsArr.put(slotObj);
                }
                res.put("ok", true);
                res.put("slots", slotsArr);
                System.out.println(res.toString());
                return;
            } catch (Exception e) {
                System.out.println("{\"ok\":false,\"error\":\"" + e.getMessage() + "\"}");
                return;
            }
        }

        if (!configFile.exists()) {
            System.out.println("{\"ok\":false,\"error\":\"no config file\"}");
            return;
        }

        try {
            String jsonStr = readFile(configFile);
            JSONObject root = new JSONObject(jsonStr);
            JSONObject slots = root.optJSONObject("slots");
            if (slots == null || slots.length() == 0) {
                System.out.println("{\"ok\":false,\"error\":\"no slots configured\"}");
                return;
            }

            // Adopt shell permission identity to call overrideConfig
            Object am = getService("activity", "IActivityManager");
            if (am != null) {
                try {
                    Method startIdentity = am.getClass().getMethod("startDelegateShellPermissionIdentity", int.class, String[].class);
                    startIdentity.invoke(am, Os.getuid(), (Object) null);
                } catch (Exception ignored) {
                }
            }

            Object cc = getService("carrier_config", "ICarrierConfigLoader");
            if (cc == null) {
                System.out.println("{\"ok\":false,\"error\":\"carrier_config service unavailable\"}");
                return;
            }

            Object isub = getService("isub", "ISub");
            if (isub == null) {
                System.out.println("{\"ok\":false,\"error\":\"isub service unavailable\"}");
                return;
            }

            Object phone = getService("phone", "ITelephony");

            JSONArray results = new JSONArray();
            Iterator<String> slotKeys = slots.keys();

            while (slotKeys.hasNext()) {
                String slotKey = slotKeys.next();
                int slotIndex = Integer.parseInt(slotKey);
                JSONObject slotCfg = slots.getJSONObject(slotKey);

                int subId = -1;
                try {
                    Method getSubIdMethod = isub.getClass().getMethod("getSubId", int.class);
                    Object subRes = getSubIdMethod.invoke(isub, slotIndex);
                    if (subRes instanceof int[]) {
                        int[] arr = (int[]) subRes;
                        if (arr.length > 0) subId = arr[0];
                    } else if (subRes instanceof Integer) {
                        subId = (Integer) subRes;
                    }
                } catch (Exception ignored) {
                }

                JSONObject slotResult = new JSONObject();
                slotResult.put("slotIndex", slotIndex);
                slotResult.put("subId", subId);

                if (subId < 0) {
                    slotResult.put("applied", false);
                    slotResult.put("error", "no subId for slot " + slotIndex);
                    results.put(slotResult);
                    continue;
                }

                PersistableBundle bundle = buildBundle(slotCfg);
                try {
                    overrideConfig(cc, subId, bundle, false);
                    slotResult.put("applied", true);
                } catch (Exception ex) {
                    slotResult.put("applied", false);
                    Throwable cause = ex.getCause() != null ? ex.getCause() : ex;
                    slotResult.put("error", cause.toString());
                    cause.printStackTrace();
                }

                slotResult.put("imsRegistered", imsRegistered(phone, subId));
                results.put(slotResult);
            }

            // Drop shell permission identity
            if (am != null) {
                try {
                    Method stopIdentity = am.getClass().getMethod("stopDelegateShellPermissionIdentity");
                    stopIdentity.invoke(am);
                } catch (Exception ignored) {
                }
            }

            JSONObject out = new JSONObject();
            out.put("ok", true);
            out.put("lastApplyMillis", System.currentTimeMillis());
            out.put("slots", results);
            System.out.println(out.toString());

        } catch (Exception e) {
            System.out.println("{\"ok\":false,\"error\":\"" + e.getMessage() + "\"}");
        }
    }
}
