package com.qingheng.bodylog

import android.app.Activity
import android.os.Bundle
import android.content.res.Configuration
import android.graphics.Color
import android.view.View
import android.widget.ScrollView
import android.widget.TextView

/** Health Connect's permission-usage link must open the actual data policy. */
class PrivacyActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        val savedMode = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .getString("flutter.bodylog.appearance", "system")
        val dark = when (savedMode) {
            "dark" -> true
            "light" -> false
            else -> resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
        }
        setTheme(if (dark) android.R.style.Theme_Material_NoActionBar else android.R.style.Theme_Material_Light_NoActionBar)
        super.onCreate(savedInstanceState)
        val background = Color.parseColor(if (dark) "#111619" else "#F2F2F7")
        val foreground = Color.parseColor(if (dark) "#EEF2F3" else "#1D1D1F")
        window.statusBarColor = background
        window.navigationBarColor = background
        window.decorView.systemUiVisibility = if (dark) 0 else
            View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        val savedLanguage = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .getString("flutter.bodylog.language", "zh")
        val english = savedLanguage == "en" || (savedLanguage == "system" && resources.configuration.locales[0].language != "zh")
        title = if (english) "Poise · Health data policy" else "轻衡 · 健康数据说明"
        val text = TextView(this).apply {
            textSize = 18f
            setTextColor(foreground)
            setBackgroundColor(background)
            setPadding(32, 40, 32, 40)
            text = if (english) "Poise health data policy\n\n" +
                "Access: weight, body fat and height that you explicitly authorize.\n\n" +
                "Purpose: display your calendar and trends, and calculate BMI using height. Data is read when you tap sync or open the app with auto-sync enabled. Auto-sync can be turned off in Health data.\n\n" +
                "Storage: imported records and source IDs stay on this device. They are not uploaded, used for advertising or shared with third parties.\n\n" +
                "Control: revoke access in Health Connect. This does not remove local copies; remove those under Health data in Poise. Original system records are never modified or deleted.\n\n" +
                "Optional Keep connection: authorization and date-range queries go directly to Keep. Imported copies stay on device; login credentials use device secure storage and are excluded from backups.\n\n" +
                "Backup: data enters the clipboard only when you export it. Keep it secure. Uninstalling or clearing app data may erase records.\n\n" +
                "This test version does not provide medical diagnosis."
            else "轻衡健康数据说明\n\n" +
                "读取范围：你主动授权的体重、体脂率和身高。\n\n" +
                "用途：在本机显示测量日历、变化趋势，并用身高计算 BMI。点击同步或开启自动同步后打开应用时读取，可在健康数据页关闭自动同步。\n\n" +
                "保存：导入的记录和来源 ID 保存在当前设备，不上传服务器，不用于广告，也不向第三方分享。\n\n" +
                "控制：你可以在 Health Connect 中撤回权限。撤权不会自动删除已导入的本地副本；请在轻衡的健康数据页移除副本。轻衡不会修改或删除系统中的原始记录。\n\n" +
                "Keep连接：仅在你主动连接后向Keep发送授权和日期范围查询请求，导入副本保存在本机，登录凭据通过设备安全存储保存且不进入备份。\n\n" +
                "备份：只有你主动导出时数据才会进入剪贴板；请妥善保管。卸载应用或清理数据可能丢失记录。\n\n" +
                "本测试版本不提供医疗诊断。"
        }
        setContentView(ScrollView(this).apply { setBackgroundColor(background); addView(text) })
    }
}
