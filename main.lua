require "import"
import "android.content.Context"
import "android.content.Intent"
import "android.net.Uri"
import "android.provider.ContactsContract"
import "android.speech.SpeechRecognizer"
import "android.speech.RecognitionListener"
import "android.speech.RecognizerIntent"
import "android.os.Handler"
import "android.os.Looper"
import "android.content.pm.PackageManager"
import "android.hardware.camera2.*"
import "android.bluetooth.BluetoothAdapter"
import "android.media.AudioManager"
import "android.provider.Settings"
import "android.widget.*"
import "android.view.*"
import "android.content.IntentFilter"
import "android.os.BatteryManager"
import "android.app.SearchManager"
import "java.lang.System"
import "java.io.File"
import "android.app.ProgressDialog"
import "android.os.AsyncTask"
import "android.graphics.Typeface"
import "android.provider.MediaStore"
import "android.media.projection.MediaProjectionManager"
import "android.media.projection.MediaProjection"
import "android.media.MediaRecorder"
import "android.os.Environment"
import "android.view.WindowManager"
import "java.util.Locale"
import "android.accessibilityservice.AccessibilityService"
import "android.app.*"
import "android.speech.tts.TextToSpeech"
import "android.os.Vibrator"
import "android.os.VibrationEffect"
import "java.lang.String"
import "com.androlua.LuaDialog"
import "com.androlua.Http"

local GITHUB_RAW_URL = "https://raw.githubusercontent.com/tecno46-lang/Advance-voice-assistant-by-Tech-for-v-i-latest/main/"
local VERSION_URL = GITHUB_RAW_URL .. "version.txt"
local SCRIPT_URL = GITHUB_RAW_URL .. "main.lua"
local PLUGIN_PATH = "/storage/emulated/0/解说/Plugins/Advance voice assistant by tech for v i Develop by Muhammad hanzla v1.2/main.lua"
local updateInProgress = false
local updateDlg = nil
local updateAvailable = false
local autoCheckDone = false

local CONSTANTS = {
    VERSION = "1.3",
    PREF_NAME = "Hanzla_Final_Safety_V7_Enhanced",
    DELAYS = {
        SUPER_FAST = 80,
        VERY_FAST = 120,
        FAST = 200,
        SHORT = 300,
        MEDIUM = 500,
        NORMAL = 800,
        LONG = 1200,
        VERY_LONG = 2000
    }
}

local CURRENT_VERSION = CONSTANTS.VERSION

local WHATSAPP_PACKAGES = {
    messenger = "com.whatsapp",
    business = "com.whatsapp.w4b"
}

local WHATSAPP_PREF_ASK = "ask"
local WHATSAPP_PREF_MESSENGER = "messenger"
local WHATSAPP_PREF_BUSINESS = "business"

local WHATSAPP_PREF_KEY = "whatsapp_preference"
local VIBRATION_ENABLED_PREF_KEY = "vibration_enabled"
local TTS_ENGINE_PREF_KEY = "tts_engine_preference"
local CUSTOM_COMMANDS_KEY = "custom_commands_keywords"
local CONTACT_KEYWORDS_KEY = "contact_keywords_mapping"
local WELCOME_DIALOG_SHOWN_KEY = "welcome_dialog_shown"
local NOISY_MODE_PREF_KEY = "noisy_mode_enabled"

local fS = false
local settingsDialog, commandsDialog, whatsappSettingsDlg, communitiesDlg
local contactSelectionDialog, selectionDialog, contactKeywordsDialog

local lastCommandTime = 0
local currentContactSelection = nil

local mainSpeechRecognizer = nil
local isListening = false

local currentTTS = nil
local ttsEngines = {}
local ttsInitialized = false

local cachedServices = {}
local cachedPrefs = nil
local cachedEdit = nil
local contactKeywordCache = {}
local lastKeywordCacheClear = 0

local isFlashOn = false
local audioManager = nil
local isAudioFocusGranted = false

local DEFAULT_COMMANDS = {
    ["show menu"] = "show menu",
    ["show commands"] = "show commands",
    ["restart screen reader"] = "rs",
    ["turn off screen reader"] = "tf",
    ["current battery"] = "current battery",
    ["current time"] = "current time",
    ["current date"] = "current date",
    ["accessibility settings"] = "accessibility settings",
    ["how to use"] = "how to use",
    ["send now"] = "send now",
    ["uninstall"] = "uninstall",
    ["clear chat"] = "clear chat",
    ["delete from everyone"] = "delete from everyone",
    ["delete from me"] = "delete from me",
    ["delete now"] = "delete now",
    ["delete number"] = "delete number",
    ["application info"] = "application info",
    ["voice call"] = "voice call",
    ["video call"] = "video call",
    ["chat"] = "chat",
    ["call"] = "call",
    ["search on youtube"] = "search on youtube",
    ["search on spotify"] = "search on spotify",
    ["search on google"] = "search on google",
    ["search on play store"] = "search on play store",
    ["search song on youtube music"] = "search song on youtube music",
    ["open"] = "open",
    ["toggle bluetooth"] = "toggle bluetooth",
    ["toggle flashlight"] = "toggle flashlight",
    ["toggle mobile data"] = "toggle mobile data",
    ["wf"] = "wf",
    ["toggle silent mode"] = "toggle silent mode",
    ["silent"] = "silent",
    ["mute"] = "mute",
    ["only admin"] = "only admin",
    ["speech rate"] = "speech rate",
    ["mention all"] = "mention all",
    ["rename it"] = "rename it",
    ["talk with me"] = "talk with me",
    ["check update"] = "check update"
}

local mainHandler = luajava.new(Handler, Looper.getMainLooper())

local function createRunnable(func)
    return luajava.createProxy("java.lang.Runnable", { run = func })
end

function showToast(message)
    mainHandler.post(createRunnable(function()
        Toast.makeText(service, message, Toast.LENGTH_SHORT).show()
    end))
end

function checkUpdate(manual)
    if updateInProgress then 
        if manual then speak("Update already in progress") end
        return 
    end
    if manual then speak("Checking for updates") end
    Http.get(VERSION_URL, function(code, onlineVersion)
        if code == 200 and onlineVersion then
            onlineVersion = tostring(onlineVersion):match("^%s*(.-)%s*$")
            if onlineVersion and onlineVersion ~= CURRENT_VERSION then
                updateAvailable = true
                showUpdateDialog(onlineVersion)
            else
                if manual then
                    mainHandler.post(createRunnable(function()
                        speak("You are using the latest version " .. CURRENT_VERSION)
                        showToast("Already up to date")
                    end))
                end
            end
        else
            if manual then
                mainHandler.post(createRunnable(function()
                    speak("Failed to check for updates")
                    showToast("Connection error")
                end))
            end
        end
    end)
end

function showUpdateDialog(onlineVersion)
    mainHandler.post(createRunnable(function()
        updateDlg = LuaDialog(service)
        updateDlg.setTitle("Update Available!")
        updateDlg.setMessage("New version " .. onlineVersion .. " is available.\nCurrent version: " .. CURRENT_VERSION .. "\n\nWould you like to update now?")
        updateDlg.setButton("Update Now", function()
            updateDlg.dismiss()
            downloadAndInstallUpdate()
        end)
        updateDlg.setButton2("Later", function()
            updateDlg.dismiss()
            speak("Update cancelled")
        end)
        updateDlg.show()
    end))
end

function downloadAndInstallUpdate()
    updateInProgress = true
    speak("Downloading update")
    Thread(createRunnable(function()
        Http.get(SCRIPT_URL, function(code, newContent)
            if code == 200 and newContent then
                local tempPath = PLUGIN_PATH .. ".temp_update"
                local backupPath = PLUGIN_PATH .. ".backup"
                local function restoreFromBackup()
                    if File(backupPath).exists() then
                        os.rename(backupPath, PLUGIN_PATH)
                        return true
                    end
                    return false
                end
                local function cleanupFiles()
                    pcall(function() os.remove(tempPath) end)
                    pcall(function() os.remove(backupPath) end)
                end
                if File(PLUGIN_PATH).exists() then
                    os.rename(PLUGIN_PATH, backupPath)
                end
                local f = io.open(tempPath, "w")
                if f then
                    f:write(newContent)
                    f:close()
                    local success = pcall(function()
                        os.remove(PLUGIN_PATH)
                        os.rename(tempPath, PLUGIN_PATH)
                    end)
                    if success then
                        cleanupFiles()
                        updateAvailable = false
                        mainHandler.post(createRunnable(function()
                            speak("Update successful")
                            local successDialog = LuaDialog(service)
                            successDialog.setTitle("Update Successful")
                            successDialog.setMessage("Update completed successfully!\n\nPlease restart the plugin to use the new version.")
                            successDialog.setButton("Restart Now", function()
                                successDialog.dismiss()
                                speak("Restarting")
                                os.exit(0)
                            end)
                            successDialog.show()
                        end))
                    else
                        local restored = restoreFromBackup()
                        cleanupFiles()
                        mainHandler.post(createRunnable(function()
                            if restored then
                                speak("Update failed, old version restored")
                            else
                                speak("Update failed")
                            end
                            showToast("Update failed")
                        end))
                    end
                else
                    mainHandler.post(createRunnable(function()
                        speak("Cannot write update file")
                        showToast("Write permission error")
                    end))
                end
            else
                mainHandler.post(createRunnable(function()
                    speak("Download failed")
                    showToast("Download error")
                end))
            end
            updateInProgress = false
        end)
    end)).start()
end

local function getService(name)
    if not cachedServices[name] then
        cachedServices[name] = service.getSystemService(name)
    end
    return cachedServices[name]
end

local function getPref()
    if not cachedPrefs then
        cachedPrefs = service.getSharedPreferences(CONSTANTS.PREF_NAME, 0)
    end
    return cachedPrefs
end

local function getEdit()
    if not cachedEdit then
        cachedEdit = getPref().edit()
    end
    return cachedEdit
end

function isNoisyModeEnabled()
    return getPref().getBoolean(NOISY_MODE_PREF_KEY, false)
end

function setNoisyModeEnabled(enabled)
    getEdit().putBoolean(NOISY_MODE_PREF_KEY, enabled)
    getEdit().commit()
end

function getTTSEnginePreference()
    return getPref().getString(TTS_ENGINE_PREF_KEY, "default")
end

function setTTSEnginePreference(engineName)
    getEdit().putString(TTS_ENGINE_PREF_KEY, engineName)
    getEdit().commit()
    if currentTTS then
        pcall(function() currentTTS.shutdown() end)
        currentTTS = nil
        ttsInitialized = false
    end
end

function getAvailableTTSEngines()
    local engines = {}
    local pm = service.getPackageManager()
    local intent = Intent(TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE)
    local resolveInfos = pm.queryIntentServices(intent, 0)
    table.insert(engines, {
        name = "Default (解说)",
        packageName = "default",
        isDefault = true
    })
    if resolveInfos then
        for i = 0, resolveInfos.size() - 1 do
            local info = resolveInfos.get(i)
            local packageName = info.serviceInfo.packageName
            local appName = pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0))
            table.insert(engines, {
                name = tostring(appName),
                packageName = packageName,
                isDefault = false
            })
        end
    end
    return engines
end

