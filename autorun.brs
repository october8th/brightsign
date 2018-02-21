'no local storage
Sub Main(args)

	url$ = "file:///index.html"
	'url$ = "http://www.mysitehere.com" disabled
	if args <> invalid and args.Count() > 0 then
		url$ = args[0]
	end if
	print "url = ";url$

	
	'reboots if html node not already enabled
	rs = createobject("roregistrysection", "html")
	mp = rs.read("mp")
	if mp <> "1" then
	    rs.write("mp","1")
	    rs.flush()
	    RebootSystem()	
	endif


	DoCanonicalInit()

	CreateHtmlWidget(url$)

	HandleEvents()
End Sub
Function DoCanonicalInit()

	gaa =  GetGlobalAA()

	EnableZoneSupport(1)
	OpenOrCreateCurrentLog()

	' Enable mouse cursor
	gaa.touchScreen = CreateObject("roTouchScreen")
	gaa.touchScreen.EnableCursor(true)

	gaa.mp = CreateObject("roMessagePort")

	gaa.gpioPort = CreateObject("roGpioControlPort")
	gaa.gpioPort.SetPort(gaa.mp)

	gaa.vm = CreateObject("roVideoMode")
	gaa.vm.setMode("auto")

	' set DWS on device
	nc = CreateObject("roNetworkConfiguration", 0)
	if type(nc) <> "roNetworkConfiguration" then
		nc = CreateObject("roNetworkConfiguration", 1)
	endif
	if type(nc) = "roNetworkConfiguration" then
		dwsAA = CreateObject("roAssociativeArray")
		dwsAA["port"] = "80"
		nc.SetupDWS(dwsAA)
		nc.Apply()
	endif

	gaa.hp = CreateObject("roNetworkHotplug")
	gaa.hp.setPort(gaa.mp)

End Function
Sub CreateHtmlWidget(url$ as String)

	gaa =  GetGlobalAA()
	width=gaa.vm.GetResX()
	height=gaa.vm.GetResY()
	rect=CreateObject("roRectangle", 0, 0, width, height)

	'new node 5-16-17
	is = {
	    port: 2999
	}
	config = {
	    	nodejs_enabled: true
	    	inspector_server: is
	    	brightsign_js_objects_enabled: true
		focus_enabled: true
		javascript_enabled: true
		url: url$
		storage_path: "SD:"
		storage_quota: 1073741824
	}
	'end new

	gaa.htmlWidget = CreateObject("roHtmlWidget", rect, config)	'new added config object after rect 5-16-17
	gaa.htmlWidget.Show()


End Sub
Sub HandleEvents()

	gaa =  GetGlobalAA()
	receivedIpAddr = false
	nc = CreateObject("roNetworkConfiguration", 0)
	currentConfig = nc.GetCurrentConfig()
	if currentConfig.ip4_address <> "" then
		' We already have an IP addr
		receivedIpAddr = true
		print "=== BS: already have an IP addr: ";currentConfig.ip4_address
	end if

	receivedLoadFinished = false
	while true
		ev = wait(0, gaa.mp)
		print "=== BS: Received event ";type(ev)
		if type(ev) = "roNetworkAttached" then
			print "=== BS: Received roNetworkAttached"
			receivedIpAddr = true
		else if type(ev) = "roHtmlWidgetEvent" then
			eventData = ev.GetData()
			if type(eventData) = "roAssociativeArray" and type(eventData.reason) = "roString" then
				if eventData.reason = "load-error" then
					print "=== BS: HTML load error: "; eventData.message
				else if eventData.reason = "load-finished" then
					print "=== BS: Received load finished"
					receivedLoadFinished = true
				else if eventData.reason = "message" then
					' To use this: msgPort.PostBSMessage({text: "my message"});
    					'm.logFile.SendLine(eventData.message.text)
    					'm.logFile.AsyncFlush()
				endif
			else
				print "=== BS: Unknown eventData: "; type(eventData)
			endif
		else if type(ev) = "roGpioButton" then
			if ev.GetInt() = 12 then stop
		else
			print "=== BS: Unhandled event: "; type(ev)
		end if
		if receivedIpAddr and receivedLoadFinished then
			print "=== BS: OK to show HTML, showing widget now"
			gaa.htmlWidget.Show()
			gaa.htmlWidget.PostJSMessage({msgtype:"htmlloaded"})
			receivedIpAddr = false
			receivedLoadFinished = false
		endif
	endwhile

End Sub

Sub OpenOrCreateCurrentLog()

	' if there is an existing log file for today, just append to it. otherwise, create a new one to use

        fileName$ = "log.txt"
        m.logFile = CreateObject("roAppendFile", fileName$)
        if type(m.logFile) = "roAppendFile" then
            return
        endif

    m.logFile = CreateObject("roCreateFile", fileName$)
    
End Sub
