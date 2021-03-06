





var NS = NS || {};
window.addEventListener("load", function() {

	function isLocalStorage(){
		var test = 'test';
		try {
			localStorage.setItem(test, test);
			localStorage.removeItem(test);
			return true;
		} catch(e) {
			return false;
		}
	}

	var loader = NS.sessionStatusLoader;
	var ui = NS.sessionStatusUI;
	var bus;
	if (isLocalStorage() === true) {
		bus = NS.sessionStatusBus;
	}
	else {
		bus = NS.sessionStatusBusLegacy;
	}

	loader.init.bind(loader.internal) ({
		"successListener": bus.sessionStatusLoadSuccess.bind(bus.internal),
		"errorListener": bus.sessionStatusLoadError.bind(bus.internal)
	});

    

	ui.init.bind(ui) ({
        "id": 248591402,
        "entityId": 48420976,
		"roleId": 1052,
		"companyId": "5183710",
		"refreshHandler": function() { bus.schedule.bind(bus.internal)(0); /* immediately*/},
        translation: {
            loggedOut: {
                title: "You have been logged out.",
                description: "Click the button to log in again.",
                button: "Log In"
            },
            wrongRole: {
                title: "This tab requires a different role.",
                description: "Please switch to the role <b>BC GHO - Fraud A/R</b> in  <b>Backcountry.com (Production 1+)</b> by clicking the button below.",
                button: "Change Role"
            },
            expiring: {
                title: "Your session is about to expire.",
                description: "You have been idle for some time. Your session will expire in <b id='count'>?</b> second(s).",
                button: "Keep Session Active"
            },
            connectionError: {
                title: "Offline"
            }
        },
    });

	bus.init.bind(bus.internal) ({
		"sessionStatusLoader": loader.load.bind(loader.internal),
		"sessionStatusListener" : ui.onSessionStatus.bind(ui),
		"errorListener": ui.onError.bind(ui)
	});

	// starting the bus
	if (null=== true) {
		bus.schedule.bind(bus.internal)(0);
	}
	else {
		bus.schedule.bind(bus.internal)(bus.internal.normalInterval);
	}

}, false);
