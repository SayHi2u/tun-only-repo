package com.codewhale.netprobe;

import android.app.Activity;
import android.content.Context;
import android.graphics.Typeface;
import android.net.ConnectivityManager;
import android.net.LinkAddress;
import android.net.LinkProperties;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Bundle;
import android.text.InputType;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.InterfaceAddress;
import java.net.NetworkInterface;
import java.net.Socket;
import java.util.Collections;

public class MainActivity extends Activity {
    private TextView statusView;
    private TextView outputView;
    private EditText targetInput;
    private Button refreshButton;
    private Button testButton;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        buildUi();
        refreshNetworkInfo();
    }

    private int dp(int value) {
        return Math.round(getResources().getDisplayMetrics().density * value);
    }

    private void buildUi() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        int pad = dp(20);
        root.setPadding(pad, pad, pad, pad);
        scroll.addView(root);

        TextView title = new TextView(this);
        title.setText("Net Probe");
        title.setTextSize(26);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        root.addView(title);

        TextView subtitle = new TextView(this);
        subtitle.setText("显示本 app 当前使用的默认网络接口，并可发起一次无害的测试连接。");
        subtitle.setTextSize(14);
        subtitle.setPadding(0, dp(6), 0, dp(14));
        root.addView(subtitle);

        statusView = new TextView(this);
        statusView.setTextSize(14);
        statusView.setTypeface(Typeface.MONOSPACE);
        statusView.setTextIsSelectable(true);
        root.addView(statusView);

        TextView targetLabel = new TextView(this);
        targetLabel.setText("测试目标（IP:端口）");
        targetLabel.setTextSize(14);
        targetLabel.setTypeface(Typeface.DEFAULT_BOLD);
        targetLabel.setPadding(0, dp(16), 0, dp(6));
        root.addView(targetLabel);

        targetInput = new EditText(this);
        targetInput.setText("223.5.5.5:443");
        targetInput.setSingleLine(true);
        targetInput.setInputType(InputType.TYPE_CLASS_TEXT);
        targetInput.setTextSize(14);
        root.addView(targetInput);

        TextView targetHint = new TextView(this);
        targetHint.setText("大陆推荐 223.5.5.5:443（阿里 DoH）；备选 119.29.29.29:443、180.76.76.76:443。\n"
                + "建议填 IP 字面量，避免 DNS 和代理解析带来的变量。");
        targetHint.setTextSize(12);
        targetHint.setPadding(0, dp(6), 0, dp(4));
        root.addView(targetHint);

        LinearLayout buttons = new LinearLayout(this);
        buttons.setOrientation(LinearLayout.HORIZONTAL);
        buttons.setPadding(0, dp(14), 0, dp(14));
        root.addView(buttons);

        refreshButton = new Button(this);
        refreshButton.setText("刷新网络状态");
        refreshButton.setAllCaps(false);
        buttons.addView(refreshButton, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        testButton = new Button(this);
        testButton.setText("测试出口");
        testButton.setAllCaps(false);
        buttons.addView(testButton, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        TextView outputLabel = new TextView(this);
        outputLabel.setText("测试结果");
        outputLabel.setTextSize(16);
        outputLabel.setTypeface(Typeface.DEFAULT_BOLD);
        root.addView(outputLabel);

        outputView = new TextView(this);
        outputView.setText("点击“测试出口”后才会发起一次 TCP 连接。");
        outputView.setTextSize(13);
        outputView.setTypeface(Typeface.MONOSPACE);
        outputView.setTextIsSelectable(true);
        outputView.setPadding(0, dp(8), 0, dp(8));
        root.addView(outputView);

        TextView warning = new TextView(this);
        warning.setText("结果怎么看：\n"
                + "• 成功 + 本地 IP 10.10.14.1 + 出口 tun0：本 app 的流量走了 VPN，符合预期。\n"
                + "• 成功 + 192.168.x.x + 出口 wlan0：走了 Wi-Fi，模块规则没有作用到本 app。\n"
                + "• 成功 + 10.x/100.x + 出口 rmnet/ccmni：走了移动数据，模块规则没有作用到本 app。\n"
                + "• 成功 + 出口 tun1：走了其他 tun，不是 v2rayNG 的 tun0。\n"
                + "• 失败 + EPERM/EACCES/ECONNREFUSED：可能是规则 REJECT；VPN 关闭时通常是预期。\n"
                + "• 失败 + SocketTimeout：目标不可达/被墙/端口过滤，换一个国内目标再试。\n\n"
                + "注意：\n"
                + "• 本 app 只能看到它自己的默认网络和测试连接出口，看不到微博/抖音的流量。\n"
                + "• 要让它代表目标 app，请把本 app 也加入模块的 packages.conf，并在 v2rayNG 分应用代理中勾选它。\n"
                + "• 打开本 app 不会自动联网；只有点击“测试出口”才会发起一次 TCP 连接，不携带业务数据。");
        warning.setTextSize(13);
        warning.setPadding(0, dp(18), 0, dp(8));
        root.addView(warning);

        refreshButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                refreshNetworkInfo();
            }
        });
        testButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                runProbe();
            }
        });

        setContentView(scroll);
    }

    private String transports(NetworkCapabilities capabilities) {
        if (capabilities == null) {
            return "未知";
        }
        StringBuilder sb = new StringBuilder();
        if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) sb.append("Wi-Fi ");
        if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) sb.append("移动数据 ");
        if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) sb.append("VPN ");
        if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) sb.append("以太网 ");
        if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH)) sb.append("蓝牙 ");
        return sb.length() == 0 ? "未知" : sb.toString().trim();
    }

    private String linkAddresses(LinkProperties properties) {
        if (properties == null) {
            return "无";
        }
        StringBuilder sb = new StringBuilder();
        for (LinkAddress address : properties.getLinkAddresses()) {
            sb.append(address.getAddress().getHostAddress())
                    .append("/")
                    .append(address.getPrefixLength())
                    .append(" ");
        }
        return sb.length() == 0 ? "无" : sb.toString().trim();
    }

    private void refreshNetworkInfo() {
        StringBuilder sb = new StringBuilder();
        ConnectivityManager cm = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
        Network active = cm != null ? cm.getActiveNetwork() : null;
        LinkProperties lp = active != null && cm != null ? cm.getLinkProperties(active) : null;
        NetworkCapabilities nc = active != null && cm != null ? cm.getNetworkCapabilities(active) : null;

        sb.append("默认网络接口: ")
                .append(lp != null && lp.getInterfaceName() != null ? lp.getInterfaceName() : "无")
                .append("\n");
        sb.append("默认网络类型: ").append(transports(nc)).append("\n");
        sb.append("默认网络 IP: ").append(lp != null ? linkAddresses(lp) : "无").append("\n\n");
        sb.append("所有已启用接口:\n");

        try {
            for (NetworkInterface ni : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                if (!ni.isUp()) {
                    continue;
                }
                sb.append(ni.getName()).append(": ");
                for (InterfaceAddress address : ni.getInterfaceAddresses()) {
                    sb.append(address.getAddress().getHostAddress()).append(" ");
                }
                sb.append("\n");
            }
        } catch (Exception e) {
            sb.append("枚举失败: ").append(e).append("\n");
        }

        sb.append("\n提示: 默认网络接口是 Android 给本 app 选择的网络；VPN 捕获时通常是 tun0。");
        statusView.setText(sb.toString());
    }

    private void runProbe() {
        String raw = targetInput.getText().toString().trim();
        if (raw.isEmpty()) {
            raw = "223.5.5.5:443";
        }

        String host = raw;
        int port = 443;
        int idx = raw.lastIndexOf(':');
        if (idx > 0 && idx < raw.length() - 1) {
            host = raw.substring(0, idx);
            try {
                port = Integer.parseInt(raw.substring(idx + 1));
            } catch (NumberFormatException e) {
                outputView.setText("端口格式不正确: " + raw);
                return;
            }
        }
        if (port < 1 || port > 65535) {
            outputView.setText("端口超出范围: " + port);
            return;
        }

        final String targetHost = host;
        final int targetPort = port;
        outputView.setText("测试中...");

        new Thread(new Runnable() {
            @Override
            public void run() {
                long start = System.currentTimeMillis();
                String result;
                try (Socket socket = new Socket()) {
                    socket.connect(new InetSocketAddress(InetAddress.getByName(targetHost), targetPort), 3000);
                    InetAddress local = socket.getLocalAddress();
                    NetworkInterface ni = NetworkInterface.getByInetAddress(local);
                    long ms = System.currentTimeMillis() - start;
                    result = "结果: 成功\n"
                            + "目标: " + targetHost + ":" + targetPort + "\n"
                            + "本地 IP: " + local.getHostAddress() + "\n"
                            + "出口接口: " + (ni != null ? ni.getName() : "未知") + "\n"
                            + "耗时: " + ms + " ms\n\n"
                            + "如果出口接口是 tun0，说明本 app 的测试流量走了 VPN。\n"
                            + "如果出口接口是 wlan0/rmnet，说明这次测试走了物理网卡，模块规则没有作用到本 app。";
                } catch (Exception e) {
                    long ms = System.currentTimeMillis() - start;
                    result = "结果: 失败\n"
                            + "目标: " + targetHost + ":" + targetPort + "\n"
                            + "异常: " + e.getClass().getSimpleName() + "\n"
                            + (e.getMessage() != null ? e.getMessage() : "(无消息)") + "\n"
                            + "耗时: " + ms + " ms\n\n"
                            + "判断方法：\n"
                            + "• 如果 VPN 关闭、异常是 ECONNREFUSED/EPERM/EACCES，且本地源 IP 是 192.168.x.x 或 10.x，说明规则在本地 OUTPUT 层拒绝，数据没有发到物理网卡；这是模块生效的预期结果。\n"
                            + "• 如果 VPN 开启仍然失败，检查本 app 是否在 v2rayNG 分应用代理里被勾选、tun0 是否存在。\n"
                            + "• 如果是 SocketTimeout，先换一个国内目标再试。";
                }

                final String finalResult = result;
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        outputView.setText(finalResult);
                    }
                });
            }
        }).start();
    }
}