function initializeTTS()
    if getTTSEnginePreference() == "default" then
        ttsInitialized = true
        return true
    end
    if currentTTS then
        pcall(function() currentTTS.shutdown() end)
        currentTTS = nil
    end
    local engineName = getTTSEnginePreference()
    local success, err = pcall(function()
        currentTTS = TextToSpeech(service, {
            onInit = function(status)
                if status == TextToSpeech.SUCCESS then
                    ttsInitialized = true
                    currentTTS.setLanguage(Locale.US)
                else
                    ttsInitialized = false
                end
            end,
            onError = function()
                ttsInitialized = false
            end
        }, engineName)
    end)
    if not success then
        ttsInitialized = false
        service.speak("TTS engine failed to initialize")
    end
    return ttsInitialized
end

function speakWithTTS(message)
    if not message or message == "" then return end
    requestAudioFocus()
    local success, err = pcall(function()
        if getTTSEnginePreference() == "default" then
            service.speak(message)
        elseif ttsInitialized and currentTTS then
            currentTTS.speak(message, TextToSpeech.QUEUE_FLUSH, nil, "tts_engine")
        else
            service.speak(message)
        end
    end)
    if not success then
        service.speak(message)
    end
end

function speak(message, delay)
    if not delay then delay = CONSTANTS.DELAYS.SUPER_FAST end
    speakWithTTS(message)
    return message
end

function speakListening()
    speakWithTTS("Listening")
end

function isVibrationEnabled()
    return getPref().getBoolean(VIBRATION_ENABLED_PREF_KEY, true)
end

function setVibrationEnabled(enabled)
    getEdit().putBoolean(VIBRATION_ENABLED_PREF_KEY, enabled)
    getEdit().commit()
end

function vibrateDevice()
    if isVibrationEnabled() then
        pcall(function()
            local vibrator = service.getSystemService(Context.VIBRATOR_SERVICE)
            if vibrator and vibrator.hasVibrator() then
                vibrator.vibrate(50)
                return true
            end
        end)
    end
    return false
end

function playSoundTick()
    service.playSoundTick()
end

