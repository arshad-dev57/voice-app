package com.example.voice_recoginization_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.MethodChannel

class SimSelectionAccessibilityService : AccessibilityService() {
    
    companion object {
        private var instance: SimSelectionAccessibilityService? = null
        private var methodChannel: MethodChannel? = null
        private var targetSimName: String? = null
        private const val TAG = "SimSelectionAccess"
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }
        
        fun setTargetSim(simName: String) {
            targetSimName = simName
            instance?.performSimSelection()
        }

        fun clearTargetSim() {
            targetSimName = null
        }
        
        fun getInstance(): SimSelectionAccessibilityService? = instance
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "SimSelectionAccessibilityService connected")
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event ?: return
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            
            if (isSimSelectionDialog(event)) {
                Log.d(TAG, "SIM selection dialog detected! Auto-selecting SIM...")
                performSimSelection()
            }
        }
    }
    
    override fun onInterrupt() {
        instance = null
    }
    
    private fun isSimSelectionDialog(event: AccessibilityEvent): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        
        val text = rootNode.text?.toString() ?: ""
        val contentDescription = rootNode.contentDescription?.toString() ?: ""
        val lowerText = (text + " " + contentDescription).lowercase()
        
        val simDialogIndicators = listOf(
            "select sim",
            "choose sim",
            "call with",
            "make call with",
            "choose a sim",
            "select a sim",
            "sim card",
            "subscription",
            "zong",
            "jazz",
            "telenor",
            "ufone"
        )
        
        for (indicator in simDialogIndicators) {
            if (lowerText.contains(indicator)) {
                return true
            }
        }
        
        return findSimButtons(rootNode).isNotEmpty()
    }
    
    private fun performSimSelection() {
        val rootNode = rootInActiveWindow ?: return
        val simButtons = findSimButtons(rootNode)
        
        if (simButtons.isEmpty()) {
            return
        }
        
        val simName = targetSimName
        if (!simName.isNullOrBlank()) {
            val targetButton = findSimButtonByName(simButtons, simName)
            if (targetButton != null) {
                Log.d(TAG, "Clicking target SIM button: $simName")
                clickNode(targetButton)
                targetSimName = null
                return
            }
            
            val partialMatch = simButtons.firstOrNull { button ->
                button.text?.toString()?.lowercase()?.contains(simName.lowercase()) == true ||
                button.contentDescription?.toString()?.lowercase()?.contains(simName.lowercase()) == true
            }
            if (partialMatch != null) {
                Log.d(TAG, "Clicking partial match target SIM button: $simName")
                clickNode(partialMatch)
                targetSimName = null
                return
            }
        }
        
        // DEFAULT BEHAVIOR FOR BLIND USERS:
        // If no specific SIM was requested (or matched), automatically click the FIRST SIM option!
        // This instantly bypasses the "Select SIM" dialog so the call proceeds hands-free on the default SIM.
        val defaultSimButton = simButtons.firstOrNull()
        if (defaultSimButton != null) {
            Log.d(TAG, "Auto-clicking default (first) SIM button for hands-free calling")
            clickNode(defaultSimButton)
            targetSimName = null
        }
    }
    
    private fun findSimButtons(rootNode: AccessibilityNodeInfo): List<AccessibilityNodeInfo> {
        val buttons = mutableListOf<AccessibilityNodeInfo>()
        findButtonsRecursive(rootNode, buttons)
        return buttons
    }
    
    private fun findButtonsRecursive(node: AccessibilityNodeInfo, buttons: MutableList<AccessibilityNodeInfo>) {
        if (node.isClickable || node.className?.toString()?.contains("Button") == true) {
            val text = node.text?.toString() ?: ""
            val contentDesc = node.contentDescription?.toString() ?: ""
            val combinedText = (text + " " + contentDesc).lowercase()
            
            val simKeywords = listOf(
                "zong", "jazz", "telenor", "ufone", "sim", "subscription",
                "sim 1", "sim 2", "sim1", "sim2", "slot 1", "slot 2", "card 1", "card 2"
            )
            
            if (simKeywords.any { combinedText.contains(it) }) {
                buttons.add(node)
            }
        }
        
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { findButtonsRecursive(it, buttons) }
        }
    }
    
    private fun findSimButtonByName(buttons: List<AccessibilityNodeInfo>, simName: String): AccessibilityNodeInfo? {
        val lowerSimName = simName.lowercase()
        for (button in buttons) {
            val text = button.text?.toString()?.lowercase() ?: ""
            val contentDesc = button.contentDescription?.toString() ?: ""
            if (text.contains(lowerSimName) || contentDesc.contains(lowerSimName)) {
                return button
            }
        }
        return null
    }
    
    private fun clickNode(node: AccessibilityNodeInfo) {
        try {
            val result = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            if (!result) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                if (!bounds.isEmpty) {
                    val clickX = bounds.centerX().toFloat()
                    val clickY = bounds.centerY().toFloat()
                    val path = Path().apply { moveTo(clickX, clickY) }
                    val gestureBuilder = GestureDescription.Builder()
                    gestureBuilder.addStroke(GestureDescription.StrokeDescription(path, 0, 100))
                    dispatchGesture(gestureBuilder.build(), null, null)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "clickNode error: ${e.message}")
        }
    }
}
