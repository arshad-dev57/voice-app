package com.example.voice_recoginization_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.graphics.Rect
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.MethodChannel

class SimSelectionAccessibilityService : AccessibilityService() {
    
    companion object {
        private var instance: SimSelectionAccessibilityService? = null
        private var methodChannel: MethodChannel? = null
        private var targetSimName: String? = null
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }
        
        fun setTargetSim(simName: String) {
            targetSimName = simName
            instance?.performSimSelection()
        }
        
        fun getInstance(): SimSelectionAccessibilityService? = instance
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event?.let {
            if (it.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                it.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
                
                // Check if SIM selection dialog is shown
                if (isSimSelectionDialog(it)) {
                    performSimSelection()
                }
            }
        }
    }
    
    override fun onInterrupt() {
        instance = null
    }
    
    private fun isSimSelectionDialog(event: AccessibilityEvent): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        
        // Look for SIM selection dialog indicators
        val text = rootNode.text?.toString() ?: ""
        val contentDescription = rootNode.contentDescription?.toString() ?: ""
        
        // Check for common SIM dialog text
        val simDialogIndicators = listOf(
            "select sim",
            "choose sim",
            "sim card",
            "subscription",
            "zong",
            "jazz",
            "telenor",
            "ufone"
        )
        
        val lowerText = (text + " " + contentDescription).lowercase()
        
        // Check if any SIM dialog indicator is present
        for (indicator in simDialogIndicators) {
            if (lowerText.contains(indicator)) {
                return true
            }
        }
        
        // Also check for buttons with SIM names
        return findSimButtons(rootNode).isNotEmpty()
    }
    
    private fun performSimSelection() {
        val rootNode = rootInActiveWindow ?: return
        val simButtons = findSimButtons(rootNode)
        
        if (simButtons.isEmpty()) {
            return
        }
        
        targetSimName?.let { simName ->
            val targetButton = findSimButtonByName(simButtons, simName)
            if (targetButton != null) {
                clickNode(targetButton)
                methodChannel?.invokeMethod("onSimSelected", mapOf(
                    "sim" to simName,
                    "success" to true
                ))
            } else {
                // If exact match not found, try partial match
                val partialMatch = simButtons.firstOrNull { button ->
                    button.text?.toString()?.lowercase()?.contains(simName.lowercase()) == true ||
                    button.contentDescription?.toString()?.lowercase()?.contains(simName.lowercase()) == true
                }
                
                partialMatch?.let {
                    clickNode(it)
                    methodChannel?.invokeMethod("onSimSelected", mapOf(
                        "sim" to simName,
                        "success" to true
                    ))
                }
            }
        }
    }
    
    private fun findSimButtons(rootNode: AccessibilityNodeInfo): List<AccessibilityNodeInfo> {
        val buttons = mutableListOf<AccessibilityNodeInfo>()
        findButtonsRecursive(rootNode, buttons)
        return buttons
    }
    
    private fun findButtonsRecursive(node: AccessibilityNodeInfo, buttons: MutableList<AccessibilityNodeInfo>) {
        // Check if this node is a button
        if (node.isClickable || node.className?.toString()?.contains("Button") == true) {
            val text = node.text?.toString() ?: ""
            val contentDesc = node.contentDescription?.toString() ?: ""
            
            // Check if it contains SIM-related text
            val simKeywords = listOf("zong", "jazz", "telenor", "ufone", "sim", "subscription")
            val combinedText = (text + " " + contentDesc).lowercase()
            
            if (simKeywords.any { combinedText.contains(it) }) {
                buttons.add(node)
            }
        }
        
        // Recursively check children
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { findButtonsRecursive(it, buttons) }
        }
    }
    
    private fun findSimButtonByName(buttons: List<AccessibilityNodeInfo>, simName: String): AccessibilityNodeInfo? {
        val lowerSimName = simName.lowercase()
        
        for (button in buttons) {
            val text = button.text?.toString()?.lowercase() ?: ""
            val contentDesc = button.contentDescription?.toString()?.lowercase() ?: ""
            
            if (text.contains(lowerSimName) || contentDesc.contains(lowerSimName)) {
                return button
            }
        }
        
        return null
    }
    
    private fun clickNode(node: AccessibilityNodeInfo) {
        try {
            // Try using performAction first
            val result = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            if (!result) {
                // If performAction fails, try using gesture
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                
                if (!bounds.isEmpty) {
                    val clickX = bounds.centerX().toFloat()
                    val clickY = bounds.centerY().toFloat()
                    
                    val path = Path()
                    path.moveTo(clickX, clickY)
                    
                    val gestureBuilder = GestureDescription.Builder()
                    gestureBuilder.addStroke(GestureDescription.StrokeDescription(path, 0, 100))
                    
                    dispatchGesture(gestureBuilder.build(), null, null)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