function requestAudioFocus()
    if not audioManager then
        audioManager = getService(Context.AUDIO_SERVICE)
    end
    if audioManager and not isAudioFocusGranted then
        local result = audioManager.requestAudioFocus(nil, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        if result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED then
            isAudioFocusGranted = true
        end
    end
end

function abandonAudioFocus()
    if audioManager and isAudioFocusGranted then
        audioManager.abandonAudioFocus(nil)
        isAudioFocusGranted = false
    end
end

function getWhatsAppPreference()
    return getPref().getString(WHATSAPP_PREF_KEY, WHATSAPP_PREF_ASK)
end

function setWhatsAppPreference(prefValue)
    getEdit().putString(WHATSAPP_PREF_KEY, prefValue)
    getEdit().commit()
end

function getCustomCommands()
    local json = getPref().getString(CUSTOM_COMMANDS_KEY, "{}")
    local success, custom = pcall(loadstring("return " .. json))
    if success and custom then
        return custom
    end
    return {}
end

function saveCustomCommands(customCommands)
    local json = "{}"
    local success, result = pcall(function()
        local items = {}
        for k, v in pairs(customCommands) do
            table.insert(items, string.format('["%s"]="%s"', k:gsub('"', '\\"'), v:gsub('"', '\\"')))
        end
        return "{" .. table.concat(items, ",") .. "}"
    end)
    if success then
        json = result
    end
    getEdit().putString(CUSTOM_COMMANDS_KEY, json)
    getEdit().commit()
end

function getCommandKeyword(commandName)
    local custom = getCustomCommands()
    if custom[commandName] and custom[commandName] ~= "" then
        return custom[commandName]
    end
    return DEFAULT_COMMANDS[commandName] or commandName
end

function resetCommandToDefault(commandName)
    local custom = getCustomCommands()
    custom[commandName] = nil
    saveCustomCommands(custom)
end

function resetAllCommandsToDefault()
    saveCustomCommands({})
    speak("All commands reset to default")
end

function getContactKeywords()
    local json = getPref().getString(CONTACT_KEYWORDS_KEY, "{}")
    local success, keywords = pcall(loadstring("return " .. json))
    if success and keywords then
        return keywords
    end
    return {}
end

function saveContactKeywords(keywords)
    local json = "{}"
    local success, result = pcall(function()
        local items = {}
        for contactName, keyword in pairs(keywords) do
            table.insert(items, string.format('["%s"]="%s"', 
                contactName:gsub('"', '\\"'), 
                keyword:gsub('"', '\\"')))
        end
        return "{" .. table.concat(items, ",") .. "}"
    end)
    if success then
        json = result
    end
    getEdit().putString(CONTACT_KEYWORDS_KEY, json)
    getEdit().commit()
end

function getContactByKeyword(keyword)
    if (os.time()*1000 - lastKeywordCacheClear) > 30000 then
        contactKeywordCache = {}
        lastKeywordCacheClear = os.time()*1000
    end
    if contactKeywordCache[keyword] then
        return contactKeywordCache[keyword]
    end
    local keywords = getContactKeywords()
    for contactName, savedKeyword in pairs(keywords) do
        if savedKeyword:lower() == keyword:lower() then
            contactKeywordCache[keyword] = contactName
            return contactName
        end
    end
    contactKeywordCache[keyword] = nil
    return nil
end

function destroySpeechRecognizer(recognizer)
    if recognizer then
        pcall(function()
            recognizer.stopListening()
            recognizer.destroy()
        end)
        return nil
    end
    return nil
end

function stopAllSpeechRecognizers()
    isListening = false
    if mainSpeechRecognizer then
        mainSpeechRecognizer = destroySpeechRecognizer(mainSpeechRecognizer)
    end
end

function getCurrentDateInfo()
    local currentTime = os.time()
    local dateTable = os.date("*t", currentTime)
    local dayNames = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
    local monthNames = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
    local dayName = dayNames[dateTable.wday]
    local monthName = monthNames[dateTable.month]
    local function getDaySuffix(day)
        if day >= 11 and day <= 13 then return "th" end
        local lastDigit = day % 10
        if lastDigit == 1 then return "st"
        elseif lastDigit == 2 then return "nd"
        elseif lastDigit == 3 then return "rd"
        else return "th" end
    end
    local daySuffix = getDaySuffix(dateTable.day)
    local fullDate = string.format("%s, %s %d%s, %d", dayName, monthName, dateTable.day, daySuffix, dateTable.year)
    local speakDate = string.format("Today is %s, %s %d%s %d", dayName, monthName, dateTable.day, daySuffix, dateTable.year)
    local shortDate = os.date("%d-%m-%Y", currentTime)
    return {
        day = dateTable.day,
        dayName = dayName,
        month = dateTable.month,
        monthName = monthName,
        year = dateTable.year,
        fullDate = fullDate,
        speakDate = speakDate,
        shortDate = shortDate
    }
end

function speakCurrentDate()
    local dateInfo = getCurrentDateInfo()
    speak(dateInfo.speakDate)
    return true
end

function openHowToUseVideo()
    if settingsDialog then settingsDialog.dismiss() end
    if commandsDialog then commandsDialog.dismiss() end
    if whatsappSettingsDlg then whatsappSettingsDlg.dismiss() end
    if contactSelectionDialog then contactSelectionDialog.dismiss() end
    if selectionDialog then selectionDialog.dismiss() end
    speak("Tutorial")
    Handler().postDelayed(function()
        local youtubeUrl = "https://youtu.be/O5R7KBdWgwg"
        local intent = Intent(Intent.ACTION_VIEW)
        intent.setData(Uri.parse(youtubeUrl))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        service.startActivity(intent)
        speak("Video opened")
    end, CONSTANTS.DELAYS.SHORT)
end

local function saveUserData(name, phone)
  local pref = service.getSharedPreferences("user_feedback_data", Context.MODE_PRIVATE)
  local edit = pref.edit()
  edit.putString("name", name)
  edit.putString("phone", phone)
  edit.apply()
end

local function loadUserData()
  local pref = service.getSharedPreferences("user_feedback_data", Context.MODE_PRIVATE)
  local name = pref.getString("name", "")
  local phone = pref.getString("phone", "")
  return name, phone
end

local function showHelpAndSupportDialog(ctx)
    local help_views = {}
    local help_layout = {
        LinearLayout;
        orientation = "vertical";
        padding = "16dp";
        layout_width = "fill";
        layout_height = "wrap";
        {
            TextView;
            text = "HELP AND SUPPORT\n\nThank you for using Advance Voice Assistant by Tech For V I!";
            textColor = "#2196F3";
            textSize = 18;
            gravity = "center";
            paddingBottom = "20dp";
        };
        {
            TextView;
            text = "Join Our Community For More Useful Tools, Contact us for feedback and suggestions, and stay updated with our latest tools";
            textSize = 14;
            textColor = "#666666";
            gravity = "center";
            paddingBottom = "20dp";
        };
        {
            ScrollView;
            layout_width = "fill";
            layout_height = "wrap_content";
            {
                LinearLayout;
                orientation = "vertical";
                layout_width = "fill";
                layout_height = "wrap_content";
                gravity = "center";
                layout_marginTop = "5dp";
                {
                    Button;
                    id = "sendFeedbackButton";
                    text = "SEND FEEDBACK";
                    layout_width = "fill";
                    layout_height = "wrap_content";
                    layout_margin = "2dp";
                    textSize = "12sp";
                    padding = "8dp";
                    backgroundColor = "#FF9800";
                    textColor = "#FFFFFF";
                };
                {
                    Button;
                    id = "joinWhatsAppGroupButton";
                    text = "JOIN WHATSAPP GROUP";
                    layout_width = "fill";
                    layout_height = "wrap_content";
                    layout_margin = "2dp";
                    textSize = "12sp";
                    padding = "8dp";
                    backgroundColor = "#25D366";
                    textColor = "#FFFFFF";
                };
                {
                    Button;
                    id = "joinYouTubeChannelButton";
                    text = "JOIN YOUTUBE CHANNEL";
                    layout_width = "fill";
                    layout_height = "wrap_content";
                    layout_margin = "2dp";
                    textSize = "12sp";
                    padding = "8dp";
                    backgroundColor = "#FF0000";
                    textColor = "#FFFFFF";
                };
                {
                    Button;
                    id = "joinTelegramChannelButton";
                    text = "JOIN TELEGRAM CHANNEL";
                    layout_width = "fill";
                    layout_height = "wrap_content";
                    layout_margin = "2dp";
                    textSize = "12sp";
                    padding = "8dp";
                    backgroundColor = "#2196F3";
                    textColor = "#FFFFFF";
                };
                {
                    Button;
                    id = "goBackButton";
                    text = "GO BACK";
                    layout_width = "fill";
                    layout_height = "wrap_content";
                    layout_margin = "2dp";
                    textSize = "12sp";
                    padding = "8dp";
                    backgroundColor = "#9E9E9E";
                    textColor = "#FFFFFF";
                };
            };
        };
    }

    local help_dialog = LuaDialog(ctx)
    help_dialog.setTitle("About and Support")
    help_dialog.setView(loadlayout(help_layout, help_views))

    local mainHandler = Handler(Looper.getMainLooper())

    local function showFeedbackDialog()
        local saved_name, saved_phone = loadUserData()
        
        local feedback_views = {}
        local feedbackLayout = {
          LinearLayout,
          orientation = "vertical",
          layout_width = "fill",
          padding = "20dp",
          backgroundColor = "#FFFFFF",
          {
            TextView,
            text = "Send Feedback to Developer",
            textSize = "18sp",
            textColor = "#0088CC",
            gravity = "center",
            padding = "10dp",
            typeface = Typeface.DEFAULT_BOLD,
          },
          {
            EditText,
            id = "name_input",
            text = saved_name,
            hint = "Enter Name (Required)",
            layout_width = "fill",
            layout_marginTop = "10dp",
          },
          {
            EditText,
            id = "phone_input",
            text = saved_phone,
            hint = "WhatsApp Number (Optional)",
            layout_width = "fill",
            layout_marginTop = "10dp",
            inputType = 3,
          },
          {
            EditText,
            id = "msg_input",
            hint = "Type your feedback here... (Required)",
            layout_width = "fill",
            layout_marginTop = "10dp",
            minLines = 3,
            gravity = Gravity.TOP,
          },
          {
            Button,
            id = "send_btn",
            text = "Send Feedback",
            layout_width = "fill",
            layout_marginTop = "20dp",
            backgroundColor = "#0088CC",
            textColor = "#FFFFFF",
          },
          {
            Button,
            id = "back_btn",
            text = "CLOSE FEEDBACK",
            layout_width = "fill",
            layout_marginTop = "5dp",
            backgroundColor = "#9E9E9E",
            textColor = "#FFFFFF",
          },
        }

        local feedbackDialog = LuaDialog(ctx)
        feedbackDialog.setTitle("Send Feedback")
        feedbackDialog.setView(loadlayout(feedbackLayout, feedback_views))
        feedbackDialog.setCancelable(true)
        
        feedback_views.back_btn.onClick = function()
            feedbackDialog.dismiss()
        end
        
        feedback_views.send_btn.onClick = function()
            local user_name = tostring(feedback_views.name_input.Text):gsub("^%s*(.-)%s*$", "%1")
            local user_phone = tostring(feedback_views.phone_input.Text):gsub("^%s*(.-)%s*$", "%1")
            local user_feedback = tostring(feedback_views.msg_input.Text):gsub("^%s*(.-)%s*$", "%1")
            
            if user_name == "" then
                speak("Please enter your name first")
                return
            end
            
            if user_feedback == "" or #user_feedback < 2 then
                speak("Please type your feedback first")
                return
            end
            
            feedback_views.send_btn.Text = "Sending..."
            feedback_views.send_btn.setEnabled(false)
            
            local api_url = "https://hc-send.vercel.app/api/send"
            local full_combined_message = "App: Advance Voice Assistant\\nName: " .. user_name .. "\\nPhone: " .. user_phone .. "\\nFeedback: " .. user_feedback
            local payload = '{"message":"'..full_combined_message..'","userName":"'..user_name..'"}'
            local headers = {["Content-Type"]="application/json; charset=utf-8"}
            
            Http.post(api_url, payload, headers, function(code, content)
                mainHandler.post(luajava.createProxy("java.lang.Runnable", {
                    run = function()
                        if code == 200 then
                            speak("Sent")
                            saveUserData(user_name, user_phone)
                            speak("Your feedback has been sent successfully. Thank you!")
                            feedbackDialog.dismiss()
                        else
                            speak("Error sending feedback")
                            feedback_views.send_btn.Text = "Send Feedback"
                            feedback_views.send_btn.setEnabled(true)
                        end
                    end
                }))
            end)
        end
        
        feedbackDialog.show()
    end

    help_views.sendFeedbackButton.onClick = function()
        showFeedbackDialog()
    end

    help_views.joinWhatsAppGroupButton.onClick = function()
        local function performActions()
            help_dialog.dismiss()
            local success, err = pcall(function()
                local message = "Assalam%20o%20Alaikum.%20I%20hope%20you%20are%20doing%20well.%20I%20would%20like%20to%20join%20your%20WhatsApp%20group.%20Kindly%20share%20the%20instructions.%20group%20rules%20and%20regulations.%20Thank%20you.%20so%20much"
                local url = "https://wa.me/923316809146?text=" .. message
                local intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                ctx.startActivity(intent)
            end)
            if not success then
                speak("Could not open WhatsApp")
            end
        end
        speak("Opening WhatsApp for Support")
        local handler = Handler(Looper.getMainLooper())
        handler.postDelayed(luajava.createProxy("java.lang.Runnable", {
            run = performActions
        }), CONSTANTS.DELAYS.NORMAL)
    end

    help_views.joinYouTubeChannelButton.onClick = function()
        local function performActions()
            help_dialog.dismiss()
            local success, err = pcall(function()
                local url = "https://youtube.com/@techforvi"
                local intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                ctx.startActivity(intent)
            end)
            if not success then
                speak("Could not open YouTube")
            end
        end
        speak("Opening YouTube Channel")
        local handler = Handler(Looper.getMainLooper())
        handler.postDelayed(luajava.createProxy("java.lang.Runnable", {
            run = performActions
        }), CONSTANTS.DELAYS.NORMAL)
    end

    help_views.joinTelegramChannelButton.onClick = function()
        local function performActions()
            help_dialog.dismiss()
            local success, err = pcall(function()
                local url = "https://t.me/TechForVI"
                local intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                ctx.startActivity(intent)
            end)
            if not success then
                speak("Could not open Telegram")
            end
        end
        speak("Opening Telegram Channel")
        local handler = Handler(Looper.getMainLooper())
        handler.postDelayed(luajava.createProxy("java.lang.Runnable", {
            run = performActions
        }), CONSTANTS.DELAYS.NORMAL)
    end

    help_views.goBackButton.onClick = function()
        help_dialog.dismiss()
        showSettingsDialog()
    end

    help_dialog.show()
end
function checkSpecialApps(query)
    if query:find("deep") or query:find("seek") or query:find("sea") then
        return "com.deepseek.chat"
    end
    return nil
end

function openAppWithForceLogic(appName)
    if not appName or appName == "" then return end
    local pm = service.getPackageManager()
    local specialPackage = checkSpecialApps(appName)
    if specialPackage then
        local intent = pm.getLaunchIntentForPackage(specialPackage)
        if intent then
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            service.startActivity(intent)
            speak("Opening DeepSeek")
            return true
        end
    end
    local apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
    local found = false
    for i = 0, apps.size() - 1 do
        local info = apps.get(i)
        local label = tostring(info.loadLabel(pm)):lower()
        if label:find(appName, 1, true) or appName:find(label, 1, true) then
            local intent = pm.getLaunchIntentForPackage(info.packageName)
            if intent then
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                service.startActivity(intent)
                speak("Opening " .. tostring(info.loadLabel(pm)))
                found = true
                break
            end
        end
    end
    if not found then
        speak("I'm sorry, I couldn't find " .. appName)
        return false
    end
    return true
end

function showCommandEditDialog(commandName, currentKeyword, description)
    local layout = LinearLayout(service)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(25, 25, 25, 25)
    layout.setBackgroundColor(0xFF0A0A0A)
    local heading = TextView(service)
    heading.setText("Customize Command")
    heading.setTextColor(0xFF2196F3)
    heading.setTextSize(18)
    heading.setTypeface(nil, Typeface.BOLD)
    heading.setGravity(Gravity.CENTER)
    heading.setPadding(0, 0, 0, 20)
    layout.addView(heading)
    local editText = EditText(service)
    editText.setHint("Enter custom keyword for: " .. commandName)
    editText.setText(currentKeyword)
    editText.setTextColor(0xFFFFFFFF)
    editText.setHintTextColor(0xFF888888)
    editText.setBackgroundColor(0xFF1A1A1A)
    editText.setPadding(15, 15, 15, 15)
    editText.setTextSize(14)
    editText.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
    layout.addView(editText)
    local buttonLayout = LinearLayout(service)
    buttonLayout.setOrientation(LinearLayout.HORIZONTAL)
    buttonLayout.setGravity(Gravity.CENTER)
    buttonLayout.setPadding(0, 20, 0, 0)
    local cancelBtn = Button(service)
    cancelBtn.setText("Cancel")
    cancelBtn.setBackgroundColor(0xFFF44336)
    cancelBtn.setTextColor(0xFFFFFFFF)
    cancelBtn.setPadding(15, 12, 15, 12)
    cancelBtn.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
    cancelBtn.setTextSize(14)
    local saveBtn = Button(service)
    saveBtn.setText("Save")
    saveBtn.setBackgroundColor(0xFF4CAF50)
    saveBtn.setTextColor(0xFFFFFFFF)
    saveBtn.setPadding(15, 12, 15, 12)
    saveBtn.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
    saveBtn.setTextSize(14)
    local resetBtn = Button(service)
    resetBtn.setText("Reset")
    resetBtn.setBackgroundColor(0xFFFF9800)
    resetBtn.setTextColor(0xFFFFFFFF)
    resetBtn.setPadding(15, 12, 15, 12)
    resetBtn.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
    resetBtn.setTextSize(14)
    buttonLayout.addView(cancelBtn)
    buttonLayout.addView(saveBtn)
    buttonLayout.addView(resetBtn)
    layout.addView(buttonLayout)
    local dialog = LuaDialog(service)
    dialog.setTitle("Edit Command: " .. commandName)
    dialog.setView(layout)
    dialog.setCancelable(true)
    cancelBtn.onClick = function()
        dialog.dismiss()
    end
    saveBtn.onClick = function()
        local newKeyword = tostring(editText.getText())
        if newKeyword then
            newKeyword = newKeyword:match("^%s*(.-)%s*$")
            if newKeyword ~= "" then
                if not newKeyword:match("^[A-Za-z0-9%s]+$") then
                    speak("Only English keywords allowed")
                    return
                end
                local customCommands = getCustomCommands()
                customCommands[commandName] = newKeyword
                saveCustomCommands(customCommands)
                speak("Command saved")
                dialog.dismiss()
                if commandsDialog then commandsDialog.dismiss() end
                Handler().postDelayed(function()
                    showAllCommandsDialog()
                end, CONSTANTS.DELAYS.FAST)
            else
                speak("Please enter a keyword")
            end
        else
            speak("Please enter a keyword")
        end
    end
    resetBtn.onClick = function()
        resetCommandToDefault(commandName)
        speak("Command reset to default")
        dialog.dismiss()
        if commandsDialog then commandsDialog.dismiss() end
        Handler().postDelayed(function()
            showAllCommandsDialog()
        end, CONSTANTS.DELAYS.FAST)
    end
    dialog.show()
end

function showAllCommandsDialog()
    local customCommands = getCustomCommands()
    local commands = {
        "",
        "────────────────────────────────",
        "            SETTINGS COMMANDS",
        "────────────────────────────────",
        "show menu - Open settings",
        "show commands - Commands list",
        "",
        "────────────────────────────────",
        "        SCREEN READER COMMANDS",
        "────────────────────────────────",
        "rs - Restart screen reader",
        "tf - Turn off screen reader",
        "",
        "────────────────────────────────",
        "            SYSTEM CONTROL",
        "────────────────────────────────",
        "current battery - Battery percentage",
        "current time - Current time",
        "current date - Today's date",
        "accessibility settings - Accessibility",
        "how to use - Tutorial video",
        "speech rate [0-100] - TTS speech rate",
        "",
        "────────────────────────────────",
        "           VOLUME CONTROL",
        "────────────────────────────────",
        "volume [0-100] - Media volume",
        "ring volume [0-100] - Ringtone",
        "notification volume [0-100] - Notification",
        "alarm volume [0-100] - Alarm",
        "accessibility volume [0-100] - Accessibility",
        "",
        "────────────────────────────────",
        "           DEVICE FEATURES",
        "────────────────────────────────",
        "toggle bluetooth - Bluetooth on/off",
        "toggle flashlight - Flashlight on/off",
        "toggle mobile data - Mobile data on/off",
        "wf - WiFi on/off",
        "toggle silent mode - Silent/vibrate/normal mode",
        "silent - Silent/vibrate/normal mode",
        "mute - Silent/vibrate/normal mode",
        "",
        "────────────────────────────────",
        "      WHATSAPP GROUP COMMANDS",
        "────────────────────────────────",
        "only admin - Set group to admin only mode",
        "mention all - Mention all group members",
        "rename it - Rename item",
        "",
        "────────────────────────────────",
        "            APP CONTROL",
        "────────────────────────────────",
        "send now - Share to WhatsApp",
        "uninstall - Uninstall app",
        "clear chat - Clear chat",
        "delete from everyone - Delete for all",
        "delete from me - Delete for me",
        "delete now - Quick delete",
        "delete number [name] - Delete contact",
        "application info - App information",
        "open [app name] - Open app",
        "talk with me - Open ChatGPT voice conversation",
        "",
        "────────────────────────────────",
        "            CALL COMMANDS",
        "────────────────────────────────",
        "voice call [contact] - WhatsApp voice",
        "video call [contact] - WhatsApp video",
        "chat [contact] - WhatsApp chat",
        "call [contact] - Phone call",
        "",
        "────────────────────────────────",
        "           SEARCH COMMANDS",
        "────────────────────────────────",
        "search [query] on youtube - YouTube",
        "search [query] on spotify - Spotify",
        "search [query] on google - Google",
        "search [query] on play store - Play Store",
        "search song [query] on youtube music - YouTube Music",
        "",
        "────────────────────────────────",
        "           DIRECT ACTIONS",
        "────────────────────────────────",
        "Say any visible button name to click it",
        "Speak any Jieshuo function to apply",
        "",
        "────────────────────────────────",
        "             DEVELOPER",
        "────────────────────────────────",
        "Developed by Muhammad Hanzla",
        "Advance voice assistant by Tech For V I",
        "Version: " .. CURRENT_VERSION
    }
    local layout = LinearLayout(service)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(15, 15, 15, 15)
    layout.setBackgroundColor(0xFF0A0A0A)
    local title = TextView(service)
    title.setText("Voice Commands List")
    title.setTextColor(0xFF2196F3)
    title.setTextSize(18)
    title.setTypeface(nil, Typeface.BOLD)
    title.setGravity(Gravity.CENTER)
    title.setPadding(0, 0, 0, 15)
    layout.addView(title)
    
    local scrollView = ScrollView(service)
    local listLayout = LinearLayout(service)
    listLayout.setOrientation(LinearLayout.VERTICAL)
    listLayout.setPadding(3, 3, 3, 3)
    
    local backToMenuBtn = Button(service)
    backToMenuBtn.setText("⟵ BACK TO MAIN MENU")
    backToMenuBtn.setBackgroundColor(0xFFFF9800)
    backToMenuBtn.setTextColor(0xFFFFFFFF)
    backToMenuBtn.setPadding(20, 15, 20, 15)
    backToMenuBtn.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
    backToMenuBtn.setTypeface(nil, Typeface.BOLD)
    backToMenuBtn.setTextSize(14)
    backToMenuBtn.onClick = function()
        if commandsDialog then
            commandsDialog.dismiss()
            commandsDialog = nil
        end
        showSettingsDialog()
    end
    listLayout.addView(backToMenuBtn)
    
    local space = View(service)
    space.setLayoutParams(LinearLayout.LayoutParams(-1, 10))
    listLayout.addView(space)
    
    local commandMappings = {
        ["show menu"] = "show menu",
        ["show commands"] = "show commands",
        ["rs"] = "rs",
        ["tf"] = "tf",
        ["current battery"] = "current battery",
        ["current time"] = "current time",
        ["current date"] = "current date",
        ["accessibility settings"] = "accessibility settings",
        ["how to use"] = "how to use",
        ["speech rate"] = "speech rate",
        ["send now"] = "send now",
        ["uninstall"] = "uninstall",
        ["clear chat"] = "clear chat",
        ["delete from everyone"] = "delete from everyone",
        ["delete from me"] = "delete from me",
        ["delete now"] = "delete now",
        ["delete number"] = "delete number",
        ["application info"] = "application info",
        ["voice call"] = "voice call",
        ["video call"] = "video call",
        ["chat"] = "chat",
        ["call"] = "call",
        ["search on youtube"] = "search on youtube",
        ["search on spotify"] = "search on spotify",
        ["search on google"] = "search on google",
        ["search on play store"] = "search on play store",
        ["search song on youtube music"] = "search song on youtube music",
        ["open"] = "open",
        ["toggle bluetooth"] = "toggle bluetooth",
        ["toggle flashlight"] = "toggle flashlight",
        ["toggle mobile data"] = "toggle mobile data",
        ["wf"] = "wf",
        ["toggle silent mode"] = "toggle silent mode",
        ["silent"] = "silent",
        ["mute"] = "mute",
        ["only admin"] = "only admin",
        ["mention all"] = "mention all",
        ["rename it"] = "rename it",
        ["talk with me"] = "talk with me",
        ["check update"] = "check update"
    }
    for i, line in ipairs(commands) do
        local textView = TextView(service)
        textView.setText(line)
        if line:find("────────────────────────────────") then
            textView.setTextColor(0xFF2196F3)
            textView.setTypeface(nil, Typeface.BOLD)
            textView.setGravity(Gravity.CENTER)
            textView.setPadding(0, 8, 0, 8)
        elseif line:find("[A-Z ]+") and not line:find("[a-z]") and line ~= "" and #line > 10 then
            textView.setTextColor(0xFFFF9800)
            textView.setTypeface(nil, Typeface.BOLD)
            textView.setTextSize(14)
            textView.setGravity(Gravity.CENTER)
            textView.setPadding(0, 10, 0, 3)
        elseif line == "" then
            textView.setHeight(5)
        else
            textView.setTextColor(0xFFFFFFFF)
            local foundCommand = nil
            for cmd, _ in pairs(commandMappings) do
                if line:find("^" .. cmd) then
                    foundCommand = cmd
                    break
                end
            end
            if foundCommand then
                local actualKeyword = getCommandKeyword(foundCommand)
                if actualKeyword ~= foundCommand then
                    local newLine = line:gsub(foundCommand, actualKeyword .. " (custom)")
                    textView.setText(newLine)
                    textView.setTextColor(0xFF2196F3)
                else
                    textView.setTextColor(0xFF4CAF50)
                end
                textView.setTypeface(nil, Typeface.BOLD)
                textView.setBackgroundColor(0xFF1A1A1A)
                textView.setPadding(10, 8, 10, 8)
                textView.onClick = function()
                    local currentKeyword = getCommandKeyword(foundCommand)
                    showCommandEditDialog(foundCommand, currentKeyword, "")
                end
                textView.onLongClick = function()
                    local actualKeyword = getCommandKeyword(foundCommand)
                    local defaultKeyword = DEFAULT_COMMANDS[foundCommand] or foundCommand
                    if actualKeyword == defaultKeyword then
                        speak("Command: " .. foundCommand .. ", Keyword: " .. actualKeyword .. " (default)")
                    else
                        speak("Command: " .. foundCommand .. ", Keyword: " .. actualKeyword .. " (custom), Default: " .. defaultKeyword)
                    end
                    return true
                end
            end
        end
        textView.setTextSize(12)
        listLayout.addView(textView)
    end
    scrollView.addView(listLayout)
    layout.addView(scrollView)
    
    commandsDialog = LuaDialog(service)
    commandsDialog.setTitle("Voice Commands - Click to customize")
    commandsDialog.setView(layout)
    commandsDialog.setCancelable(true)
    commandsDialog.show()
    speak("Commands list")
end

function showSettingsDialog()
    local layout = LinearLayout(service)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(25, 25, 25, 25)
    layout.setBackgroundColor(0xFF0A0A0A)
    local appName = TextView(service)
    appName.setText("Advance Voice Assistant by Tech For V I")
    appName.setTextColor(0xFF2196F3)
    appName.setTextSize(22)
    appName.setTypeface(nil, Typeface.BOLD)
    appName.setGravity(Gravity.CENTER)
    appName.setPadding(0, 0, 0, 5)
    layout.addView(appName)
    local developer = TextView(service)
    developer.setText("Developed by Muhammad Hanzla")
    developer.setTextColor(0xFFFFFFFF)
    developer.setTextSize(14)
    developer.setGravity(Gravity.CENTER)
    developer.setPadding(0, 0, 0, 5)
    layout.addView(developer)
    local version = TextView(service)
    version.setText("Version: " .. CURRENT_VERSION)
    version.setTextColor(0xFF4CAF50)
    version.setTextSize(12)
    version.setGravity(Gravity.CENTER)
    version.setPadding(0, 0, 0, 20)
    layout.addView(version)
    local buttonsContainer = LinearLayout(service)
    buttonsContainer.setOrientation(LinearLayout.VERTICAL)

    local buttonConfigs = {
        {"Show Commands", 0xFF2196F3},
        {"Settings", 0xFF9C27B0},
        {"Check Update", 0xFF4CAF50},
        {"About and Support", 0xFFFF5722},
        {"Exit", 0xFFF44336}
    }

    for i, config in ipairs(buttonConfigs) do
        local btn = Button(service)
        btn.setText(config[1])
        btn.setBackgroundColor(config[2])
        btn.setTextColor(0xFFFFFFFF)
        btn.setPadding(20, 15, 20, 15)
        btn.setTextSize(14)
        btn.setTypeface(nil, Typeface.BOLD)
        btn.setAllCaps(false)
        local params = LinearLayout.LayoutParams(-1, -2)
        if i > 1 then
            params.topMargin = 10
        end
        btn.setLayoutParams(params)

        if config[1] == "Show Commands" then
            btn.onClick = function()
                if settingsDialog then settingsDialog.dismiss() end
                showAllCommandsDialog()
            end
        elseif config[1] == "Settings" then
            btn.onClick = function()
                if settingsDialog then settingsDialog.dismiss() end
                showSettingsSubDialog()
            end
        elseif config[1] == "Check Update" then
            btn.onClick = function()
                if settingsDialog then settingsDialog.dismiss() end
                checkUpdate(true)
            end
        elseif config[1] == "About and Support" then
            btn.onClick = function()
                if settingsDialog then settingsDialog.dismiss() end
                showHelpAndSupportDialog(service)
            end
        elseif config[1] == "Exit" then
            btn.onClick = function()
                stopAllSpeechRecognizers()
                local homeIntent = Intent(Intent.ACTION_MAIN)
                homeIntent.addCategory(Intent.CATEGORY_HOME)
                homeIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                service.startActivity(homeIntent)
                if settingsDialog then settingsDialog.dismiss() end
                speak("Closed")
            end
        end

        buttonsContainer.addView(btn)
    end

    layout.addView(buttonsContainer)
    local dialog = LuaDialog(service)
    dialog.setTitle("Main Menu")
    dialog.setView(layout)
    dialog.setCancelable(true)
    settingsDialog = dialog
    dialog.show()
    speak("Menu opened")
end

function showSettingsSubDialog()
    local layout = LinearLayout(service)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(15, 15, 15, 15)
    layout.setBackgroundColor(0xFF0A0A0A)
    local title = TextView(service)
    title.setText("Settings")
    title.setTextColor(0xFF2196F3)
    title.setTextSize(16)
    title.setTypeface(nil, Typeface.BOLD)
    title.setGravity(Gravity.CENTER)
    title.setPadding(0, 0, 0, 10)
    layout.addView(title)
    local vibrationCheckBox = CheckBox(service)
    vibrationCheckBox.setText("Enable vibration")
    vibrationCheckBox.setTextColor(0xFFFFFFFF)
    vibrationCheckBox.setChecked(isVibrationEnabled())
    vibrationCheckBox.setPadding(10, 5, 10, 10)
    vibrationCheckBox.setTextSize(12)
    layout.addView(vibrationCheckBox)
    local space1 = View(service)
    space1.setLayoutParams(LinearLayout.LayoutParams(-1, 15))
    layout.addView(space1)
    local noisyCheckBox = CheckBox(service)
    noisyCheckBox.setText("Noisy environment mode")
    noisyCheckBox.setTextColor(0xFFFFFFFF)
    noisyCheckBox.setChecked(isNoisyModeEnabled())
    noisyCheckBox.setPadding(10, 5, 10, 10)
    noisyCheckBox.setTextSize(12)
    layout.addView(noisyCheckBox)
    local space2 = View(service)
    space2.setLayoutParams(LinearLayout.LayoutParams(-1, 15))
    layout.addView(space2)
    local whatsappHeading = TextView(service)
    whatsappHeading.setText("WhatsApp Settings")
    whatsappHeading.setTextColor(0xFF25D366)
    whatsappHeading.setTextSize(14)
    whatsappHeading.setTypeface(nil, Typeface.BOLD)
    whatsappHeading.setGravity(Gravity.START)
    whatsappHeading.setPadding(0, 5, 0, 5)
    layout.addView(whatsappHeading)
    local whatsappSpinner = Spinner(service)
    local whatsappOptions = {"Always ask", "Use WhatsApp Messenger", "Use WhatsApp Business"}
    local currentWhatsAppPref = getWhatsAppPreference()
    local whatsappAdapter = ArrayAdapter(service, android.R.layout.simple_spinner_item, whatsappOptions)
    whatsappAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
    whatsappSpinner.setAdapter(whatsappAdapter)
    if currentWhatsAppPref == WHATSAPP_PREF_ASK then
        whatsappSpinner.setSelection(0)
    elseif currentWhatsAppPref == WHATSAPP_PREF_MESSENGER then
        whatsappSpinner.setSelection(1)
    elseif currentWhatsAppPref == WHATSAPP_PREF_BUSINESS then
        whatsappSpinner.setSelection(2)
    end
    layout.addView(whatsappSpinner)
    local space3 = View(service)
    space3.setLayoutParams(LinearLayout.LayoutParams(-1, 15))
    layout.addView(space3)
    local ttsHeading = TextView(service)
    ttsHeading.setText("TTS Engine")
    ttsHeading.setTextColor(0xFF00BCD4)
    ttsHeading.setTextSize(14)
    ttsHeading.setTypeface(nil, Typeface.BOLD)
    ttsHeading.setGravity(Gravity.START)
    ttsHeading.setPadding(0, 5, 0, 5)
    layout.addView(ttsHeading)
    local ttsSpinner = Spinner(service)
    local ttsEnginesList = getAvailableTTSEngines()
    local ttsEngineNames = {}
    for i, engine in ipairs(ttsEnginesList) do
        table.insert(ttsEngineNames, engine.name)
    end
    local ttsAdapter = ArrayAdapter(service, android.R.layout.simple_spinner_item, ttsEngineNames)
    ttsAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
    ttsSpinner.setAdapter(ttsAdapter)
    local currentTTSPref = getTTSEnginePreference()
    for i, engine in ipairs(ttsEnginesList) do
        if engine.packageName == currentTTSPref then
            ttsSpinner.setSelection(i-1)
            break
        end
    end
    layout.addView(ttsSpinner)
    local space4 = View(service)
    space4.setLayoutParams(LinearLayout.LayoutParams(-1, 15))
    layout.addView(space4)
    local contactHeading = TextView(service)
    contactHeading.setText("Contact Shortcuts")
    contactHeading.setTextColor(0xFFFF5722)
    contactHeading.setTextSize(14)
    contactHeading.setTypeface(nil, Typeface.BOLD)
    contactHeading.setGravity(Gravity.START)
    contactHeading.setPadding(0, 5, 0, 5)
    layout.addView(contactHeading)
    local contactBtn = Button(service)
    contactBtn.setText("Manage Shortcuts")
    contactBtn.setBackgroundColor(0xFFFF5722)
    contactBtn.setTextColor(0xFFFFFFFF)
    contactBtn.setPadding(10, 10, 10, 10)
    contactBtn.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
    layout.addView(contactBtn)
    local space5 = View(service)
    space5.setLayoutParams(LinearLayout.LayoutParams(-1, 15))
    layout.addView(space5)
    local buttonLayout = LinearLayout(service)
    buttonLayout.setOrientation(LinearLayout.HORIZONTAL)
    buttonLayout.setGravity(Gravity.CENTER)
    local saveBtn = Button(service)
    saveBtn.setText("Save")
    saveBtn.setBackgroundColor(0xFF4CAF50)
    saveBtn.setTextColor(0xFFFFFFFF)
    saveBtn.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
    saveBtn.setPadding(8, 10, 8, 10)
    local cancelBtn = Button(service)
    cancelBtn.setText("Cancel")
    cancelBtn.setBackgroundColor(0xFFF44336)
    cancelBtn.setTextColor(0xFFFFFFFF)
    cancelBtn.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
    cancelBtn.setPadding(8, 10, 8, 10)
    buttonLayout.addView(saveBtn)
    buttonLayout.addView(cancelBtn)
    layout.addView(buttonLayout)
    local dialog = LuaDialog(service)
    dialog.setTitle("Settings")
    dialog.setView(layout)
    dialog.setCancelable(true)
    contactBtn.onClick = function()
        dialog.dismiss()
        showContactKeywordsDialog()
    end
    saveBtn.onClick = function()
        setVibrationEnabled(vibrationCheckBox.isChecked())
        setNoisyModeEnabled(noisyCheckBox.isChecked())
        local whatsappSelection = whatsappSpinner.getSelectedItemPosition()
        if whatsappSelection == 0 then
            setWhatsAppPreference(WHATSAPP_PREF_ASK)
        elseif whatsappSelection == 1 then
            setWhatsAppPreference(WHATSAPP_PREF_MESSENGER)
        elseif whatsappSelection == 2 then
            setWhatsAppPreference(WHATSAPP_PREF_BUSINESS)
        end
        local ttsSelection = ttsSpinner.getSelectedItemPosition()
        if ttsEnginesList[ttsSelection+1] then
            setTTSEnginePreference(ttsEnginesList[ttsSelection+1].packageName)
        end
        dialog.dismiss()
        speak("Settings saved")
        initializeTTS()
        Handler().postDelayed(function()
            showSettingsDialog()
        end, CONSTANTS.DELAYS.MEDIUM)
    end
    cancelBtn.onClick = function()
        dialog.dismiss()
        speak("Cancelled")
        showSettingsDialog()
    end
    dialog.show()
    speak("Settings")
end

function showContactKeywordsDialog()
    local layout = LinearLayout(service)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(15, 15, 15, 15)
    layout.setBackgroundColor(0xFF0A0A0A)
    local title = TextView(service)
    title.setText("Contact Shortcuts")
    title.setTextColor(0xFF2196F3)
    title.setTextSize(18)
    title.setTypeface(nil, Typeface.BOLD)
    title.setGravity(Gravity.CENTER)
    title.setPadding(0, 0, 0, 10)
    layout.addView(title)
    local infoText = TextView(service)
    infoText.setText("Set shortcut keywords for quick contact access")
    infoText.setTextColor(0xFFFFFFFF)
    infoText.setTextSize(12)
    infoText.setGravity(Gravity.CENTER)
    infoText.setPadding(0, 0, 0, 15)
    layout.addView(infoText)
    local scrollView = ScrollView(service)
    local listLayout = LinearLayout(service)
    listLayout.setOrientation(LinearLayout.VERTICAL)
    local keywords = getContactKeywords()
    local keywordList = {}
    for contactName, keyword in pairs(keywords) do
        table.insert(keywordList, {
            contactName = contactName,
            keyword = keyword
        })
    end
    table.sort(keywordList, function(a, b)
        return a.contactName:lower() < b.contactName:lower()
    end)
    if #keywordList == 0 then
        local emptyText = TextView(service)
        emptyText.setText("No contact keywords set yet")
        emptyText.setTextColor(0xFF888888)
        emptyText.setTextSize(14)
        emptyText.setGravity(Gravity.CENTER)
        emptyText.setPadding(0, 10, 0, 10)
        listLayout.addView(emptyText)
    else
        for i, item in ipairs(keywordList) do
            local itemLayout = LinearLayout(service)
            itemLayout.setOrientation(LinearLayout.HORIZONTAL)
            itemLayout.setBackgroundColor(0xFF1A1A1A)
            itemLayout.setPadding(8, 8, 8, 8)
            local textView = TextView(service)
            textView.setText(string.format("%s → %s", item.contactName, item.keyword))
            textView.setTextColor(0xFF4CAF50)
            textView.setTextSize(12)
            textView.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
            local deleteBtn = Button(service)
            deleteBtn.setText("Remove")
            deleteBtn.setBackgroundColor(0xFFF44336)
            deleteBtn.setTextColor(0xFFFFFFFF)
            deleteBtn.setPadding(8, 8, 8, 8)
            deleteBtn.setMinWidth(0)
            deleteBtn.setMinHeight(0)
            deleteBtn.onClick = function()
                keywords[item.contactName] = nil
                saveContactKeywords(keywords)
                if contactKeywordsDialog then contactKeywordsDialog.dismiss() end
                showContactKeywordsDialog()
                speak("Keyword removed")
            end
            itemLayout.addView(textView)
            itemLayout.addView(deleteBtn)
            listLayout.addView(itemLayout)
            if i < #keywordList then
                local space = View(service)
                space.setLayoutParams(LinearLayout.LayoutParams(-1, 3))
                space.setBackgroundColor(0xFF333333)
                listLayout.addView(space)
            end
        end
    end
    scrollView.addView(listLayout)
    layout.addView(scrollView)
    local separator = View(service)
    separator.setLayoutParams(LinearLayout.LayoutParams(-1, 1))
    separator.setBackgroundColor(0xFF2196F3)
    separator.setPadding(0, 8, 0, 8)
    layout.addView(separator)
    local formTitle = TextView(service)
    formTitle.setText("Add New Shortcut")
    formTitle.setTextColor(0xFFFF9800)
    formTitle.setTextSize(14)
    formTitle.setTypeface(nil, Typeface.BOLD)
    formTitle.setGravity(Gravity.CENTER)
    formTitle.setPadding(0, 5, 0, 5)
    layout.addView(formTitle)
    local contactLayout = LinearLayout(service)
    contactLayout.setOrientation(LinearLayout.HORIZONTAL)
    contactLayout.setGravity(Gravity.CENTER_VERTICAL)
    local contactLabel = TextView(service)
    contactLabel.setText("Contact:")
    contactLabel.setTextColor(0xFFFFFFFF)
    contactLabel.setTextSize(12)
    contactLabel.setPadding(0, 0, 5, 0)
    contactLabel.setWidth(100)
    contactLayout.addView(contactLabel)
    local contactInput = EditText(service)
    contactInput.setHint("Contact name")
    contactInput.setTextColor(0xFFFFFFFF)
    contactInput.setHintTextColor(0xFF888888)
    contactInput.setBackgroundColor(0xFF333333)
    contactInput.setPadding(10, 8, 10, 8)
    contactInput.setTextSize(12)
    contactInput.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
    contactLayout.addView(contactInput)
    layout.addView(contactLayout)
    local keywordLayout = LinearLayout(service)
    keywordLayout.setOrientation(LinearLayout.HORIZONTAL)
    keywordLayout.setGravity(Gravity.CENTER_VERTICAL)
    local keywordLabel = TextView(service)
    keywordLabel.setText("Keyword:")
    keywordLabel.setTextColor(0xFFFFFFFF)
    keywordLabel.setTextSize(12)
    keywordLabel.setPadding(0, 0, 5, 0)
    keywordLabel.setWidth(100)
    keywordLayout.addView(keywordLabel)
    local keywordInput = EditText(service)
    keywordInput.setHint("Short keyword")
    keywordInput.setTextColor(0xFFFFFFFF)
    keywordInput.setHintTextColor(0xFF888888)
    keywordInput.setBackgroundColor(0xFF333333)
    keywordInput.setPadding(10, 8, 10, 8)
    keywordInput.setTextSize(12)
    keywordInput.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
    keywordLayout.addView(keywordInput)
    layout.addView(keywordLayout)
    local addBtn = Button(service)
    addBtn.setText("Add Shortcut")
    addBtn.setBackgroundColor(0xFF4CAF50)
    addBtn.setTextColor(0xFFFFFFFF)
    addBtn.setPadding(10, 10, 10, 10)
    addBtn.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
    addBtn.onClick = function()
        local contactName = tostring(contactInput.getText()):gsub("^%s*(.-)%s*$", "%1")
        local keyword = tostring(keywordInput.getText()):gsub("^%s*(.-)%s*$", "%1")
        if contactName == "" or keyword == "" then
            speak("Please enter both fields")
            return
        end
        local keywords = getContactKeywords()
        keywords[contactName] = keyword
        saveContactKeywords(keywords)
        contactInput.setText("")
        keywordInput.setText("")
        speak("Keyword added")
        if contactKeywordsDialog then contactKeywordsDialog.dismiss() end
        showSettingsSubDialog()
    end
    layout.addView(addBtn)
    local backBtn = Button(service)
    backBtn.setText("Back to Settings")
    backBtn.setBackgroundColor(0xFF2196F3)
    backBtn.setTextColor(0xFFFFFFFF)
    backBtn.setPadding(10, 10, 10, 10)
    backBtn.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
    backBtn.onClick = function()
        if contactKeywordsDialog then contactKeywordsDialog.dismiss() end
        showSettingsSubDialog()
    end
    layout.addView(backBtn)
    contactKeywordsDialog = LuaDialog(service)
    contactKeywordsDialog.setTitle("Contact Shortcuts")
    contactKeywordsDialog.setView(layout)
    contactKeywordsDialog.setCancelable(true)
    contactKeywordsDialog.show()
    speak("Contact shortcuts")
end

function isWhatsAppInstalled(packageName)
    local pm = service.getPackageManager()
    local intent = pm.getLaunchIntentForPackage(packageName)
    return intent ~= nil
end

function getInstalledWhatsAppApps()
    local installedApps = {}
    if isWhatsAppInstalled(WHATSAPP_PACKAGES.messenger) then
        table.insert(installedApps, {
            name = "WhatsApp Messenger",
            package = WHATSAPP_PACKAGES.messenger,
            color = 0xFF25D366
        })
    end
    if isWhatsAppInstalled(WHATSAPP_PACKAGES.business) then
        table.insert(installedApps, {
            name = "WhatsApp Business",
            package = WHATSAPP_PACKAGES.business,
            color = 0xFF25D366
        })
    end
    return installedApps
end

function cleanPhoneNumber(number)
    if not number then return "" end
    return number:gsub("[%s%-%(%)+]", "")
end

function showContactSelectionDialog(contacts, actionType, callback)
    if #contacts == 0 then
        speak("No contacts")
        if callback then callback(nil) end
        return
    end
    if #contacts == 1 then
        if callback then callback(contacts[1]) end
        return
    end
    local layout = LinearLayout(service)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(15, 15, 15, 15)
    layout.setBackgroundColor(0xFF0A0A0A)
    local title = TextView(service)
    title.setText("Select Contact")
    title.setTextColor(0xFF2196F3)
    title.setTextSize(16)
    title.setTypeface(nil, Typeface.BOLD)
    title.setGravity(Gravity.CENTER)
    title.setPadding(0, 0, 0, 10)
    layout.addView(title)
    for i, contact in ipairs(contacts) do
        local btn = Button(service)
        local displayText = contact.name
        if contact.number then
            local formattedNumber = contact.number
            if #formattedNumber > 6 then
                formattedNumber = "..." .. formattedNumber:sub(#formattedNumber-5)
            end
            displayText = displayText .. " (" .. formattedNumber .. ")"
        end
        btn.setText(displayText)
        btn.setBackgroundColor(0xFF2196F3)
        btn.setTextColor(0xFFFFFFFF)
        btn.setPadding(10, 10, 10, 10)
        btn.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
        btn.onClick = function()
            if contactSelectionDialog then
                contactSelectionDialog.dismiss()
                contactSelectionDialog = nil
            end
            if callback then callback(contact) end
        end
        layout.addView(btn)
        if i < #contacts then
            local space = View(service)
            space.setLayoutParams(LinearLayout.LayoutParams(-1, 3))
            layout.addView(space)
        end
    end
    local cancelBtn = Button(service)
    cancelBtn.setText("Cancel")
    cancelBtn.setBackgroundColor(0xFFF44336)
    cancelBtn.setTextColor(0xFFFFFFFF)
    cancelBtn.setPadding(10, 10, 10, 10)
    cancelBtn.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
    cancelBtn.onClick = function()
        if contactSelectionDialog then
            contactSelectionDialog.dismiss()
            contactSelectionDialog = nil
        end
        speak("Cancelled")
        if callback then callback(nil) end
    end
    layout.addView(cancelBtn)
    contactSelectionDialog = LuaDialog(service)
    contactSelectionDialog.setTitle("Contact Selection")
    contactSelectionDialog.setView(layout)
    contactSelectionDialog.setCancelable(true)
    contactSelectionDialog.show()
    speak("Multiple contacts")
end

function showWhatsAppSelectionDialog(contactName, phoneNumber, callType, callback)
    local installedApps = getInstalledWhatsAppApps()
    if #installedApps == 0 then
        speak("No WhatsApp")
        if callback then callback(nil) end
        return
    end
    local preference = getWhatsAppPreference()
    if preference == WHATSAPP_PREF_MESSENGER then
        for _, app in ipairs(installedApps) do
            if app.package == WHATSAPP_PACKAGES.messenger then
                if callback then callback(WHATSAPP_PACKAGES.messenger) end
                return
            end
        end
    elseif preference == WHATSAPP_PREF_BUSINESS then
        for _, app in ipairs(installedApps) do
            if app.package == WHATSAPP_PACKAGES.business then
                if callback then callback(WHATSAPP_PACKAGES.business) end
                return
            end
        end
    end
    if #installedApps == 1 then
        if callback then callback(installedApps[1].package) end
        return
    end
    local layout = LinearLayout(service)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(15, 15, 15, 15)
    layout.setBackgroundColor(0xFF0A0A0A)
    local title = TextView(service)
    title.setText("Select WhatsApp")
    title.setTextColor(0xFF2196F3)
    title.setTextSize(16)
    title.setTypeface(nil, Typeface.BOLD)
    title.setGravity(Gravity.CENTER)
    title.setPadding(0, 0, 0, 10)
    layout.addView(title)
    for i, app in ipairs(installedApps) do
        local btn = Button(service)
        btn.setText(app.name)
        btn.setBackgroundColor(app.color)
        btn.setTextColor(0xFFFFFFFF)
        btn.setPadding(10, 10, 10, 10)
        btn.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
        btn.onClick = function()
            if selectionDialog then
                selectionDialog.dismiss()
                selectionDialog = nil
            end
            if callback then callback(app.package) end
        end
        layout.addView(btn)
        if i < #installedApps then
            local space = View(service)
            space.setLayoutParams(LinearLayout.LayoutParams(-1, 8))
            layout.addView(space)
        end
    end
    local cancelBtn = Button(service)
    cancelBtn.setText("Cancel")
    cancelBtn.setBackgroundColor(0xFFF44336)
    cancelBtn.setTextColor(0xFFFFFFFF)
    cancelBtn.setPadding(10, 10, 10, 10)
    cancelBtn.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
    cancelBtn.onClick = function()
        if selectionDialog then
            selectionDialog.dismiss()
            selectionDialog = nil
        end
        speak("Cancelled")
        if callback then callback(nil) end
    end
    layout.addView(cancelBtn)
    selectionDialog = LuaDialog(service)
    selectionDialog.setTitle("WhatsApp Selection")
    selectionDialog.setView(layout)
    selectionDialog.setCancelable(true)
    selectionDialog.show()
    speak("Select WhatsApp")
end

function startWhatsAppCall(packageName, contactName, phoneNumber, callType)
    if not packageName then 
        speak("WhatsApp not selected")
        return 
    end
    local cleanNumber = cleanPhoneNumber(phoneNumber)
    if cleanNumber:sub(1,1) == "0" then 
        cleanNumber = "92" .. cleanNumber:sub(2) 
    end
    local url = "https://wa.me/" .. cleanNumber
    local intent = Intent(Intent.ACTION_VIEW)
    intent.setData(Uri.parse(url))
    intent.setPackage(packageName)
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    local appName = (packageName == WHATSAPP_PACKAGES.messenger) and "WhatsApp Messenger" or "WhatsApp Business"
    speak("Opening " .. appName .. " for " .. contactName)
    service.startActivity(intent)
    Handler().postDelayed(function()
        if callType == "voice" then
            Handler().postDelayed(function()
                service.click({
                    {"Voice call", "Call"}
                })
            end, CONSTANTS.DELAYS.SHORT)
            Handler().postDelayed(function()
                service.click({
                    {"Voice call"}
                })
            end, CONSTANTS.DELAYS.MEDIUM)
            Handler().postDelayed(function()
                speak(appName .. " voice call started with " .. contactName)
            end, CONSTANTS.DELAYS.LONG)
        elseif callType == "video" then
            Handler().postDelayed(function()
                service.click({
                    {"Video call", "Call"}
                })
            end, CONSTANTS.DELAYS.SHORT)
            Handler().postDelayed(function()
                service.click({
                    {"Video call"}
                })
            end, CONSTANTS.DELAYS.MEDIUM)
            Handler().postDelayed(function()
                speak(appName .. " video call started with " .. contactName)
            end, CONSTANTS.DELAYS.LONG)
        elseif callType == "chat" then
            Handler().postDelayed(function()
                speak(appName .. " chat opened with " .. contactName)
            end, CONSTANTS.DELAYS.SHORT)
        end
    end, CONSTANTS.DELAYS.SHORT)
end

function getContactsFromGroup(groupName)
    local contacts = {}
    local cur = service.getContentResolver().query(
        ContactsContract.CommonDataKinds.Phone.CONTENT_URI, 
        nil, 
        "display_name LIKE ?", 
        {"%"..groupName.."%"}, 
        "display_name ASC"
    )
    if cur then
        while cur.moveToNext() do
            local contactName = cur.getString(cur.getColumnIndex("display_name"))
            local phoneNumber = cur.getString(cur.getColumnIndex("data1"))
            if contactName and phoneNumber then
                table.insert(contacts, {
                    name = contactName,
                    number = phoneNumber,
                    cleanedNumber = cleanPhoneNumber(phoneNumber)
                })
            end
        end
        cur.close()
    end
    return contacts
end

function runCalls(input)
    local name = ""
    local actionType = ""
    if input:find("^" .. getCommandKeyword("voice call") .. " ") then
        name = input:gsub("^" .. getCommandKeyword("voice call") .. " ", ""):gsub("^%s*(.-)%s*$", "%1")
        actionType = "voice"
    elseif input:find("^" .. getCommandKeyword("video call") .. " ") then
        name = input:gsub("^" .. getCommandKeyword("video call") .. " ", ""):gsub("^%s*(.-)%s*$", "%1")
        actionType = "video"
    elseif input:find("^" .. getCommandKeyword("chat") .. " ") then
        name = input:gsub("^" .. getCommandKeyword("chat") .. " ", ""):gsub("^%s*(.-)%s*$", "%1")
        actionType = "chat"
    elseif input:find("^" .. getCommandKeyword("call") .. " ") then
        name = input:gsub("^" .. getCommandKeyword("call") .. " ", ""):gsub("^%s*(.-)%s*$", "%1")
        actionType = "phone"
    else 
        return false 
    end
    if name == "" then return false end
    local actualContactName = getContactByKeyword(name)
    if actualContactName then
        speak("Shortcut: " .. actualContactName)
        name = actualContactName
    end
    local contacts = {}
    local uniqueContacts = {}
    local groupContacts = getContactsFromGroup(name)
    for _, gc in ipairs(groupContacts) do
        local key = gc.name .. "_" .. gc.cleanedNumber
        if not uniqueContacts[key] then
            table.insert(contacts, gc)
            uniqueContacts[key] = true
        end
    end
    local cur = service.getContentResolver().query(
        ContactsContract.CommonDataKinds.Phone.CONTENT_URI, 
        nil, 
        "display_name LIKE ?", 
        {"%"..name.."%"}, 
        "display_name ASC"
    )
    if cur then
        while cur.moveToNext() do
            local contactName = cur.getString(cur.getColumnIndex("display_name"))
            local phoneNumber = cur.getString(cur.getColumnIndex("data1"))
            local contactId = cur.getString(cur.getColumnIndex("contact_id"))
            if contactName and phoneNumber then
                local cleanedNumber = cleanPhoneNumber(phoneNumber)
                local uniqueKey = contactName .. "_" .. cleanedNumber
                if not uniqueContacts[uniqueKey] then
                    table.insert(contacts, {
                        name = contactName,
                        number = phoneNumber,
                        cleanedNumber = cleanedNumber,
                        contactId = contactId
                    })
                    uniqueContacts[uniqueKey] = true
                end
            end
        end
        cur.close()
    end
    table.sort(contacts, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    if #contacts == 0 then
        speak("Contact not found")
        return true
    end
    if #contacts == 1 then
        local contact = contacts[1]
        if actionType == "chat" or actionType == "voice" or actionType == "video" then
            showWhatsAppSelectionDialog(contact.name, contact.number, actionType, function(packageName)
                if packageName then
                    startWhatsAppCall(packageName, contact.name, contact.number, actionType)
                end
            end)
        else
            local intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:"..contact.number))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            service.startActivity(intent)
            speak("Calling " .. contact.name)
        end
        return true
    end
    currentContactSelection = {
        actionType = actionType,
        contacts = contacts
    }
    showContactSelectionDialog(contacts, actionType, function(selectedContact)
        if not selectedContact then return end
        if actionType == "chat" or actionType == "voice" or actionType == "video" then
            showWhatsAppSelectionDialog(selectedContact.name, selectedContact.number, actionType, function(packageName)
                if packageName then
                    startWhatsAppCall(packageName, selectedContact.name, selectedContact.number, actionType)
                end
            end)
        else
            local intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:"..selectedContact.number))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            service.startActivity(intent)
            speak("Calling " .. selectedContact.name)
        end
    end)
    return true
end

function runMediaSearch(input)
    input = input:lower()
    if not input:find("^search .* on ") then return false end
    local query, platform
    if input:find("^search song .* on youtube music$") then
        query = input:gsub("^search song ", ""):gsub(" on youtube music$", ""):gsub("^%s*(.-)%s*$", "%1")
        platform = "youtube music"
    elseif input:find("^search .* on youtube$") then
        query = input:gsub("^search ", ""):gsub(" on youtube$", ""):gsub("^%s*(.-)%s*$", "%1")
        platform = "youtube"
    elseif input:find("^search .* on spotify$") then
        query = input:gsub("^search ", ""):gsub(" on spotify$", ""):gsub("^%s*(.-)%s*$", "%1")
        platform = "spotify"
    elseif input:find("^search .* on google$") then
        query = input:gsub("^search ", ""):gsub(" on google$", ""):gsub("^%s*(.-)%s*$", "%1")
        platform = "google"
    elseif input:find("^search .* on play store$") then
        query = input:gsub("^search ", ""):gsub(" on play store$", ""):gsub("^%s*(.-)%s*$", "%1")
        platform = "play store"
    else
        return false
    end
    if not query or query == "" then return false end
    speak("Searching " .. query .. " on " .. platform)
    local intent = nil
    if platform == "spotify" then
        intent = Intent(Intent.ACTION_VIEW, Uri.parse("spotify:search:" .. Uri.encode(query)))
    elseif platform == "play store" then
        intent = Intent(Intent.ACTION_VIEW, Uri.parse("market://search?q=" .. Uri.encode(query)))
        intent.setPackage("com.android.vending")
    elseif platform == "youtube music" then
        intent = Intent(Intent.ACTION_SEARCH)
        intent.setPackage("com.google.android.apps.youtube.music")
        intent.putExtra(SearchManager.QUERY, query)
    elseif platform == "youtube" then
        intent = Intent(Intent.ACTION_SEARCH)
        intent.setPackage("com.google.android.youtube")
        intent.putExtra(SearchManager.QUERY, query)
    elseif platform == "google" then
        intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=" .. Uri.encode(query)))
    end
    if intent then
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        service.startActivity(intent)
    end
    return true
end

function runSystem(input)
    if input:find(getCommandKeyword("show menu")) then
        showSettingsDialog()
        return true
    end
    if input:find(getCommandKeyword("show commands")) then
        showAllCommandsDialog()
        return true
    end
    if input == getCommandKeyword("tf") then
        speak("Turning off Jieshuo")
        service.disableSelf()
        return true
    end
    if input == getCommandKeyword("rs") then
        speak("Restarting")
        os.exit(0)
        return true
    end
    if input:find(getCommandKeyword("accessibility settings")) then
        service.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS):addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        speak("Accessibility")
        return true
    end
    if input:find(getCommandKeyword("how to use")) then
        openHowToUseVideo()
        return true
    end
    if input == getCommandKeyword("send now") then
        if service.click({
            {"%Direct long press", "Share|Send", "WhatsApp|WhatsApp Business"}
        }) then
            speak("Sent")
        else
            speak("Share not found")
        end
        return true
    end
    if input == getCommandKeyword("uninstall") then
        if service.click({{"%Long press", "Uninstall"}}) then
            Handler().postDelayed(function()
                if service.click({{"Uninstall"}, {"OK"}}) then
                    speak("Uninstalled")
                else
                    speak("Confirmation button not found")
                end
            end, CONSTANTS.DELAYS.LONG)
        else
            speak("Uninstall not found")
        end
        return true
    end
    if input:find(getCommandKeyword("current battery")) then
        local lvl = service.registerReceiver(nil, IntentFilter(Intent.ACTION_BATTERY_CHANGED)).getIntExtra("level", -1)
        speak("Battery " .. lvl .. "%") 
        return true
    end
    if input:find(getCommandKeyword("current time")) then
        speak("Time " .. os.date("%I:%M %p")) 
        return true
    end
    if input:find(getCommandKeyword("current date")) then
        return speakCurrentDate()
    end
    if input:find(getCommandKeyword("speech rate")) then
        local rate = tonumber(input:match("(%d+)"))
        if rate then 
            service.setTTSSpeed(rate) 
            speak("Speech rate set to " .. rate) 
            return true 
        end
    end
    if input == getCommandKeyword("silent") or input == getCommandKeyword("mute") or input:find(getCommandKeyword("toggle silent mode")) then
        local audioManager = service.getSystemService(Context.AUDIO_SERVICE)
        local nm = service.getSystemService(Context.NOTIFICATION_SERVICE)
        if not nm.isNotificationPolicyAccessGranted() then
            speak("Please grant Do Not Disturb access first")
            local intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            service.startActivity(intent)
            return true
        end
        local mode = audioManager.getRingerMode()
        if mode == AudioManager.RINGER_MODE_NORMAL then
            audioManager.setRingerMode(AudioManager.RINGER_MODE_VIBRATE)
            speak("Vibration mode")
            playSoundTick()
            vibrateDevice()
        elseif mode == AudioManager.RINGER_MODE_VIBRATE then
            audioManager.setRingerMode(AudioManager.RINGER_MODE_SILENT)
            speak("Silent mode")
            playSoundTick()
            vibrateDevice()
        else
            audioManager.setRingerMode(AudioManager.RINGER_MODE_NORMAL)
            speak("Normal mode")
            playSoundTick()
            vibrateDevice()
        end
        return true
    end
    if input == getCommandKeyword("toggle bluetooth") then
        local bt = BluetoothAdapter.getDefaultAdapter()
        if bt then
            if bt.isEnabled() then
                bt.disable()
                speak("Bluetooth service has been disabled. Develop by Muhammad Hanzla")
                playSoundTick()
                vibrateDevice()
            else
                bt.enable()
                speak("Bluetooth service has been enabled. Develop by Muhammad Hanzla")
                playSoundTick()
                vibrateDevice()
            end
        else
            speak("Bluetooth not supported")
        end
        return true
    end
    if input == getCommandKeyword("toggle flashlight") then
        local cm = service.getSystemService(Context.CAMERA_SERVICE)
        local list = cm.getCameraIdList()
        if list and #list > 0 then
            isFlashOn = not isFlashOn
            cm.setTorchMode(list[0], isFlashOn)
            if isFlashOn then
                speak("Flashlight turned on. Develop by Muhammad Hanzla")
                playSoundTick()
                vibrateDevice()
            else
                speak("Flashlight turned off. Develop by Muhammad Hanzla")
                playSoundTick()
                vibrateDevice()
            end
        end
        return true
    end
    if input == getCommandKeyword("toggle mobile data") then
        local intent = Intent("android.settings.panel.action.INTERNET_CONNECTIVITY")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        service.startActivity(intent)
        Handler().postDelayed(function()
            local btnList = {"Mobile data", {"Turn off", "OK", "确定", "关闭"}, "Mobile data"}
            local success = service.click(btnList)
            if success then
                service.playSoundTick()
                speak("Mobile data has been toggled successfully")
                vibrateDevice()
                Handler().postDelayed(function()
                    service.toBack()
                end, CONSTANTS.DELAYS.FAST)
            else
                Handler().postDelayed(function()
                    if service.click(btnList) then
                        service.playSoundTick()
                        speak("Mobile data is now switched")
                        vibrateDevice()
                        service.toBack()
                    end
                end, CONSTANTS.DELAYS.SHORT)
            end
        end, CONSTANTS.DELAYS.NORMAL)
        return true
    end
    if input == getCommandKeyword("wf") then
        local intent = Intent("android.settings.panel.action.INTERNET_CONNECTIVITY")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        service.startActivity(intent)
        Handler().postDelayed(function()
            local btnList = {"Wi-Fi", {"Turn off", "OK", "确定", "关闭", "WLAN"}, "Wi-Fi"}
            local success = service.click(btnList)
            if success then
                service.playSoundTick()
                speak("Wi-Fi toggled")
                vibrateDevice()
                Handler().postDelayed(function()
                    service.toBack()
                end, CONSTANTS.DELAYS.FAST)
            else
                Handler().postDelayed(function()
                    if service.click(btnList) then
                        service.playSoundTick()
                        speak("Wi-Fi toggled")
                        vibrateDevice()
                        service.toBack()
                    end
                end, CONSTANTS.DELAYS.SHORT)
            end
        end, CONSTANTS.DELAYS.NORMAL)
        return true
    end

    local vol = tonumber(input:match("(%d+)"))
    if vol then
        local am = service.getSystemService(Context.AUDIO_SERVICE)
        local stream = -1
        if input:find(getCommandKeyword("accessibility volume")) then
            stream = AudioManager.STREAM_ACCESSIBILITY
        elseif input:find(getCommandKeyword("ring volume")) then
            stream = AudioManager.STREAM_RING
        elseif input:find(getCommandKeyword("alarm volume")) then
            stream = AudioManager.STREAM_ALARM
        elseif input:find(getCommandKeyword("notification volume")) then
            stream = AudioManager.STREAM_NOTIFICATION
        elseif input:find(getCommandKeyword("volume")) then
            stream = AudioManager.STREAM_MUSIC
        end
        if stream ~= -1 then
            local maxVol = am.getStreamMaxVolume(stream)
            local targetVol = math.floor((vol/100)*maxVol)
            am.setStreamVolume(stream, targetVol, 1)
            speak("Volume set to " .. vol .. " percent")
            return true
        end
    end
    return false
end

function runDirectAction(input)
    if input == getCommandKeyword("mention all") then
        service.playSoundTick()
        service.paste("@")
        Handler().postDelayed(function()
            if service.click({
                {
                    "all, Mention all members in this chat",
                    "Send",
                }
            }) then
                speak("All members mentioned")
                return true
            end
        end, CONSTANTS.DELAYS.SHORT)
        return true
    end
    
    if input == getCommandKeyword("clear chat") then
        if service.click({
            {
                "More options$50",
                "More*$100",
                "*Clear chat*>6",
                "CLEAR CHAT (*>120",
            }
        }) then
            speak("Chat cleared")
            return true
        else
            speak("Option not found")
        end
        return true
    end
    
    if input == getCommandKeyword("only admin") then
        if service.click({
            {"*More options*>2",
            "*Group info*>2",
            "<More options*>2",
            "*Group permissions*>2",
            "*Send*",
            "*Back<2",
            }
        }) then
            speak("Admin only mode set")
            return true
        else
            speak("Option not found")
        end
        return true
    end
    
    if input == getCommandKeyword("rename it") then
        if service.click({
            {"%Direct long press",
            "Rename|More",
            "Rename",
            }
        }) then
            speak("Rename option selected")
            return true
        else
            speak("Option not found")
        end
        return true
    end
    
    if input == getCommandKeyword("delete from everyone") then
        if service.click({
            {"%Direct long press", "Delete", "Delete for everyone", "DELETE"}
        }) then
            Handler().postDelayed(function()
                service.click({
                    {"DELETE", "Delete", "YES", "Yes"}
                })
                speak("Deleted for everyone")
            end, CONSTANTS.DELAYS.SHORT)
        else
            speak("Option not found")
        end
        return true
    end
    if input == getCommandKeyword("delete from me") then
        if service.click({
            {"%Direct long press", "Delete", "Delete for me", "DELETE"}
        }) then
            Handler().postDelayed(function()
                service.click({
                    {"DELETE", "Delete", "YES", "Yes"}
                })
                speak("Deleted for me")
            end, CONSTANTS.DELAYS.SHORT)
        else
            speak("Option not found")
        end
        return true
    end
    if input == getCommandKeyword("delete now") then
        if service.click({
            {"%Direct long press", "Delete", "DELETE"}
        }) then
            Handler().postDelayed(function()
                service.click({
                    {"DELETE", "Delete", "YES", "Yes"}
                })
                speak("Deleted")
            end, CONSTANTS.DELAYS.SHORT)
        else
            speak("Option not found")
        end
        return true
    end
    if input == getCommandKeyword("delete number") then
        if service.click({
            {"%Direct click", "More options", "View contact", "More options", "Delete contact", "DELETE"}
        }) then
            speak("Contact deleted")
        else
            speak("Option not found")
        end
        return true
    end
    if input == getCommandKeyword("application info") then
        local root = service.getRootInActiveWindow()
        if root then
            local intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:"..tostring(root.getPackageName())))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            service.startActivity(intent)
            speak("Application info")
        else
            speak("No app open")
        end
        return true
    end
    if input:find("^" .. getCommandKeyword("open") .. " ") then
        local appName = input:gsub("^" .. getCommandKeyword("open") .. " ", ""):gsub("^%s*(.-)%s*$", "%1"):lower()
        return openAppWithForceLogic(appName)
    end
    if input == getCommandKeyword("talk with me") then
        local packageName = "com.openai.chatgpt"
        local pm = service.getPackageManager()
        local intent = pm.getLaunchIntentForPackage(packageName)
        if intent then
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            service.startActivity(intent)
            speak("Opening ChatGPT")
            Handler().postDelayed(function()
                if service.click({
                    {"Start a voice conversation"}
                }) then
                    speak("Starting voice conversation")
                else
                    speak("Could not find the voice conversation button")
                end
            end, CONSTANTS.DELAYS.LONG)
        else
            speak("ChatGPT is not installed. Opening Play Store to install.")
            local playIntent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" .. packageName))
            playIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            service.startActivity(playIntent)
        end
        return true
    end
    if input == getCommandKeyword("check update") then
        checkUpdate(true)
        return true
    end
    local fmt = input:gsub("(%a)([%w']*)", function(f, r) return f:upper()..r:lower() end)
    if service.click({{"%" .. fmt}}) then 
        speak("Clicked " .. fmt)
        return true 
    end
    if service.click({input}) then 
        speak("Clicked " .. input)
        return true 
    end
    return false
end

function startSmartAssistant()
    stopAllSpeechRecognizers()
    vibrateDevice()
    speakListening()
    requestAudioFocus()
    local now = System.currentTimeMillis()
    if now - lastCommandTime < CONSTANTS.DELAYS.FAST then lastCommandTime = now; return end
    lastCommandTime = now
    mainSpeechRecognizer = SpeechRecognizer.createSpeechRecognizer(service)
    local intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
    intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
    intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
    intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
    intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
    intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 10000)
    intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 800)
    intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 800)
    if isNoisyModeEnabled() then
        intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1500)
        intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1500)
    end
    local listener = RecognitionListener {
        onResults = function(results)
            isListening = false; abandonAudioFocus()
            local arr = results.getParcelableArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            if arr and arr.size() > 0 then
                for i = 0, math.min(arr.size() - 1, 2) do
                    local input = arr.get(i):lower()
                    if runCalls(input) then 
                        mainSpeechRecognizer = destroySpeechRecognizer(mainSpeechRecognizer); return 
                    end
                    if runMediaSearch(input) then
                        mainSpeechRecognizer = destroySpeechRecognizer(mainSpeechRecognizer); return 
                    end
                    if runSystem(input) then 
                        mainSpeechRecognizer = destroySpeechRecognizer(mainSpeechRecognizer); return 
                    end
                    if runDirectAction(input) then 
                        mainSpeechRecognizer = destroySpeechRecognizer(mainSpeechRecognizer); return 
                    end
                end
                speak("Not recognized")
            end
            mainSpeechRecognizer = destroySpeechRecognizer(mainSpeechRecognizer)
        end,
        onError = function(e)
            isListening = false; abandonAudioFocus()
            if e == SpeechRecognizer.ERROR_NO_MATCH then
                speak("Not recognized")
            elseif e == SpeechRecognizer.ERROR_SPEECH_TIMEOUT then
                speakListening()
            elseif e == SpeechRecognizer.ERROR_NETWORK then
                speak("Network error")
            elseif e == SpeechRecognizer.ERROR_AUDIO then
                speak("Audio error")
            else
                speak("Error, try again")
            end
            mainSpeechRecognizer = destroySpeechRecognizer(mainSpeechRecognizer)
        end
    }
    mainSpeechRecognizer.setRecognitionListener(listener)
    Handler().postDelayed(function()
        if mainSpeechRecognizer then
            pcall(function() mainSpeechRecognizer.startListening(intent); isListening = true end)
        end
    end, CONSTANTS.DELAYS.VERY_FAST)
end

function showWelcomeDialog()
    local pref = getPref()
    local welcomeShown = pref.getBoolean(WELCOME_DIALOG_SHOWN_KEY, false)
    if welcomeShown then return false end
    local layout = LinearLayout(service)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(30, 30, 30, 30)
    layout.setBackgroundColor(0xFF0A0A0A)
    local title = TextView(service)
    title.setText("Welcome to Advance Voice Assistant by Tech for V I")
    title.setTextColor(0xFF2196F3)
    title.setTextSize(18)
    title.setTypeface(nil, Typeface.BOLD)
    title.setGravity(Gravity.CENTER)
    title.setPadding(0, 0, 0, 20)
    layout.addView(title)
    local instruction = TextView(service)
    instruction.setText("If you are using this extension for the first time, please click the 'Watch Tutorial' button to watch the video.")
    instruction.setTextColor(0xFFFFFFFF)
    instruction.setTextSize(14)
    instruction.setGravity(Gravity.CENTER)
    instruction.setPadding(0, 0, 0, 20)
    layout.addView(instruction)
    local dontShowCheckBox = CheckBox(service)
    dontShowCheckBox.setText("Don't show this again")
    dontShowCheckBox.setTextColor(0xFFFFFFFF)
    dontShowCheckBox.setTextSize(12)
    dontShowCheckBox.setPadding(10, 15, 10, 15)
    layout.addView(dontShowCheckBox)
    local buttonLayout = LinearLayout(service)
    buttonLayout.setOrientation(LinearLayout.HORIZONTAL)
    buttonLayout.setGravity(Gravity.CENTER)
    buttonLayout.setPadding(0, 20, 0, 0)
    local tutorialBtn = Button(service)
    tutorialBtn.setText("Watch Tutorial")
    tutorialBtn.setBackgroundColor(0xFF2196F3)
    tutorialBtn.setTextColor(0xFFFFFFFF)
    tutorialBtn.setPadding(15, 12, 15, 12)
    tutorialBtn.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
    local okayBtn = Button(service)
    okayBtn.setText("Okay")
    okayBtn.setBackgroundColor(0xFF4CAF50)
    okayBtn.setTextColor(0xFFFFFFFF)
    okayBtn.setPadding(15, 12, 15, 12)
    okayBtn.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
    buttonLayout.addView(tutorialBtn)
    buttonLayout.addView(okayBtn)
    layout.addView(buttonLayout)
    local dialog = LuaDialog(service)
    dialog.setTitle("Welcome!")
    dialog.setView(layout)
    dialog.setCancelable(false)
    tutorialBtn.onClick = function()
        if dontShowCheckBox.isChecked() then
            getEdit().putBoolean(WELCOME_DIALOG_SHOWN_KEY, true)
            getEdit().commit()
        end
        dialog.dismiss()
        openHowToUseVideo()
    end
    okayBtn.onClick = function()
        if dontShowCheckBox.isChecked() then
            getEdit().putBoolean(WELCOME_DIALOG_SHOWN_KEY, true)
            getEdit().commit()
        end
        dialog.dismiss()
        startSmartAssistant()
    end
    dialog.show()
    return true
end

Thread(createRunnable(function()
    Thread.sleep(2000)
    if not autoCheckDone then
        autoCheckDone = true
        checkUpdate(false)
    end
end)).start()

initializeTTS()
if not showWelcomeDialog() then 
    startSmartAssistant()
end