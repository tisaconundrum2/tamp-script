









		

var isBackend = false;
var isDebug = false;
var isIE = isBackend || false;
var isIE9 = false;
var isIE10 = false;
var isIE11 = false;
var isFirefox = false;


(function(){
    var isShoppingSession = false;
    
    /* The core NetSuite object */
(function(window) {
    /* Sandbox */
    var document = window.document,
        location = window.location,
        navigator = window.navigator;

	var NS = window.NS || {};
	window.NS = NS;

	NS.UI = {
		Preferences: {
			horizontalLabelsEnabled: typeof isShoppingSession === 'undefined' ? false : isShoppingSession // determines the behavior of setFieldLabelRequired
		}
	};
    /*
     *******
     * NetSuite namespace and common functions
     ******
     */
    NS.Core = (function() {
        var guid = 0;

        return {
            getWindow: function() {
                return window;
            },

            getDocument: function() {
                return document;
            },

            getLocation: function() {
                return location;
            },

            getNavigator: function() {
                return navigator;
            },

            isUndefined: function(val) {
                return (typeof val === "undefined");
            },

            getURLParameter: function(param) {
                var val = new RegExp('[?&]' + param + '=([^&]*)').exec(location.search);
                return (val != null) ? decodeURIComponent(val[1]) : null;
            },

            getUniqueId: function() {
                return ++guid;
            }
        };
    }());

    /*
     ********
     * Event bus
     *
     * Example 1:
     *   NS.event.bind("my_event", function() { alert("Triggered"); });         // Bind event listener
     *   NS.event.once("my_event", function() { alert("One-time listener"); }); // Listener that is triggered only once
     *   NS.event.dispatch("my_event");                                         // Trigger event
     *
     * Example 2:
     *   NS.event.bind("my_event", function(e, data) {                          // Bind listener
     *      alert(data.value);                                                  // Output event parameters
     *      if (data.value) { NS.event.unbind(e.name, e.fn); }                  // Conditional unbind
     *   });
     *   NS.event.dispatch("my_event", { value: true });                        // Trigger event with parameters
     *
     * NOTE: Please don't use "dispatch" in code that may run on the server, use "dispatchImmediate" instead. Rhino doesn't have a setTimeout function that
     * is essential for asynchronous event dispatching.
     *
     ********
    */
	NS.event = (function() {
		var eventListeners = {};

		/*
		 Event object.

		 name: The name of the event that triggered the handler.
		 fn  : The handler function.
		 */
		function EventObject(name, fn) {
			this.name = name;
			this.fn = fn;
		}

		function ListenerObject(fn, condition, scope, once) {
			this.fn = fn;
			this.condition = condition;
			this.scope = scope;
			this.once = once;
		}

		function bindEvent(eventName, fn, condition, scope, once) {
			var listeners;

			if (!eventListeners[eventName]) {
				eventListeners[eventName] = {};
			}
			listeners = eventListeners[eventName];

			scope = scope || NS.Core.getWindow();
			fn.nsEventGuid = fn.nsEventGuid || NS.Core.getUniqueId();

			listeners[fn.nsEventGuid] = new ListenerObject(fn, condition, scope, once);
		}

		function listenerInvoker(eventName, listener, data) {
			return function () {
				var event = new EventObject(eventName, listener.fn);
				if (!listener.condition || listener.condition.call(listener.scope, event, data)) {
					listener.fn.call(listener.scope, event, data);
				}
			};
		}

		function emptyFunction() {
			return undefined;
		}

		return {
			/*
			 Attach a handler to an event.

			 eventName: The name of the event.
			 callback : Handler that is executed every time the event is triggered. The handler receives two
			 parameters: EventObject and Data. EventObject contains information about the event that
			 triggered the handler and reference to the handler itself. This information can be
			 used, e.g., to unbind the handler. The Data object contains user data passed to the event.
			 [scope]  : Optional. The scope of the handler function. Global scope is used if not defined otherwise.
			 */
			bind: function(eventName, callback, scope) {
				bindEvent(eventName, callback, null, scope, false);
			},

			/*
			 Attach a handler to an event. The handler is executed at most once.

			 eventName   : The name of the event.
			 callback    : Handler that is executed when the event is triggered.
			 [condition] : Optional. If defined the handler is executed only if the condition is true. If the condition
			 returns false the handler remains registered and waits for the next occurence of the event.
			 The condition function is executed with the same parameters as the handler.
			 [scope]     : Optional. The scope of the handler function. Global scope is used if not defined otherwise.
			 */
			once: function(eventName, callback, condition, scope) {
				bindEvent(eventName, callback, condition, scope, true);
			},

			/*
			 Execute all handlers attached to an event. Note that event dispatching is done asynchronously, i.e., the
			 listeners are NOT executed immediately.

			 eventName   : The name of the event.
			 data        : Additional parameters that will be passed to each listener.
			 doneHandler : Callback that is triggered when all event handlers sucesfully finish. May be undefined or null.
			 errorHandler: Callback that is triggered when any of the listeners fails. It is run after all listners for
			 the given event have been executed. May be undefined or null.
			 */
			dispatch: function(eventName, data, doneHandler, errorHandler) {
				var key, listeners, listener, invoker, wrapper;
				var listenersExecuted = 0, listenersFinished = 0, listenersTotal = 0;

				if (eventListeners[eventName]) {
					listeners = eventListeners[eventName];
					listenersTotal = Object.keys(listeners).length;

					for (key in listeners) {
						if (listeners.hasOwnProperty(key)) {
							listener = listeners[key];
							invoker = listenerInvoker(eventName, listener, data);

							if (listener.once) {
								delete listeners[key];
							}

							wrapper = (function(inner) {
								return function() {
									listenersExecuted++;
									if (listenersExecuted === listenersTotal) {
										setTimeout(function () {
											var finalHandler = ((listenersFinished === listenersTotal) ? doneHandler : errorHandler) || emptyFunction;
											finalHandler();
										}, 0);
									}
									inner();
									listenersFinished++;
								}
							})(invoker);

							setTimeout(wrapper, 0);
						}
					}
				}

				if (listenersTotal === 0 && doneHandler) {
					setTimeout(doneHandler, 0);
				}
			},
			/*
			 Synchronous execution of all handlers attached to an event.

			 eventName   : The name of the event.
			 data        : Additional parameters that will be passed to each listener.
			 doneHandler : Callback that is triggered when all event handlers sucesfully finish. May be undefined or null.
			 errorHandler: Callback that is triggered when any of the listeners fails. It is run after all listners for
			 the given event have been executed. May be undefined or null.
			 */
			dispatchImmediate: function(eventName, data, doneHandler, errorHandler) {
				var key, listeners, listener, invoker, errorEncountered = false;

				if (eventListeners[eventName]) {
					listeners = eventListeners[eventName];

					for (key in listeners) {
						if (listeners.hasOwnProperty(key)) {
							try {
								listener = listeners[key];
								if (listener.once) {
									delete listeners[key];
								}
								invoker = listenerInvoker(eventName, listener, data);
								invoker();
							} catch (err) {
								errorEncountered = true;
								if (console) {
									console.log(err);
								}
							}
						}
					}
				}

				if (!errorEncountered && doneHandler) {
					doneHandler();
				} else if (errorEncountered && errorHandler) {
					errorHandler();
				}
			},

            /*
                Remove attached event handler.

                eventName: The name of the event.
                callback : The handler function.
             */
            unbind: function(eventName, callback) {
                if (callback.nsEventGuid) {
                    if (eventListeners[eventName]) {
                        delete eventListeners[eventName][callback.nsEventGuid];
                    }
                }
            }
        };
    }());

    /*
     ********
     * Supported event types
     ********
    */
    NS.event.type = {
        FORM_INITED: "formInited",
        FORM_CHANGED: "formChanged",
        FORM_VALID: "formValid",
        PAGE_INIT_FINISHED: "pageInitFinished",
        FIELD_CHANGED: "fieldChanged",
        RECORD_FIELD_CHANGED: "recordFieldChanged", // unlike FIELD_CHANGED above, this is dispatched immediately both UI and SSS
        SYNCTOTAL_FINISHED: "synctotal_finished",
        POST_PAGE_INIT: "post_page_init",
        ITEM_ITEM_CHANGED: "item_item_changed",
        ROW_UPDATE_BUTTONS: "row_update_buttons",
        ITEM_SYNC_LINE_FIELDS: 'item_sync_line_fields',
        ITEM_POST_PROCESS_LINE: 'item_post_process_line',
        ITEM_VALIDATE_DELETE: 'item_validate_delete'
    };

    /*
     *******
     * Form object
     ******
    */
    NS.form = (function() {
        // NS.Core.getWindow().isinited = false;  // Make it undefined temporarily before Selenium tests are fixed
        NS.Core.getWindow().ischanged = false;
        NS.Core.getWindow().isvalid = true;

        return {
            isInited: function() {
                return (NS.Core.getWindow().isinited === true);
            },

            setInited: function(val) {
                if (typeof val === "boolean" && this.isInited() !== val) {
                    NS.Core.getWindow().isinited = val;
                    NS.event.dispatch(NS.event.type.FORM_INITED, {value: val});
                }
            },

            isChanged: function() {
                return NS.Core.getWindow().ischanged;
            },

            setChanged: function(val) {
                if (typeof val === "boolean" && this.isChanged() !== val) {
                    NS.Core.getWindow().ischanged = val;
                    NS.event.dispatch(NS.event.type.FORM_CHANGED, {value: val});
                }
            },

            isValid: function() {
                return NS.Core.getWindow().isvalid;
            },

            setValid: function(val) {
                if (typeof val === "boolean" && this.isValid() !== val) {
                    NS.Core.getWindow().isvalid = val;
                    NS.event.dispatch(NS.event.type.FORM_VALID, {value: val});
                }
            },

            isEditMode: function() {
                return (NS.Core.getURLParameter("e") == "T");
            },

            isViewMode: function() {
                var recordId = NS.Core.getURLParameter("id") || "-1";
                return (!this.isEditMode() && recordId != "-1");
            },

            isNewMode: function() {
                var recordId = NS.Core.getURLParameter("id") || "-1";
                return (!this.isEditMode() && recordId == "-1");
            }
        };
    }());
}(this));  /* Use 'this' instead of 'window' which is not available to server side javascript */

}).call(this);

NS.Logger = { debugValue : false };


function getDocumentClientHeight()
{
    var isWindowContainedInDivFrame = (window.parentAccesible && typeof parent != "undefined" && typeof parent.Ext != "undefined" && parent.Ext.WindowMgr.getActive()!=null);
    
        
        return (isWindowContainedInDivFrame ? parent.Ext.WindowMgr.getActive().body.dom.contentWindow.innerHeight : window.innerHeight);
    
}

function getDocumentClientWidth()
{
    var isWindowContainedInDivFrame = (window.parentAccesible && typeof parent != "undefined" && typeof parent.Ext != "undefined" && parent.Ext.WindowMgr.getActive()!=null);
    
        return (isWindowContainedInDivFrame ? parent.Ext.WindowMgr.getActive().body.dom.contentWindow.innerWidth : window.innerWidth);
    
}

function resetDivSizes()
{
    if (typeof(ignoreResetDivSizes) != 'undefined' && ignoreResetDivSizes)
    {
        return;
    }

    
       
    
    if(document.getElementById("resetdivwascalled") == null)
    {
        var hasBeenCalled = document.createElement("input");
        hasBeenCalled.type = "hidden";
        hasBeenCalled.value = "T";
        hasBeenCalled.id = "resetdivwascalled";
        document.body.appendChild(hasBeenCalled);
    }

    var header = document.getElementById('div__header');
    var title = document.getElementById('div__title');
    var banner = document.getElementById('div__banner');
    var messsageBox = document.getElementById('div__alert');
    var prelabel = document.getElementById('div__prelabel'); 
    var label = document.getElementById('div__label'); 
    var list = document.getElementById('div__body');
    var nav = document.getElementById( 'div__nav');
    var footer = document.getElementById('div__footer');

    
      
    
    var newElementsHeight = 0;
    var newTitleArea = jQuery(".pt_container").get(0);
    if (newTitleArea)
    {
        newElementsHeight += getHeight(newTitleArea) + 30; 
    }

    var controlbarHeight = 0;
    var controlBar = jQuery(".uir_control_bar").get(0);
    if (controlBar)
    {
        newElementsHeight += getHeight(controlBar) + 25;
    }

	
	var topBanner = document.getElementById('bannerContainer');
    var topBannerHeight = getHeight(topBanner);
    if (topBannerHeight > 0)  
    	topBannerHeight += 5;

    if (list == null)
        return; 

    
    
    document.body.style.overflowY = "hidden";

    
        
        
    if (footer != null)
    {
        var childnodes = footer.childNodes;
        for(var i = 0; i < childnodes.length; i++)
        {
            var tableFooter = childnodes[i];
            
            if(tableFooter.tagName == "TABLE")
            {
                document.body.style.overflow =
                    (tableFooter.scrollWidth > document.body.clientWidth) ? "-moz-scrollbars-horizontal" : "-moz-scrollbars-none";
                break;
            }
        }
    }
    

    
    
    var nHeight = getDocumentHeight() - 10;
    nHeight -= topBannerHeight + getHeight(header) + getHeight(footer) + getHeight(title) + getHeight(banner)+ getHeight(prelabel)+ getHeight(label) + getHeight(messsageBox) + 25 + newElementsHeight;
    list.style.height = ( nHeight > 0 ? nHeight : 0) + "px";

    
    
    
    

    list.clientWidth;
    
    

    var docwidth = getDocumentWidth();
    var reportDataTable = document.getElementById('_rptdata');
    if ( nav != null )
    {
        list.style.height = ( nHeight - list.offsetTop > 0 ? nHeight - list.offsetTop : 0) + "px";
        var tree = document.getElementById('div__nav_tree');
        if (tree)
            tree.style.height = ( nHeight - tree.offsetTop > 0 ? nHeight - tree.offsetTop : 0 ) + "px";

    
    

    
    
        
        if( reportDataTable )
        {
            docwidth -= nav.offsetWidth;
        }


        
        
        var node = nav.parentNode;
        var cellSpacing = 0;
        while (node != null)
        {
            if (node.getAttribute("cellspacing"))
            {
                cellSpacing = node.getAttribute("cellspacing");
                break;
            }
            node = node.parentNode;
        }
        docwidth -= 4*cellSpacing;
    }

    
    list.style.width = Math.max( docwidth-18, 0 ) + "px";

    
    nHeight = getDocumentHeight() - 10;
    nHeight -= topBannerHeight + getHeight(header) + getHeight(footer) + getHeight(title) + getHeight(banner) + getHeight(prelabel) + getHeight(label) + getHeight(messsageBox) + (isIE ? 4 : 25) + newElementsHeight;
    list.style.height = ( nHeight > 0 ? nHeight : 0) + "px";
    if ( nav != null )
    {
        list.style.height = ( nHeight - list.offsetTop > 0 ? nHeight - list.offsetTop : 0) + "px";
        var tree = document.getElementById('div__nav_tree');
        if (tree)
            tree.style.height = ( nHeight - tree.offsetTop > 0 ? nHeight - tree.offsetTop : 0 ) + "px";
    }

    
       
       
       
    
    if (label != null )
    {
        label.style.width = list.clientWidth + "px";
        label.style.left = -document.getElementById('div__body').scrollLeft + "px";
    }

    
    
    if( reportDataTable )
    {
        var labtab = document.getElementById('div__labtab');
        labtab.style.width = reportDataTable.clientWidth + "px";
    }
    

    
    var bFirst = true;
    var lastCol;
    var lastWidth;
    for (var i=0; i==0 || document.getElementById('div__labcol'+i) != null; i++)
    {
        var col = document.getElementById('div__labcol'+i);
        var lab = document.getElementById('div__lab'+i);
        if (lab != null)
        {
            var width = col.offsetWidth;
            if (bFirst && width > 0)
            {
                bFirst = false;
                width--;
            }
            if (width > 0)
            {
                lastCol = lab;
                lastWidth = width;
            }
            if ( lab.tagName == 'TD' )
            {
                lab.style.width = width + "px";
            }
            else
            {
                lab.offsetParent.style.width = width + "px";
            }
        }
    }
    if (lastCol && lastWidth > 0)
        lastCol.style.width = lastWidth - 1 + "px";

    makeVisible(label);
    makeVisible(list);
    makeVisible(footer);

    
    var paddingCell = document.getElementById("div__labend");
    if (paddingCell)
    {
        paddingCell.style.width = list.offsetWidth - list.clientWidth + "px";
        if (label)
	        paddingCell.style.height = label.offsetHeight + "px";
        paddingCell.style.left = list.clientWidth - 1 + "px";
    }

    hideInvisibleRows();
}

function checkzipcode(f, bIsCanada)
{
  var v = f.value;
  var n = bIsCanada ? 6 : 5;
  if(!onlydigits(f) || v.length != n)
  {
    if ( bIsCanada )
        alert('Please enter a valid '+n+' digit Postal Code.');
    else
        alert('Please enter a valid '+n+' digit Zip Code.');
    return false;
  }
  return true;
}


function checknotempty(fld1,nam)
{
    if (!checkvalnotempty(fld1.value, 'Please enter a value for {1}'.replace('{1}',nam)))
    {
        try {
            fld1.focus();
            fld1.select();
        } catch (e) { }
        return false;
    }

    return true;
}

    
function amount_string(amount)
{
    var cents = Math.floor((amount-Math.floor(amount))*100+0.5);
    var centstring = (cents < 10) ? '0'+cents.toString() : cents.toString();
    var dollarstring = dollars_string(Math.floor(amount));
    return dollarstring.charAt(0).toUpperCase() + dollarstring.substr(1) + 'and ' + centstring + '/100';
}
function format_rate(a,p)
{
    var returnMe;
    if (isNaN(parseFloat(a)))
    {
        returnMe= '';
    }
    else
    {
    	var precision = get_precision();
                                               
    	if (precision>1 || p)
    	{
            var s=(a<0);
            if (s) a=-a;
            var d=Math.floor(a);
            var c=Math.floor((a-d)*(p?10:100)+0.5);
                             
            if (a == d+c/(p?10:100))
            {
                if (c==(p?10:100)) {d++;c=0;}
                var cs=p?c.toString():((c < 10)?'0'+c.toString():c.toString());
                returnMe = (s?'-':'')+d.toString()+'.'+cs+(p?'%':'');
           }
            else
              returnMe = (s?'-':'')+a+(p?'%':'');
        }
        else if (precision==1)
        {
            var s=(a<0);
            if (s) a=-a;
            var cs = a.toString();
            var n = cs.indexOf('.');
            if (n==-1) cs = cs.toString() + '.0';
            else if (n==0) cs = '0.' + cs.toString() ;
            else if (n==cs.length-1) cs = cs.toString() + '0' ;
      		returnMe = (s?'-':'') + cs ;
        }
        else if (precision==0)
        {
            var s=(a<0);
            if (s) a=-a;
            var cs = a.toString();
            var n = cs.indexOf('.');
            if (n==0) cs = '0.' + cs.toString() ;
            else if (n==cs.length-1) cs = cs.substring(0, cs.length-2);
      		returnMe = (s?'-':'') + cs ;
        }
    }
  return returnMe;
}
function get_precision()
{
	var currencyPrecision = getFormElementViaFormName('main_form', 'currencyprecision');
	var precision = 2;
	if (currencyPrecision != null) 
	{
		var transactionPrecision = parseFloat(currencyPrecision.value);
		if (!isNaN(transactionPrecision))
		{
			precision = transactionPrecision;
		}
	} 
	return precision;
}
function round_currency(amount, numofdecimals, method)
{
var TEN_POWER_TABLE=[1.0000000000000001E-29, 1.0E-28, 1.0E-27, 1.0E-26, 1.0E-25, 1.0000000000000001E-24, 1.0E-23, 1.0E-22, 1.0000000000000001E-21, 1.0000000000000001E-20, 1.0E-19, 1.0E-18, 9.999999999999999E-18, 1.0E-16, 1.0E-15, 1.0E-14, 1.0E-13, 1.0E-12, 1.0000000000000001E-11, 1.0E-10, 1.0E-9, 1.0E-8, 1.0E-7, 1.0E-6, 9.999999999999999E-6, 1.0E-4, 0.001, 0.01, 0.1, 1.0, 10.0, 100.0, 1000.0, 10000.0, 100000.0, 1000000.0, 1.0E7, 1.0E8, 1.0E9, 1.0E10, 1.0E11, 1.0E12, 1.0E13, 1.0E14, 1.0E15, 1.0E16, 1.0E17, 1.0E18, 1.0E19, 1.0E20, 1.0E21, 1.0E22, 9.999999999999999E22, 1.0E24, 1.0E25, 1.0E26, 1.0E27, 1.0E28, 1.0000000000000001E29];
function getTenPower (digits)
{
	return TEN_POWER_TABLE[digits - -29];
}
function shouldRoundUp (absNum, floor, ceil, tolerance, multiplicator, roundingMode)
{
	switch (roundingMode)
	{
		case 'UP':
			return absNum > floor / multiplicator + tolerance;
		case 'DOWN':
			return absNum >= ceil / multiplicator - tolerance;
		default:
			return absNum >= (floor + 0.5) / multiplicator - tolerance;
	}
}
function roundDouble(num, digits, tolerance, roundingMode)
{
	if (!isFinite (num))
		return num;
	var signum = (num >= 0) ? +1 : -1
	var absNum = Math.abs (num);
	var multiplicator = getTenPower(digits);
	var multipliedAbsNum = multiplicator * absNum;
	var floor = Math.floor (multipliedAbsNum);
	var ceil = Math.ceil (multipliedAbsNum);
	var roundUp = shouldRoundUp (absNum, floor, ceil, tolerance, multiplicator, roundingMode);
	var multipliedResult = (roundUp) ? ceil : floor;
	var result = signum * multipliedResult / multiplicator;
	return (result == -0.0) ? 0.0 : result;
}
  var precision = numofdecimals;
  if (precision==null) 
    precision = get_precision();
  var tolerance = Math.min (5.0E-6 / getTenPower(precision), 5.0E-10)
  return roundDouble(amount, precision, tolerance, method);
}
function round_float(a)
{
  return round_float_to_n_places(a,8);
}
function round_float_to_n_places(a,n)
{
  var str = a + '';
  if(str.indexOf('.') < 0)
    return a;
  if(str.length-str.indexOf('.')-1 <= n)
    return a;
  var b = Math.abs(a);
  b = b + 0.00000000000001;
  var factor = Math.pow(10,n);
  b = Math.floor((b * factor)+0.5) / factor;
  b = b * (a >= 0.0 ? 1.0 : -1.0);
  if( b == 0.0 )
    return 0.0;
  return b;
}
function pad_to_atleast_two_decimal_places(a)
{
  var s;
    if(a == null)
    {
       s = '';
    }
  else
  {
    s = a.toString();
    var n = s.indexOf('.');
    if(n == -1)
    {
      s = s + '.00';
    }
    else if(n == s.length-1)
    {
      s = s + '00';
    }
    else if(n == s.length-2)
    {
      s = s + '0';
    }
    if (n == 0)
    {
      s = '0' + s;
    }
  }
  return s;
}
function pad_decimal_places(a, noOfDecimalPlaces)
{
  var s;
  if(a == null)
  {
     s = '';
  }
  else
  {
    s = a.toString();
    var n = s.indexOf('.');
    if (noOfDecimalPlaces==0) 
    {
      if(a == 0.0)
      {
        s = '0'; 
      }
      else if(n > -1)
      {
        s = s.substring(0, n) ;
      } 
    }
    else if (noOfDecimalPlaces==1) 
    {
      if(n == -1)
      {
        s = s + '.0';
      }
      else if(n == s.length-1)
      {
        s = s + '0';
      } 
      else if (n == 0)
      {
        s = '0' + s;
      }
    }
    else
    {
      if(n == -1)
      {
        s = s + '.00';
      }
      else if(n == s.length-1)
      {
        s = s + '00';
      }
      else if(n == s.length-2)
      {
        s = s + '0';
      }
      if (n == 0)
      {
        s = '0' + s;
      }
    }
  }
  return s;
}
function format_currency(a, bDoNotRound, precision)
{
if(isNaN(a))
{
    return '';
}
  var noOfDecimalPlaces;
if (precision === undefined) {
  var cp = getFormElementViaFormName('main_form', 'currencyprecision');
  noOfDecimalPlaces = 2;
  if (cp != null) 
  {
  	noOfDecimalPlaces = parseFloat(cp.value);
    if (isNaN(noOfDecimalPlaces))
    {
        noOfDecimalPlaces = 2;
    }
  } 
  } else { noOfDecimalPlaces = precision; }
var returnMe;
if( !(bDoNotRound == true)) 
{
    returnMe = round_currency(a, noOfDecimalPlaces);
}
else
{
    returnMe = a;
}
returnMe = pad_decimal_places(returnMe, noOfDecimalPlaces);
return returnMe;
}
function format_currency2(n)
{
  if(isNaN(n))
  {
    return '';
  }
  var returnMe;
  if( (n+'').indexOf('.') < 0 )
    returnMe = n;
  else
    returnMe = round_float_to_n_places(n,8);
  var precision = get_precision();
  if (precision == 2) {
    returnMe = pad_to_atleast_two_decimal_places(returnMe);
  } 
  return returnMe;
}
function format_percent(p) {
  if(typeof p == 'string')
     p = parseFloat(p);
 return p+(p==Math.floor(p) ? '.0%' : '%'); }
function process_currency_field_value(value, fieldType) {
    if (fieldType == null || fieldType.indexOf('currency') == -1)
        return value;
    if (isValEmpty(value) || ('' + value).indexOf('.') != -1 || isNaN(parseFloat(value)))
        return value;
    var precision = fieldType.indexOf('currency2') >= 0 ? 2 : get_precision();
    return pad_decimal_places('' + value, precision);
}
function formatCurrencyTax(value, bDoNotRound, precision, method)
{
	var currencyPrecision = precision || nlapiGetFieldValue('taxfractionunit') || 2;
	var roundingMethod = method || nlapiGetFieldValue('taxrounding') || null;
	return pad_decimal_places(
		bDoNotRound ? value : round_currency(value, currencyPrecision, roundingMethod),
		currencyPrecision
	);
}



function validate_textfield_maxlen(field, maxLen, bAlert, bMaxInChars)
{
	if (field.value == null || field.value.length == 0)
	{
		NS.form.setValid(true);
		return true;
	}
	var bValid = true, truncOffset = null;
	if (bMaxInChars)
	{
        
		var len = field.value.replace(/\r/g, '').replace(/\n/g, '\n ').length;
		if (len > maxLen)
		{
			if (bAlert)
				alert('You have exceeded the '+maxLen+' character limit for this field. Please shorten your entry by '+(len-maxLen)+' characters.');
			truncOffset = getIndexForSelection(field.value, maxLen);
		}
	}
	else
	{
		var toTrim = analyzeUTF8(field.value, maxLen);
		if (toTrim)
		{
			if (bAlert)
				alert('You have exceeded the length limit for this field. Please shorten your entry by '+toTrim+' characters.');
			truncOffset = UTF8toUTF16index(field.value, maxLen);
		}
	}
	if (truncOffset)
	{
		window.focusedTextArea = field;
		setTimeout("try { setSelectionRange(window.focusedTextArea, " + truncOffset + ", " + field.value.length + "); } catch (e) {}",0);
		bValid = false;
	}
	NS.form.setValid(bValid);
	return bValid;
}

function validate_time(fldvalue, doalert, includeSeconds)
{
    
    fldvalue = hhmmtotimestring( fldvalue );
    var time;
    if (includeSeconds)
       time = regexstringtotime(null, fldvalue, includeSeconds);
    else
       time = stringtotime(null, fldvalue);
    
    var validflag = !isNaN(time);
    var value;
    if (validflag)
    {
        if (includeSeconds)
           value = gettimewithsecondsstring(time, window.datetime_am_string, window.datetime_pm_string);
        else
           value = gettimestring(time, window.datetime_am_string, window.datetime_pm_string);
    }
    else if (doalert)
    {
        alert("Invalid time value");
    }
    return {validflag:validflag, value:value};
}
        

function old_validate_field(field, type, doalert, autoplace, minval, maxval, mandatory, separator, scale)
{
    
    if (Object.prototype.hasOwnProperty.call(field, "validationLimit"))
    {
        if (field.validationLimit > 0)
            field.validationLimit--;
        else return false;
    }

    
    NS.form.setValid(false);
    type = type.toLowerCase();
    if (field.value == null || field.value.length == 0)
    {
        if (mandatory)
        {
            if (doalert) alert("Field must contain a value.");
            selectAndFocusField(field);
            NS.form.setValid(false);
            return false;
        }
        else
        {
            NS.form.setValid(true);
            return true;
        }
    }
    checkForQuirks(type, field.value, field.id);
    if ( (type != "text" && type != "identifier" && type != "identifieranycase" && type != "address" && type != "visiblepassword") &&
		 ("en" == "ja" || "en" == "ko" || "en" == "zh") )
        field.value = parseCJKNumbers(field);
    var validflag = true;
    if (type =="url")
    {
        var val = trim(field.value.toLowerCase());
        
        
        if (!(val.indexOf('/') == 0 || val.indexOf('http://') == 0 || val.indexOf('https://') == 0 || val.indexOf('ftp://') == 0 || val.indexOf('file://') == 0))
        {
            
            if (val.indexOf('://') != -1)
            {
                if (doalert)
                    alert("Invalid url. Url must start with http://, https://, ftp://, or file://");
                validflag = false;
            }
            else
            {
                makeValidationQuirkLog(type, field.value, "HTTP prepended", field.id);
                field.value = 'http://' + trim(field.value);
        }
        }
        
        if ( val.indexOf( ' ' ) > 0 || val.indexOf( '\t' ) > 0 )
        {
            if (doalert)
                alert("Invalid url. Spaces are not allowed in the URL");
            validflag = false;
        }
    }
    else if (type == "currency" || type == "currency2" || type == "poscurrency" || type == 'nonnegcurrency')
    {
        var val = field.value.replace(/$/g,"");

        val = val.toLowerCase();
        if(val.charAt(0) == '=')
            val = val.substr(1);
        else if (val.substr(1).search(/[\-\+\*\/]/g) == -1)
            val = NLStringToNumber(val, true) + '';

        
        if (val.substr(1).search(/[\-\+\*\/]/g) != -1)
        {
            
            
            
            
            
            if(window.groupseparator && window.decimalseparator)
                val = val.replace(new RegExp( '\\' + window.groupseparator, 'g'), '').replace(new RegExp( '\\' + window.decimalseparator, 'g'), '.');
	        var regexEquation  = new RegExp('^([-+]?[0-9 .eE]+[/+*\\-]*?)+([-+]?[0-9 .eE]+)$');
            if(!regexEquation.test(val))
            {
                value = "error";
            }
            else
            {
                
                
                
                
                try {
                    val = eval(val);
                } catch (e) { val = "error"; }
                autoplace = false;
            }
        }
        numval = parseFloat(val);
        var totalDigitCount = getTotalDigitCount(val);
        if (isNaN(numval))
        {
			if (doalert)
			   alert("Invalid currency value. Values must be numbers up to 999,999,999,999,999.99");
			validflag = false;
        }
        else if ( maxval != null && !isNaN(maxval) && Math.abs(numval)>=maxval )
        {
			if (doalert)
			{
                var regex  = new RegExp('(-?[0-9]+)([0-9]{3})');
                var preDecimal = (maxval-1).toString();
                while(regex.test(preDecimal))
                {
                   preDecimal = preDecimal.replace(regex, '$1' + ',' + '$2');
                }
                alert("Invalid currency value. Values must be numbers up to " + preDecimal + ".999999999999999" + "");
            }

    		validflag = false;
		}
        
        if ((type == "poscurrency" || type == "nonnegcurrency" || minval == 0) && numval < 0)
        {
            if (doalert) alert("Invalid currency value. Value can not be negative.");
            validflag = false;
        }
        if (type == "poscurrency" && numval === 0 && validflag)
            makeValidationQuirkLog(type, field.value, "poscurrency accepted 0", field.id);

        if (validflag)
        {
            

            if(autoplace && window.decimalseparator && field.value.indexOf(window.decimalseparator) == -1) numval/=100;
            if(type == "currency" || type == "poscurrency" || type == "nonnegcurrency")
                val =format_currency(numval);
            else
                val = format_currency2(numval);
            if (isNLNumericOrCurrencyDisplayField(field))
                val = NLNumberToString(val);
            field.value = val;
        }
    }
    else if (type == "date")
    {
        var ret = validate_date(field.value, doalert, field.id);
        validflag = ret.validflag;
        if (validflag)
           field.value = ret.value;
        }
    else if (type == "mmyydate")
    {
        
        var value;
        try
        {
            value = parseMMYYDateString(field.value);
        }
        catch(e) {}

        
        if (value != null && value.month >= 1 && value.month <= 12 && value.year > 1900 && value.year < 2100)
        {
			var dDate = validateDate(new Date(value.year, value.month-1), doalert);
			if (dDate)
			{
				field.value = getmmyydatestring(dDate, NLDate_short_months);
                validflag = true;
            }
            else
		    	validflag = false;
		}
        else
        {
            
            var fmterr =  "MMYY, MMYYYY, ";
            if (window.dateformat == "DD-Mon-YYYY")
                fmterr += "Mon-YY, Mon-YYYY";
            else if (window.dateformat == "DD.MM.YYYY")
                fmterr += "MM.YY, MM.YYYY";
            else
                fmterr += "MM/YY, MM/YYYY";

            if (doalert) alert('Invalid date value (must be '+fmterr+')');
            validflag = false;
        }
    }
    else if (type == "ccexpdate" || type == "ccvalidfrom")
    {
        
        

        validflag = true;
        var m=0, y=0;
        if(field.value.indexOf('/') != -1)
        {
            var dToday = new Date();
            var Y = dToday.getFullYear();
            var M = dToday.getMonth() + 1;
            if(Y <= 999) Y += 1900;         

            var c = field.value.split('/');
            if(onlydigits(c[0])) m = parseInt(c[0],10);
            if(onlydigits(c[1])) y = parseInt(c[1],10);

            if(m<1) m=1; else if(m>12) m=12;
            if(y<100) y+=((y>=70)?1900:2000);

            
            
            if(type == "ccexpdate" && (y < Y || (y==Y && m < M)) ||
               type == "ccvalidfrom" && (y > Y || (y==Y && m > M)))
            {
                if (doalert) alert("Notice: The credit card appears to be incorrect");
            }
            field.value = (m<10?'0':'')+m+'/'+y;
        }
        else
        {
            if (doalert)
            {
                if (type == "ccexpdate") alert("Please enter an expiration date in MM/YYYY format");
                else alert("Please enter a Valid From / Start Date in MM/YYYY format");
            }
            validflag = false;
        }
    }
    else if (type == "ccnumber") 
    {
		validflag = (field.value.length > 4 &&
						field.value.substring(0, field.value.length-4).replace(new RegExp( "\\*", "g" ), '').length == 0 &&
						field.value.substring(field.value.length-4).replace(new RegExp( "\\*", "g" ), '').length == 4) || checkccnumber(field);
    }
    else if (type == "rate" || type == 'ratehighprecision')
    {
        var numval;

        var val = field.value;
        var pctidx = val.lastIndexOf("%");
        var isPct = (pctidx!=-1);
        if (isPct)
            val = val.substr(0,pctidx);

        numval = NLStringToNumber(val, true);
        if (isNaN(numval))
        {
            if (doalert) alert("Invalid number or percentage");
            validflag = false;
        }
        else
        {
            if (autoplace && !isPct && val.indexOf(".") == -1)
                numval/=100;
            var numstr = format_rate(numval, isPct);  
            if (isNLNumericOrCurrencyDisplayField(field))
            {
                numstr = NLNumberToString(numstr.replace('%',''));
                if(isPct && numval < 0 && numstr.indexOf('-') < 0)  
                {
                    var positiveNumberStr = NLNumberToString(format_rate(-numval, isPct).replace('%',''));
                    numstr = numstr.replace(positiveNumberStr, positiveNumberStr+'%');
                }
                else
                    numstr = numstr + (isPct?'%':'');
            }
            field.value = numstr;
            validflag = true;
        }
    }
    else if (type == "integer" || type == "posinteger" || type == "float" || type == "posfloat" || type == "nonnegfloat" || type == "percent" || type == "dynamicprecision")
    {
        var numval;
        var custrange=false;
        if ((minval != null || maxval != null) || type == "percent")
          custrange=true;
        var minclip= minval == null ? (type == "percent" ? 0 : -Math.pow(2,32)) : minval;
        var maxclip = maxval == null ?(type == "percent" ? 100 : Math.pow(2,64)) : maxval;
        var val = field.value.replace(/$/g,"");
        val = val.replace(/%/g,"");

        numval = NLStringToNumber(val, true);
        if (type == "integer")
            numval = parseInt(numval,10);
        else if (type == "posinteger")
        {
            numval = parseInt(numval,10);
            minclip=0;
        }
        else if (type == "posfloat" || type == "nonnegfloat" || type == "float")
        {
            if(val.indexOf(".") != -1)
			    numval = round_float(numval);
			if (type == "posfloat")
				minclip=0;
            if (type == "nonnegfloat")
            {
                minclip=-Number.MIN_VALUE;
            }
        }
        else if (type == "dynamicprecision")
        {
	        numval = round_float_to_n_places(numval, scale);
        }
        if (isNaN(numval) || (custrange && (numval > maxclip || numval < minclip)) || (!custrange && (numval >= maxclip || numval <= minclip)))
        {
            if (doalert)
            {
                if (type == "percent")
                {
					alert("Invalid percentage (must be between "+minclip+" and "+maxclip+")");
                }
                else if (custrange == true)
                {
                    if (minval == null)
                        alert("Invalid number (must be at most "+maxclip+")");
                    else if (maxval == null)
                        alert("Invalid number (must be at least "+minclip+")");
                    else
                        alert("Invalid number (must be between "+minclip+" and "+maxclip+")");
                }
                else if (type=="posinteger" || type=="posfloat")
                    alert("Invalid number (must be positive)");
                else if (type=="nonnegfloat")
                {
                    alert("Invalid: Please enter a number greater than or equal to 0.");
                }
                else if (type=="integer" || type=="float")
                {
                    if (isNaN(numval))
                        alert('You may only enter numbers into this field');
                    else
                        alert("Illegal number: " + numval);
                }
                else
                    alert("Invalid number (must be greater than -4.29B");
             }
             validflag = false;
        }
        else
        {
            var numberStr = numval + '';
            var isPct = (type == "percent");
            if (isPct)
                numberStr = format_percent(numval);   
            if (isNLNumericOrCurrencyDisplayField(field))
            {
                numberStr = NLNumberToString(numberStr.replace("%", ""));
                if(isPct && numval < 0 && numberStr.indexOf('-') < 0) 
                {
                    var positiveNumberStr = NLNumberToString(format_percent(-numval).replace('%',''));
                    numberStr = numberStr.replace(positiveNumberStr, positiveNumberStr+'%');
                }
                else
                    numberStr = numberStr + (isPct?'%':'');
            }
            field.value = numberStr;
            validflag = true;
        }
    }
    else if (type == "address")
    {
        var err = '', newval;
        if (field.value.length>999)
        {
            err = "Address too long (truncated at 1000 characters)";
            newval = field.value.substr(0,999);
        }
        if (err != '')
        {
            if (doalert) alert(err);
            field.value = newval;
        }
    }
    else if (type == "function")
    {
        if (field.value.indexOf('(') > 0)
            field.value = field.value.substr(0,field.value.indexOf('('));
		var val = field.value;
		var re = /^[0-9A-Za-z_]+(\.[0-9A-Za-z_]+)*$/;
		if (!re.test(val))
		{
			if  (doalert) alert("The Function field must be a valid JavaScript function identifier");
			validflag = false;
		}
	}
    else if (type == "time" || type == "timetrack")
    {
		var hours;
		var minutes;
        var isNegative = false;
        var val = field.value;

        if ((type === "timetrack") && (val.search(/^\s*\-/) !== -1))
        {
            isNegative = true;
            val = val.replace(/^\s*\-/, "");
        }

		var re = /([0-9][0-9]?)?(:[0-9][0-9]+)?/
        var result = re.exec(val)
        if (result==null || result.index > 0 || result[0].length != val.length)
		{
            var timeval = parseFloat(val);
			if (isNaN(timeval) || field.value.indexOf(':') != -1)
				hours = -1;
			else
			{
				hours = Math.floor(timeval);
				minutes = Math.floor((timeval-hours)*60+0.5);
			}
		}
		else
		{
			if (RegExp.$1.length > 0)
				hours = parseInt(RegExp.$1,10);
			else
				hours = 0;
			if (typeof(RegExp.$2) != "undefined" && RegExp.$2.length > 0)
			{
				minutes = parseInt(RegExp.$2.substr(1),10);
				
				
				if (minutes >= 60)
				{
					var hours_delta = Math.floor(minutes / 60);
					minutes -= (hours_delta * 60);
					hours += hours_delta;
				}
			}
			else
				minutes = 0;
		}
		if (hours >= 0 && minutes >= 0 && minutes < 60)
		{
			field.value = (isNegative ? "-" : "") + hours + ":" + (minutes < 10 ? "0" : "") + minutes;
			validflag = true;
		}
		else
		{
			if (doalert) alert("Invalid time value (must be hh:mm)");
			validflag = false;
		}
    }
    else if (type == "timeofday")
    {
        var ret = validate_time(field.value, doalert, false);
        validflag = ret.validflag;
        if (validflag)
           field.value = ret.value;
        }
    else if (type == 'datetimetz' || type == 'datetime')
    {
        var ret_date_time = extract_date_time(field.value);
        validflag = ret_date_time.validflag;
        if (validflag)
        {
            var ret_date = validate_date(ret_date_time.date, doalert, field.id);
            validflag = ret_date.validflag;
            if (validflag)
            {
                var ret_time = validate_time(ret_date_time.time, doalert, type == 'datetimetz');
                validflag = ret_time.validflag;
                if (validflag)
                {
                    field.value = ret_date.value + " " + ret_time.value;
                }
            }
        }
    }
    else if (type == "email")
    {
        validflag = checkemail(field.value, true, doalert);
    }
    else if (type == "emails")
    {
        var bademails = [];
        var validcount = 0;
        if (!separator) separator = /[,;]/;
        var emails = field.value.split(separator);
		for (var j=0; j < emails.length; j++)
		{
			var semail = trim(emails[j]);
			if (semail)
			{
				if (checkemailvalue(semail, false))
					validcount += 1;
				else
					bademails.push(emails[j]);
			}
		}
        if (bademails.length > 0)
        {
            validflag = false;
            if (doalert) alert('Invalid email(s) found: '+bademails.join('; '));
        }
        else if (validcount < 1)
        {
            validflag = false;
            if (doalert) alert('No valid emails found in \"'+field.value+'\"');
        }
    }
    else if (type == "phone"  || type == "fullphone")
    {
        var val = field.value;
        
        if(val.length!=0 && val.length<7)
        {
            if (doalert) alert("Phone number should have seven digits or more.");
            validflag = false;
        }

        if (validflag && type == "fullphone")
        {
            
            if(val.length!=0 && val.length<10)
            {

                if (doalert) alert("Please include the area code for phone number: " + val);
                validflag = false;
            }
        }
        if (autoplace && validflag)
        {
            var extidx = val.search(/[A-Za-z]/);
            var ext = '';
            if (extidx >= 0)
            {
                ext = ' '+val.substring(extidx);
                val = val.substring(0,extidx);
            }
            var re = /^[0-9()-.\s]+$/;
            if (re.test(val))
            {
			  var digits = val.replace(/[()-.\s]/g,'');
			  var phoneformat = window.phoneformat.replace(new RegExp( "[360]", "g" ),String.fromCharCode(3));
              if (digits.length == 7)
                 field.value=phoneformat.replace(phoneformat.substring(0,phoneformat.indexOf('4')),'').replace('45'+String.fromCharCode(3),digits.substring(0,3)).replace('789'+String.fromCharCode(3),digits.substring(3)) + ext;
              else if (digits.length == 10)
                 field.value=phoneformat.replace('12'+String.fromCharCode(3),digits.substring(0,3)).replace('45'+String.fromCharCode(3),digits.substring(3,6)).replace('789'+String.fromCharCode(3),digits.substring(6)) + ext;
              else if (digits.length == 11 && digits.substring(0,1) == '1')
                 field.value='1 '+phoneformat.replace('12'+String.fromCharCode(3),digits.substring(1,4)).replace('45'+String.fromCharCode(3),digits.substring(4,7)).replace('789'+String.fromCharCode(3),digits.substring(7)) + ext;
            }
        }
    }
    else if (type == "color")
    {
        var val = field.value;
        if (val.substring(0,1) == "#")
            val = val.substring(1);
        
        var re = /^[0-9ABCDEFabcdef]{6,}$/;
        if (val.length > 6 || !re.test(val))
        {
            if (doalert) alert("Color value must be 6 hexadecimal digits of the form: #RRGGBB.  Example: #FF0000 for red.");
            validflag = false;
        }
        else
            field.value = "#"+val;
    }
    else if (type == "identifier" || type == "identifieranycase")
    {
        var val = field.value;
        var re = /^[0-9A-Za-z_]+$/;
        if (!re.test(val))
        {
            if (doalert) alert("Identifiers can contain only digits, alphabetic characters, or \"_\" with no spaces");
            validflag = false;
        }
        else
            field.value = type == "identifier" ? val.toLowerCase() : val;
    }
	else if (type == "package")
	{
        validflag = /^[a-z0-9]+(\.[a-z0-9]+){2}$/.test(field.value);
        if (!validflag && doalert)
            alert("The application ID must be a fully qualified name, such as com.publisherid.projectid. It must contain lowercase alphanumeric characters and exactly two periods. The ID may not begin or end with a period.");
        else
            field.value = field.value.toLowerCase();
	}
    else if (type == "furigana")
    {
        var val = field.value;
        var re = /^[\u0020\u3000\u30A0-\u30FF\uFF61-\uFF9F]+$/;
        if (!re.test(val))
        {
			if (doalert) alert("A non-katakana character has been entered.");
            validflag = false;
        }
    }
	else if(type == "urlcomponent") 
	{
		var val = field.value.toLowerCase();
		var re = /^[a-z0-9\-]*$/;
		if(!re.test(val)) {
			if(doalert) alert("This field can contain only lower case letters, numbers and \'-\'.");
			validflag = false;
		}
		else
			field.value = val;
	}
    if (mandatory == true)
    {
        if (field.value.length == 0)
        {
            if (doalert) alert("Field must contain a value.");
            validflag = false;
        }
    }
    if (!validflag)
        selectAndFocusField(field);
    else if (isNLNumericOrCurrencyDisplayField(field))
    {

    }
    NS.form.setValid(validflag);
    return validflag;
}


function validatePeriodRange(fldPeriodStart, fldPeriodEnd)
{
    if( getSelectIndex(fldPeriodEnd) < getSelectIndex(fldPeriodStart) )
    {
        alert('Please enter a valid date range. The From date must precede the To date.');
        return false;
    }

    return true;
}


NLDate_months = ["January","February","March","April","May","June","July","August","September","October","November","December",""];
NLDate_short_months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec",""];
function nlGetFullYear(d)
{
    if (window.navigator != null && window.navigator.appName == "Netscape")
    {
        if (d.getFullYear == "undefined")
            return d.getYear();
    }
    return d.getFullYear();
}
function nlSetFullYear(d,val)
{
    if (window.navigator != null && window.navigator.appName == "Netscape")
    {
        if (d.setFullYear == "undefined")
            d.setYear(val);
    }
    d.setFullYear(val);
}

var year_char_cn = "年";
var month_char_cn = "月";
var day_char_cn = "日";

var weekday = new Array(7);
weekday[0] = "Sunday";
weekday[1] = "Monday";
weekday[2] = "Tuesday";
weekday[3] = "Wednesday";
weekday[4] = "Thursday";
weekday[5] = "Friday";
weekday[6] = "Saturday";

function getdatestring(d, format)
{
	// if dateformat is specified, use it from the format parameter
	// else use the window property (set from user preference)
	var dateformat;
	if (typeof(format) != "undefined")
		dateformat = format;
	else if (typeof(window.dateformat) != "undefined")
		dateformat = window.dateformat;
	else
		dateformat = "MM/DD/YYYY";

	return oracleDateTimeFormatterFactory.getFormatter().formatDateTime(d, dateformat);
}

var reiwa_start_date = new Date(2019, 4, 1);
var heisei_start_date = new Date(1989,0,8);
var shouwa_start_date = new Date(1926,11,25);
var taishou_start_date = new Date(1912,6,30);
var meiji_start_date = new Date(1867,1,3);
function get_japanese_imperial_era(d)
{
	if (d >= reiwa_start_date)
		return "令和";
	else if (d >= heisei_start_date)
		return "平成";
	else if(d >= shouwa_start_date)
		return "昭和";
	else if(d >= taishou_start_date)
		return "大正";
	else
		return "明治";
}
function get_short_japanese_imperial_era(d)
{
	if (d >= reiwa_start_date)
		return "R";
	else if (d >= heisei_start_date)
		return "H";
	else if(d >= shouwa_start_date)
		return "S";
	else if(d >= taishou_start_date)
		return "D";
	else
		return "M";
}
function get_japanese_imperial_year(d)
{
	if (d >= reiwa_start_date)
		return nlGetFullYear(d) - 2018;
	else if (d >= heisei_start_date)
		return nlGetFullYear(d) - 1988;
	else if(d >= shouwa_start_date)
		return nlGetFullYear(d) - 1925;
	else if(d >= taishou_start_date)
		return nlGetFullYear(d) - 1911;
	else
		return nlGetFullYear(d) - 1867;
}
function get_gregorian_year(ja_imperial_year, era)
{
	if (era == "令和" || era == "R")
		return ja_imperial_year + 2018;
	else if (era == "平成" || era == "H")
		return ja_imperial_year + 1988;
	else if(era == "昭和" || era == "S")
		return ja_imperial_year + 1925;
	else if(era == "大正" || era == "D")
		return ja_imperial_year + 1911;
	else
		return ja_imperial_year + 1867;
}

function getdefaultformatdatestring(d)
{
    return (d.getMonth()+1)+"/"+d.getDate()+"/"+nlGetFullYear(d);
}
function gettimestring(time,amvar,pmvar)
{
	return gettimestringwithformat(time, amvar, pmvar, window.timeformat);
}

function gettimestringwithformat(time, amvar, pmvar, format)
{
	return oracleDateTimeFormatterFactory.getFormatter().formatDateTime(time, format);
}

function gettimewithsecondsstring(time,amvar,pmvar)
{
	return oracleDateTimeFormatterFactory.getFormatter().formatDateTime(time, window.timeformatwithseconds);
}

function getdatetimestring(date)
{
    return getdatestring(date) + " " + gettimestring(date);
}

function getdatetimetzstring(date)
{
    return getdatestring(date) + " " + gettimewithsecondsstring(date);
}

/**
 * Convert date to MMYY string.
 * Should behave the same way as NLDateRangeFieldGroup.getInvTurnDate().
 * The result must also be parsable by parseMMYYDateString.
 *
 * @param d
 * @param NLDate_short_months
 */
function getmmyydatestring(d, NLDate_short_months)
{
	var dateformat = window.dateformat || "MM/DD/YYYY";
	return oracleDateTimeFormatterFactory.getFormatter().formatMMYYDateString(d, dateformat);
}

function isoToDate(isoStr, type)
{
	if (type == 'date')
		isoStr = isoStr + ' 00:00:00';
	else if (type == 'timeofday')
		isoStr = getdatestring(new Date(), 'YYYY-MM-DD') + ' ' + isoStr;

	return new Date(isoStr);
}

/**
 * Parse year and month from a MMYY value.
 * Try to be as benevolent as possible, while keeping unambiguous.
 * Must parse anything produced by getmmyydatestring()
 * and NLDateRangeFieldGroup.getInvTurnDate().
 *
 * @param value the string value
 */
function parseMMYYDateString(value)
{
    var year, month;
    if(!/^[0-9-\/\.]+$/.test(value))
    {
        // contains other chars than numerals and ./- => must contain month short name
        var c = value.split(/[\/-]/);
        if (c.length != 2) {
            return null;
        }
        month = getMonthIndex(c[0]);
        year = parseInt(c[1],10);
    }
    else
    {
        // split it by any of ./-
        var comps = value.split(/[\.\/-]/);
        if (comps.length == 1)
        {
            // without any separator - month is the first 1 or 2 chars,
            // the rest is year (2 or 4 chars)
            var l = value.length;
            month = parseInt(value.substr(0,2-l%2),10);
            year = parseInt(value.substr(2-l%2),10);
        }
        else
        {
            // first month then year
            month = parseInt(comps[0],10);
            year = parseInt(comps[1],10);
        }
    }

    // make the year full year if less then 100
    if (year < 50)
        year += 2000;
    else if (year < 100)
        year += 1900;

    return {
        year: year,
        month: month
    };
}

/**
 * Parse day and month from a DDMM value.
 *
 * @param value the string value
 */
function parseMMDDDateString(value)
{
    var day, month;
    // format is fixed as MM/DD
    var c = value.split(/[\/]/);
    if (c.length != 2) {
        return null;
    }
    // first month then day
    month = parseInt(c[0],10)-1;
    day = parseInt(c[1],10);

    return {
        month: month,
        day: day
    };
}

function stringtodate(arg, dateformat, returnNullIfInvalid, formattype)
{
    var comps;
	var month, day, year;
	var year_char_index, month_char_index, day_char_index, era;
    var d = arg;  // date string, assume it's the whole string for now
	if(dateformat == null)
	{
		if(typeof(window.dateformat) != "undefined")
			dateformat = window.dateformat;
		else
			dateformat = "MM/DD/YYYY";
	}
	var datestring_length = arg.length;
	var end_string; //the end segment in date string (mainly used for date seg since year string's length is always 4)
	var year_length = 4;
	var returnValIfError = returnNullIfInvalid ? null : new Date();
	dateformat = oracleDateTimeFormatterFactory.getFormatter().preprocessDateTimeFormat(dateformat);

	if(d.length > 0)
	{
		if(dateformat == "MM/DD/YYYY")
		{
			comps = d.split("/");
			if(comps.length < 3)       // the format can contains time hh:mm:ss or hh-mm-ss
				return returnValIfError;
			month = parseInt(comps[0], 10) - 1;
			day = parseInt(comps[1], 10);
			year = parseInt(comps[2].substring(0, year_length), 10);
			datestring_length = comps[0].length + comps[1].length + year_length + 2;
		}
		else if(dateformat == "DD/MM/YYYY")
		{
			comps = d.split("/");
			if(comps.length < 3)     // the format can contains time hh:mm:ss or hh-mm-ss
				return returnValIfError;
			day = parseInt(comps[0], 10);
			month = parseInt(comps[1], 10) - 1;
			year = parseInt(comps[2].substring(0, year_length), 10);
			datestring_length = comps[0].length + comps[1].length + year_length + 2;
		}
		else if(dateformat == "DD-Mon-YYYY")
		{
			comps = d.split("-");
			if(comps.length < 3)     // the format can contains time hh:mm:ss or hh-mm-ss
				return returnValIfError;
			day = parseInt(comps[0], 10);
			month = getMonthIndex(comps[1]) - 1;
			year = parseInt(comps[2].substring(0, year_length), 10);
			datestring_length = comps[0].length + comps[1].length + year_length + 2;
		}
		else if(dateformat == "DD.MM.YYYY")
		{
			comps = d.split(".");
			if(comps.length < 3)     // the format can contains time hh:mm:ss or hh-mm-ss
				return returnValIfError;
			day = parseInt(comps[0], 10);
			month = parseInt(comps[1], 10) - 1;
			year = parseInt(comps[2].substring(0, year_length), 10);
			datestring_length = comps[0].length + comps[1].length + year_length + 2;
		}
		else if(dateformat == "DD-MONTH-YYYY")
		{
			comps = d.split("-");
			if(comps.length < 3)     // the format can contains time hh:mm:ss or hh-mm-ss
				return returnValIfError;
			day = parseInt(comps[0], 10);
			month = arrayIndexOf(NLDate_months, comps[1], true);
			year = parseInt(comps[2].substring(0, year_length), 10);
			datestring_length = comps[0].length + comps[1].length + year_length + 2;
		}
		else if(dateformat == "YYYY/MM/DD")
		{
			comps = d.split("/");
			if(comps.length < 3)     // the format can contains time hh:mm:ss or hh-mm-ss
				return returnValIfError;
			end_string = comps[2].split(" ")[0];
			day = parseInt(end_string, 10);
			month = parseInt(comps[1], 10) - 1;
			year = parseInt(comps[0], 10);
			datestring_length = comps[1].length + end_string.length + year_length + 2;
		}
		else if(dateformat == "YYYY-MM-DD")
		{
			comps = d.split("-");
			if(comps.length < 3)     // the format can contains time hh:mm:ss or hh-mm-ss
				return returnValIfError;
			end_string = comps[2].split(" ")[0];
			day = parseInt(end_string, 10);
			month = parseInt(comps[1], 10) - 1;
			year = parseInt(comps[0], 10);
			datestring_length = comps[1].length + end_string.length + year_length + 2;
		}
		else if(dateformat == "EEYY年MM月DD日")
		{
			year_char_index = d.indexOf(year_char_cn);
			month_char_index = d.indexOf(month_char_cn);
			day_char_index = d.indexOf(day_char_cn);
			if(year_char_index < 0 || month_char_index < 0 || day_char_index < 0)
				return returnValIfError;
			day = parseInt(d.substring(month_char_index+1,day_char_index), 10);
			month = parseInt(d.substring(year_char_index+1,month_char_index), 10) - 1;
			era = d.substring(0, 2);
			year = get_gregorian_year(parseInt(d.substring(2,year_char_index), 10), era);
			datestring_length = day_char_index + 1;
		}
		else if(dateformat == "YYYY年MM月DD日")
		{
			year_char_index = d.indexOf(year_char_cn);
			month_char_index = d.indexOf(month_char_cn);
			day_char_index = d.indexOf(day_char_cn);
			if(year_char_index < 0 || month_char_index < 0 || day_char_index < 0)
				return returnValIfError;
			day = parseInt(d.substring(month_char_index+1,day_char_index), 10);
			month = parseInt(d.substring(year_char_index+1,month_char_index), 10) - 1;
			year = parseInt(d.substring(0,year_char_index), 10);
			datestring_length = day_char_index + 1;
		}
		else if(dateformat == "EYY.MM.DD")
		{
			comps = d.split(".");
            if(comps.length < 3)     // the format can contains time hh:mm:ss or hh-mm-ss
				return returnValIfError;
			end_string = comps[2].split(" ")[0];
			day = parseInt(end_string, 10);
			month = parseInt(comps[1], 10) - 1;
			era = comps[0].substring(0, 1);
			year = get_gregorian_year(parseInt(comps[0].substring(1,comps[0].length), 10), era);
			datestring_length = comps[0].length + comps[1].length + end_string.length + 2;
		}
		else if(dateformat == "DD. MON YYYY")
		{
			comps = d.split(" ");
            if(comps.length < 3)     // the format can contains time hh:mm:ss or hh-mm-ss
				return returnValIfError;
			day = parseInt(comps[0].substring(0, comps[0].length - 1), 10);
			month = arrayIndexOf(NLDate_short_months, comps[1]);
			year = parseInt(comps[2].substring(0, year_length), 10);
			datestring_length = comps[0].length + comps[1].length + year_length + 2;
		}
		else if(dateformat == "DD de MONTH de YYYY")
		{
			comps = d.split(" de ");
            if(comps.length < 3)     // the format can contains time hh:mm:ss or hh-mm-ss
				return returnValIfError;
			day = parseInt(comps[0], 10);
			month = getMonthIndex(comps[1]) - 1;
			year = parseInt(comps[2].substring(0, year_length), 10);
			datestring_length = comps[0].length + comps[1].length + year_length + 8;
		}
		else if(dateformat == "YYYY년 MM월 DD일")
		{
			comps = d.split(" ");
			if(comps.length < 3)     // the format can contains time hh:mm:ss or hh-mm-ss
				return returnValIfError;
			day = parseInt(comps[2].substring(0, comps[2].length-1), 10);
			month = parseInt(comps[1].substring(0, comps[1].length-1), 10) - 1;
			year = parseInt(comps[0].substring(0, comps[0].length-1), 10);
			var whitespaceChars = 3;
			datestring_length = comps[0].length + comps[1].length + comps[2].length + whitespaceChars;
		}
		else if(dateformat == "DD MONTH YYYY")
		{
			comps = d.split(" ");
			if(comps.length < 3) //the format could be "DD MONTH YYYY HH:MI:SS AM" . length =4
				return returnValIfError;
			day = parseInt(comps[0], 10);
			month = arrayIndexOf(NLDate_months, comps[1], true);
			year = parseInt(comps[2].substring(0, year_length), 10);
			datestring_length = comps[0].length + comps[1].length + year_length + 2;
		}
		else if(dateformat == "DD MONTH, YYYY")
		{
			comps = d.split(" ");
			if(comps.length < 3) //the format could be "DD MONTH YYYY HH:MI:SS PM" . length = 4
				return returnValIfError;
			day = parseInt(comps[0], 10);
			month = arrayIndexOf(NLDate_months, comps[1].substring(0, comps[1].length-1), true);
			year = parseInt(comps[2].substring(0, year_length), 10);
			datestring_length = comps[0].length + comps[1].length + year_length + 2;
		}
	}

	if (!isvalidyearmonthday(year, month, day))
		return returnValIfError;
	
	// now handle the time segment
	var result;
    var t = arg.substring(datestring_length);
	if (t != null && t.length > 0)
    {
        if (formattype == 'datetimetz')
            result = regexstringtotime(arg.substring(0,datestring_length),t, true);
        else if (formattype == 'datetime' || formattype == 'timeofday')
            result = regexstringtotime(arg.substring(0,datestring_length),t, false);
        else
            result = stringtotime(arg.substring(0,datestring_length),t);        
    }
    else
        result = new Date(year,month,day);

	if (result != null && !isNaN(result)) {
		if (year < 50)
			nlSetFullYear(result, year + 2000);
		else if (year < 100)
			nlSetFullYear(result, year + 1900);
	}
    return isNaN(result) && returnNullIfInvalid ? null : result;
}

function isvalidyearmonthday(year, month, day)
{
	if(isNaN(year) || year < 0 || isNaN(month) || month < 0 || month > 11 || isNaN(day) || day < 1 || day > 31)
		return false;
	else
		return true;
}

// we need this for sever side script
function trimstring(str)
{
    return str.replace(/^\s+/,"").replace(/\s+$/,"");
}

function regexstringtotime(date, time, includeSeconds)
{
    var flddate = date != null ? stringtodate(date) : new Date();
    if (time != null && new String(time).length != 0 && new String(time).search(/\S/) >= 0)
    {
        var hours, minutes, seconds;
        hours = NaN;
        minutes = NaN;
        seconds = NaN;

        var delimitors = null;
        time = trimstring(time); // remove all leading/trailing spaces

        var TIME_FORMAT_MAP =
        {
            "HH:MI:SS am": { rcase:0, hend:':', mend:':', send:' '},
            "HH-MI-SS am": { rcase:0, hend:'-', mend:'-', send:' '},
            "HH24:MI:SS": { rcase:0, hend:':', mend:':', send:null},
            "HH24-MI-SS": { rcase:0, hend:'-', mend:'-', send:null},
            "amHH時MI分SS秒": { rcase:1, hend:'時', mend:'分', send:'秒'},
            "amHH点MI分SS秒": { rcase:1, hend:'点', mend:'分', send:'秒'},
            "amHH시MI분SS초": { rcase:1, hend:'시', mend:'분', send:'초'},
            "HH24時MI分SS秒": { rcase:2, hend:'時', mend:'分', send:'秒'},
            "HH24点MI分SS秒": { rcase:2, hend:'点', mend:'分', send:'秒'},
            "HH24시MI분SS초": { rcase:2, hend:'시', mend:'분', send:'초'},
            "HH:MI am": { rcase:0, hend:':', mend:' ', send:null},
            "HH-MI am": { rcase:0, hend:'-', mend:' ', send:null},
            "HH24:MI": { rcase:0, hend:':', mend:null, send:null},
            "HH24-MI": { rcase:0, hend:'-', mend:null, send:null},
            "amHH時MI分": { rcase:1, hend:'時', mend:'分', send:null},
            "amHH点MI分": { rcase:1, hend:'点', mend:'分', send:null},
            "amHH시MI분": { rcase:1, hend:'시', mend:'분', send:null},
            "HH24時MI分": { rcase:2, hend:'時', mend:'分', send:null},
            "HH24点MI分": { rcase:2, hend:'点', mend:'分', send:null},
            "HH24시MI분":{ rcase:2, hend:'시', mend:'분', send:null}
        }

        format = trimstring(
        	oracleDateTimeFormatterFactory.getFormatter().preprocessDateTimeFormat(
        		includeSeconds ? window.timeformatwithseconds : window.timeformat));
        delimitors = TIME_FORMAT_MAP[format];

        var m;
        var ampm = null;
        var hend = null, mend = null, send = null;
        var TIME_FORMAT_WITH_POSSIBLE_AMPM_SUFFIX = /^(\d+)(\D)(\d+)((\D)(\d+))?\s*(\S+)?/;
        var TIME_FORMAT_WITH_POSSIBLE_AMPM_PREFIX = /^(\D+)(\d+)(\D)(\d+)(\D)((\d+)(\D))?/;
        var TIME_FORMAT_WITH_ASIAN_FORMATTING	  = /^(\d+)(\D)(\d+)(\D)((\d+)(\D))?/;

		if (delimitors != null)
        {
            switch (delimitors.rcase)
            {
                case 0:
                {
                    m = TIME_FORMAT_WITH_POSSIBLE_AMPM_SUFFIX.exec(time);
                    if (m !== null)
                    {
                        hours = parseInt(m[1], 10);
                        hend = m[2];
                        minutes = parseInt(m[3], 10);
                        mend = m[5];
                        if (includeSeconds && m[4] != null)
                            seconds = parseInt(m[6], 10);
                        else
                            seconds = 0;
                        ampm = m[7];
                    }
                    break;
                }
                case 1:
                {
                	var amtime=time.replace(/午前|上午|오전/g,'am');
                	amtime=amtime.replace(/午後|下午|오후/g,'pm');
                    m = TIME_FORMAT_WITH_POSSIBLE_AMPM_PREFIX.exec(amtime);
                    if (m !==  null)
                    {
                        hours = parseInt(m[2], 10);
                        hend = m[3];
                        minutes = parseInt(m[4], 10);
                        mend = m[5];
                        if (includeSeconds && m[6] != null)
                        {
                            seconds = parseInt(m[7], 10);
                            send = m[8];
                        }
                        else
                            seconds = 0;
                        ampm = m[1];
                    }
                    break;
                }
                case 2:
                {
                    m = TIME_FORMAT_WITH_ASIAN_FORMATTING.exec(time);
                    if (m !==  null)
                    {
                        hours = parseInt(m[1], 10);
                        hend = m[2];
                        minutes = parseInt(m[3], 10);
                        mend = m[4];
                        if (includeSeconds && m[5] != null)
                        {
                            seconds = parseInt(m[6], 10);
                            send = m[7];
                        }
                        else
                            seconds = 0;         
                    }
                    break;
                }
            }
            if (isNaN(hours) || isNaN(minutes) || isNaN(seconds) || hours >= 24 || hours < 0 || minutes >= 60 || minutes < 0 || seconds >= 60 || seconds < 0)
                return NaN;

            if (hend != delimitors.hend || (includeSeconds && (mend != null && mend != delimitors.mend) || (send != null && send != delimitors.send)))
                return NaN;

            if (ampm != null)
            {
                var is_pm = (ampm.toLowerCase() == window.datetime_pm_string);
                if (!is_pm && hours == 12)
                    hours = 0;
                else if (is_pm && hours < 12)
                    hours += 12;
            }
            flddate.setHours(hours, minutes, seconds, 0);
        } else
           flddate = NaN;        
    }
    return flddate;
}



function stringtotime(date, time)
{
    var flddate = date != null ? stringtodate(date) : new Date();
    if (time != null && new String(time).length != 0 && new String(time).search(/\S/) >= 0)
    {
        var hours, minutes, seconds, is_pm;
        var hour_char_index;
        var minute_char_index;
        format = oracleDateTimeFormatterFactory.getFormatter().preprocessDateTimeFormat(window.timeformat);
        if (format == "HH:MI am" || format == "HH-MI am" || format == "HH24:MI" || format == "HH24-MI")
        {
            var m = /^\s*(\d+)[-:](\d+)\s*(.*)/.exec(time);
            if (!m) return NaN;
            hours = parseInt(m[1], 10);
            minutes = parseInt(m[2], 10);
            if (format.substring(6) == "am")
            {
                is_pm = (m[3].toLowerCase() == window.datetime_pm_string);
                if (!is_pm && hours == 12)
                    hours = 0;
                else if (is_pm && hours < 12)
                    hours += 12;
            }
        }
        else if(format == "amHH時MI分" || format == "amHH点MI分" || format == "amHH시MI분")
        {
            hour_char_index = time.indexOf("時");
            if(hour_char_index < 0)
                hour_char_index = time.indexOf("点");
            if(hour_char_index < 0)
                hour_char_index = time.indexOf("시");
            var hour_start_index = 0;
            is_pm = false;
            if(time.indexOf(window.datetime_am_string) == 0)
                hour_start_index = window.datetime_am_string.length;
            else if(time.indexOf(window.datetime_pm_string) == 0)
            {
                hour_start_index = window.datetime_pm_string.length;
                is_pm = true;
            }
            hours = parseInt(time.substring(hour_start_index, hour_char_index));
            if (!is_pm && hours == 12)
                hours = 0;
            else if(is_pm && hours < 12)
                hours += 12;
            minutes = parseInt(time.substring(hour_char_index + 1, time.length - 1));
        }
        else if(format == "HH24時MI分" || format == "HH24点MI分" || format == "HH24시MI분")
        {
            hour_char_index = time.indexOf("時");
            if(hour_char_index < 0)
                hour_char_index = time.indexOf("点");
            if(hour_char_index < 0)
                hour_char_index = time.indexOf("시");
            hours = parseInt(time.substring(0, hour_char_index));
            minutes = parseInt(time.substring(hour_char_index + 1, time.length - 1));
        }
        if(isNaN(hours) || isNaN(minutes) || hours >= 24 || hours < 0 || minutes >= 60 || minutes < 0 || seconds >= 60 || seconds < 0)
            return NaN;
        flddate.setHours(hours, minutes, 0, 0);
    }
    return flddate;
}

function hhmmtotime( hhmm )
{
    return stringtotime( null, hhmmtotimestring( hhmm ) );
}

// -- handle shorthand time notation i.e. 5p -> 5:00 pm, 18 -> 6:00 pm, 900 -> 9:00 am, 1433p -> 2:33 pm
function hhmmtotimestring( hhmm )
{
    var fldvalue = hhmm;
	var hour, minute;
	if ( window.datetime_am_string.charAt(0) == window.datetime_pm_string.charAt(0) )
		re = new RegExp("^[0-9]{1,4}("+window.datetime_am_string+"|"+window.datetime_pm_string+")*$", "i");
	else
		re = new RegExp("^[0-9]{1,4}(["+window.datetime_am_string.charAt(0)+"|"+window.datetime_pm_string.charAt(0)+"]?)$","i");
    if ( re.test(fldvalue) )
    {
		var aorp = '';
		if ( RegExp.$1 )
		{
			if ( window.datetime_am_string.charAt(0) == window.datetime_pm_string.charAt(0) )
				aorp = RegExp.$1.toLowerCase() == window.datetime_pm_string ? window.datetime_pm_string : window.datetime_am_string;
			else
				aorp = RegExp.$1.toLowerCase().charAt(0) == window.datetime_pm_string.charAt(0) ? window.datetime_pm_string : window.datetime_am_string;
		}
		if ( fldvalue.length < 3 || ( fldvalue.length == 3 && RegExp.$1 ) )
        {
            var hh = RegExp.$1 ? fldvalue.substring(0,fldvalue.length-1) : fldvalue;
            hour = parseInt( hh, 10 ) == 0 ? 12 : ( parseInt( hh, 10 ) > 12 ? parseInt( hh, 10 ) % 12 : hh ) ;
			minute = 0;
            var ampm = RegExp.$1 ? aorp :
					   ( parseInt( fldvalue, 10 ) > 11 ? window.datetime_pm_string : window.datetime_am_string );
        }
		else if (fldvalue.length == 3 || (fldvalue.length == 4 && RegExp.$1) )
        {
            var hh = fldvalue.substring(0,1) == "0" ? "12" : fldvalue.substring(0,1);
			hour = parseInt( hh, 10 );
			var mm = RegExp.$1 ? fldvalue.substring(1,3) : fldvalue.substring(1);
			minute = parseInt( mm, 10 );
			var ampm = RegExp.$1 ? aorp : window.datetime_am_string;
        }
        else
        {
            var hh = fldvalue.substring(0,2);
			hour = parseInt( hh, 10 ) == 0 ? 12 : ( parseInt( hh, 10 ) > 12 ? parseInt( hh, 10 ) % 12 : hh );
			var mm = RegExp.$1 ? fldvalue.substring(2,4) : fldvalue.substring(2);
			minute = parseInt( mm, 10 );            
			var ampm = parseInt( fldvalue.substring(0,2), 10 ) > 11 ? window.datetime_pm_string : window.datetime_am_string;
            ampm = RegExp.$1 ? aorp : ampm;
		}
		if (ampm == window.datetime_am_string && hour == 12)
			hour = 0;
		else if(ampm == window.datetime_pm_string && hour != 12)
			hour = parseInt(hour) + 12;
		var time = new Date();
		time.setHours(hour,minute,0,0);        
        fldvalue = gettimestring(time, window.datetime_am_string, window.datetime_pm_string);
	}
	return fldvalue;
}

function adddays(d, daystoadd)
{
    var d2 = new Date(d.getTime() + 86400 * daystoadd * 1000);
    if (d2.getHours() != d.getHours())
    {
        if ((d.getHours() > 0 && d2.getHours() < d.getHours()) || (d.getHours() == 0 && d2.getHours() == 23))
          d2.setTime(d2.getTime() + 3600*1000);
        else
          d2.setTime(d2.getTime() - 3600*1000);
    }
    d.setTime(d2.getTime());
    return d;
}

function daysBetween(dEarly, dLate) // ignores time
{
	return get_julian_date(dLate) - get_julian_date(dEarly);
}

function monthsBetween(dEarly, dLate) // ignores DOM and time
{
	return 12*(dLate.getFullYear() - dEarly.getFullYear()) + (dLate.getMonth() - dEarly.getMonth());
}

function isDOWIM(dDate, nDOWIM)
{
	return (nDOWIM >= 1 && nDOWIM == (1 + Math.floor((dDate.getDate()-1)/7))) ||
		((nDOWIM == -1 || nDOWIM == 5) && daysBetween(dDate, addmonths(new Date(dDate.getFullYear(), dDate.getMonth(), 1), 1)) <= 7);
}

function isLeapYear(year)
{
    return (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));
}

MONTH_LENGTH = [[31,28,31,30,31,30,31,31,30,31,30,31],[31,29,31,30,31,30,31,31,30,31,30,31]];

function getMonthLength(year, month)
{
	return MONTH_LENGTH[isLeapYear(year)?1:0][month];
}

/**
 *  setDateComponents: set the month and day of the given date.  If noRollover is given and true,
 *  the day will not exceed the last day of the final month and thus will not trigger a month rollover.
 */
function setDateComponents(theDate, monthsToAdd, theDay, noRollover)
{
  var newDate  = new Date(theDate);

  if (typeof(noRollover) != 'boolean')
      noRollover = false;
  addmonths(newDate,monthsToAdd);
  setDate(newDate, theDay, noRollover);

  return newDate;
}

function addmonths(d, mtoadd)
{
	if (mtoadd != 0)
	{
		var year = nlGetFullYear(d);
		var dom = d.getDate();
		var month = d.getMonth() + mtoadd;
		if (month < 0)
		{
			month += 1;
			year = year + Math.ceil(month / 12) - 1;
			nlSetFullYear(d, year);
			month = 11 + (month % 12);
		}
		else if (month > 11)
		{
			year = year + Math.floor(month / 12);
			nlSetFullYear(d, year);
			month %= 12;

			// JS rounds leap days up (2/29/2016 + 1 yr = 3/1/2017),
			// whereas Java rounds them down (2/29/2016 + 1 yr = 2/28/2017).
			// Make JS behave like Java to be consistent with server side.
			if(dom === 29)
				d.setDate(dom); //This only works because we're setting the month later
		}
		var eom = getMonthLength(year, month);
		if (dom > eom)
			d.setDate(eom);

		d.setMonth(month);
	}
	return d;
}

function addhours(d, hourstoadd, truncate)
{
    var d2 = new Date(d.getTime() + 3600 * hourstoadd * 1000);
    d.setTime(d2.getTime());
	if (truncate)
	{
		d.setMinutes(0);
		d.setSeconds(0);
		d.setMilliseconds(0);
	}
	return d;
}

function setDate(d, day, noRollover)
{
    if (noRollover)
    {
        var eom = getMonthLength(nlGetFullYear(d), d.getMonth());
        day = Math.min(eom, day);
    }
    d.setDate(day);
}

m_j_d = [[0,31,59,90,120,151,181,212,243,273,304,334],[0,31,60,91,121,152,182,213,244,274,305,335]];

function getMonthJulian(year, month)
{
	return m_j_d[isLeapYear(year)?1:0][month];
}

var j_d=new Array();
j_d[1970]=0;
j_d[1971]=365;
j_d[1972]=730;
j_d[1973]=1096;
j_d[1974]=1461;
j_d[1975]=1826;
j_d[1976]=2191;
j_d[1977]=2557;
j_d[1978]=2922;
j_d[1979]=3287;
j_d[1980]=3652;
j_d[1981]=4018;
j_d[1982]=4383;
j_d[1983]=4748;
j_d[1984]=5113;
j_d[1985]=5479;
j_d[1986]=5844;
j_d[1987]=6209;
j_d[1988]=6574;
j_d[1989]=6940;
j_d[1990]=7305;
j_d[1991]=7670;
j_d[1992]=8035;
j_d[1993]=8401;
j_d[1994]=8766;
j_d[1995]=9131;
j_d[1996]=9496;
j_d[1997]=9862;
j_d[1998]=10227;
j_d[1999]=10592;
j_d[2000]=10957;
j_d[2001]=11323;
j_d[2002]=11688;
j_d[2003]=12053;
j_d[2004]=12418;
j_d[2005]=12784;
j_d[2006]=13149;
j_d[2007]=13514;
j_d[2008]=13879;
j_d[2009]=14245;
j_d[2010]=14610;
j_d[2011]=14975;
j_d[2012]=15340;
j_d[2013]=15706;
j_d[2014]=16071;
j_d[2015]=16436;
j_d[2016]=16801;
j_d[2017]=17167;
j_d[2018]=17532;
j_d[2019]=17897;
j_d[2020]=18262;
j_d[2021]=18628;
j_d[2022]=18993;
j_d[2023]=19358;
j_d[2024]=19723;
j_d[2025]=20089;
j_d[2026]=20454;
j_d[2027]=20819;
j_d[2028]=21184;
j_d[2029]=21550;
j_d[2030]=21915;

function get_julian_date(d)
{
    return j_d[d.getFullYear()]+getMonthJulian(d.getFullYear(),d.getMonth())+d.getDate()-1;   
}

function getMonthIndex(sMonth)
{
    var m = -1;
    sMonth = String(sMonth).toUpperCase();
    for ( var i=0; i < NLDate_short_months.length; i++ )
    {
        if ( NLDate_short_months[i].toUpperCase() == sMonth )
        {
            m = i + 1; break;
        }
    }
    if(m != -1)
    	return m;
    for ( var i=0; i < NLDate_months.length; i++ )
    {
        if ( NLDate_months[i].toUpperCase() == sMonth )
        {
            m = i + 1; break;
        }
    }
    if(m != -1)
    	return m;
    else
    {
        var ms = "JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC";
        m = (ms.indexOf(sMonth)+3)/3;
    }
    return m;
}

function _hhmm_to_mins(time) {
    return time.hrs * 60 + time.mins;
}

function round_hhmm_nearest(hrs, mins, round_by) {
    var up_time = round_hhmm_up(hrs, mins, round_by);
    var down_time = round_hhmm_down(hrs, mins, round_by);

    orig_mins = _hhmm_to_mins({
        hrs: hrs,
        mins: mins
    });
    up_mins = _hhmm_to_mins(up_time);
    down_mins = _hhmm_to_mins(down_time);

    if (up_mins - orig_mins > orig_mins - down_mins) {
        return down_time;
    } else {
        return up_time;
    }
}

function round_hhmm_up(hrs, mins, round_by) {
    mins += (mins % round_by > 0 ? (round_by - (mins % round_by)) : 0);
    if (mins >= 60) {
        var _hhmm_delta = Math.floor(mins / 60);
        mins -= (_hhmm_delta * 60);
        hrs += _hhmm_delta;
    }
    return {
        hrs: hrs,
        mins: mins
    };
}

function round_hhmm_down(hrs, mins, round_by) {
    mins -= (mins > 0 ? (mins % round_by) : 0);
    return {
        hrs: hrs,
        mins: mins
    };
}

function round_hhmm(val, round_by, direction) {
	if (val == "") return val;
	var re = /^([0-9]+?):([0-9]+)$/;
	var result = re.exec(val);
	if (result == null) {
		result = format_hhmm(val);
		if (result == null) return val;
	}
	var hrs = parseFloat(result[1]);
	var mins = parseFloat(result[2]);
	var time;
	if (direction == 'UP') {
		time = round_hhmm_up(hrs, mins, round_by);
	} else if (direction == 'DOWN') {
		time = round_hhmm_down(hrs, mins, round_by);
	} else if (direction == 'NEAR') {
		time = round_hhmm_nearest(hrs, mins, round_by);
	} else {
		throw direction + ' is not vald direction: [UP,DOWN,NEAREST]';
	}
	if (time.mins < 10) time.mins = '0' + time.mins;
	return time.hrs + ':' + time.mins;
}

function format_hhmm(val) {
	var hours;
	var minutes;

	var re = /([0-9][0-9]?)?(:[0-9][0-9]+)?/
	var result = re.exec(val)
	if (result == null || result.index > 0 || result[0].length != val.length) {
		timeval = parseFloat(val);
		if (isNaN(timeval)) hours = -1;
		else {
			hours = Math.floor(timeval);
			minutes = Math.floor((timeval - hours) * 60 + 0.5);
		}
	} else {
		if (RegExp.$1.length > 0) hours = parseInt(RegExp.$1, 10);
		else hours = 0;
		if (typeof (RegExp.$2) != "undefined" && RegExp.$2.length > 0) {
			minutes = parseInt(RegExp.$2.substr(1), 10);
			// if the user entered a value >= 60 for minutes, add the extra hours to the hours var and reduce
			// minutes to be less than 60
			if (minutes >= 60) {
				var hours_delta = Math.floor(minutes / 60);
				minutes -= (hours_delta * 60);
				hours += hours_delta;
			}
		} else minutes = 0;
	}
	if (hours >= 0 && minutes >= 0 && minutes < 60) {
		return [val, hours, minutes];
	}
}

function hhmmtofloat(val)
{
	if ((val == null) || (val == ""))
		return 0;
	var re = /^([0-9]+?):([0-9]+)$/;
	var result = re.exec(val);
	if (result == null)
	{
		result = format_hhmm(val);
		if (result == null)
			return 0;
	}
	var hrs = parseFloat(result[1]);
	var mins = parseFloat(result[2]);

	return 60*hrs + mins;
}

function parse_time(val) {

	if (val == null || val.trim().length == 0)
		return null;

	var time = {hours: 0, minutes: 0, negative: false};

	var rexp = /^(\-?)(\d*)(:(\d+))?$/;
	var rexpRes = rexp.exec(val);

	if (rexpRes == null) {
		var timeval = parseFloat(val);
		if (isNaN(timeval)) {
			return null;
		} else {
			if (timeval < 0) {
				timeval = Math.abs(timeval);
				time.negative = true;
			}
			time.hours = Math.floor(timeval);
			time.minutes = Math.round((timeval - time.hours) * 60);
		}
	} else {

		if (typeof rexpRes[2] != "undefined" && rexpRes[2].trim().length > 0) {
			time.hours = parseInt(rexpRes[2], 10);
		}

		if (typeof rexpRes[4] != "undefined" && rexpRes[4].trim().length > 0) {
			time.minutes = parseInt(rexpRes[4], 10);
			// if the user entered a value >= 60 for minutes, add the extra hours to the hours var and reduce minutes to be less than 60
			if (time.minutes >= 60) {
				var delta = Math.floor(time.minutes / 60);
				time.hours += delta;
				time.minutes -= delta * 60;
			}
		}
		if (rexpRes[1] == '-' && (time.hours > 0 || time.minutes > 0))
			time.negative = true;
	}
	return time;
}

function round_hhmm2(val, round_by, direction) {

	var result = parse_time(val);
	if (result == null) {
		return val;
	}
	var hrs = result.hours;
	var mins = result.minutes;
	var time;
	if (direction == 'UP') {
		time = round_hhmm_up(hrs, mins, round_by);
	} else if (direction == 'DOWN') {
		time = round_hhmm_down(hrs, mins, round_by);
	} else if (direction == 'NEAR') {
		time = round_hhmm_nearest(hrs, mins, round_by);
	} else {
		throw direction + ' is not vald direction: [UP,DOWN,NEAREST]';
	}
	if (time.mins < 10) time.mins = '0' + time.mins;
	return (result.negative ? '-' : '') + time.hrs + ':' + time.mins;
}

// copypasta from N/util/date.js for now
function OracleDateTimeFormatter(settingsContainer, japaneseEraHandlers, shortMonthsMap, longMonthsMap) {
	var that = this;
	this.settingsContainer = settingsContainer;
	this.shortMonthsMap = shortMonthsMap === undefined ? settingsContainer.datetime_short_months : shortMonthsMap;
	this.longMonthsMap = longMonthsMap === undefined ? settingsContainer.datetime_months : longMonthsMap;

	this.getJapaneseImperialEra = japaneseEraHandlers.getJapaneseImperialEra;
	this.getShortJapaneseImperialEra = japaneseEraHandlers.getShortJapaneseImperialEra;
	this.getJapaneseImperialYear = japaneseEraHandlers.getJapaneseImperialYear;

	function DateTimeElementType(matchPattern, formatterFunction) {
		this.matchRegexp = new RegExp('^' + matchPattern, 'i');
		this.formatterFunction = formatterFunction;
	}

	function DateTimeElement(elementType, value, isUnpadded, isStrict) {
		this.elementType = elementType;
		this.value = value;
		this.isUnpadded = isUnpadded;
		this.isStrict = isStrict;
		this.formatterFunction = elementType.formatterFunction;
	}

	this.padChar = function padChar(value, length, characterToPad) {
		while (value.length < length) {
			value = characterToPad + value;
		}
		return value;
	};

	this.padZeros = function padZeros(value, length) {
		return that.padChar(value, length, '0');
	};

	this.padSpace = function padSpace(value, length) {
		return that.padChar(value, length, ' ');
	};

	this.formatDateTimeElement = function formatDateTimeElement(element, valueFromDateObject, maxWidth) {
		var width = element.value.length;

		if (maxWidth !== undefined && width > maxWidth) {
			width = maxWidth;
		}
		var isUnpadded = element.isUnpadded;
		var padFunc = isNaN(valueFromDateObject) ? that.padSpace : that.padZeros;
		var valueAsString = valueFromDateObject.toString();

		return isUnpadded ? valueAsString : padFunc(valueAsString, width);
	};


	this.formatters = Object.freeze({
		formatMeridian: function formatMeridian(dateTimeElement, dateObject) {
			//noinspection JSUnresolvedVariable
			var amvar = that.settingsContainer.datetime_am_string || '';
			//noinspection JSUnresolvedVariable
			var pmvar = that.settingsContainer.datetime_pm_string || '';
			var hours = dateObject.getHours();
			return hours < 12 ? amvar : pmvar;
		},

		formatDayOfMonth: function formatDayOfMonth(dateTimeElement, dateObject) {
			return that.formatDateTimeElement(dateTimeElement, dateObject.getDate())
		},

		formatDayOfWeek: function formatDayOfWeek(dateTimeElement, dateObject) {
			return that.formatDateTimeElement(dateTimeElement, dateObject.getDay());
		},

		formatLongEra: function formatLongEra(dateTimeElement, dateObject) {
			return that.getJapaneseImperialEra(dateObject);
		},

		formatShortEra: function formatShortEra(dateTimeElement, dateObject) {
			return that.getShortJapaneseImperialEra(dateObject);
		},

		format24Hour: function format24Hour(dateTimeElement, dateObject) {
			return that.formatDateTimeElement(dateTimeElement, dateObject.getHours(), 2);
		},

		format12Hour: function format12Hour(dateTimeElement, dateObject) {
			var valueIn12Hour = dateObject.getHours() % 12;
			// 00 in 24h corresponds to 12 am
			if (valueIn12Hour === 0) valueIn12Hour = 12;
			return that.formatDateTimeElement(dateTimeElement, valueIn12Hour, 2);
		},

		formatISOYear: function formatISOYear(dateTimeElement, dateObject) {
			return this.formatYear(dateTimeElement, dateObject);
		},

		formatMonth: function formatMonth(dateTimeElement, dateObject) {
			return that.formatDateTimeElement(dateTimeElement, dateObject.getMonth() + 1);
		},

		formatMinute: function formatMinute(dateTimeElement, dateObject) {
			return that.formatDateTimeElement(dateTimeElement, dateObject.getMinutes());
		},

		formatLongMonthName: function formatLongMonthName(dateTimeElement, dateObject) {
			return that.longMonthsMap[dateObject.getMonth()];
		},

		formatShortMonthName: function formatShortMonthName(dateTimeElement, dateObject) {
			return that.shortMonthsMap[dateObject.getMonth()];
		},

		formatSeconds: function formatSeconds(dateTimeElement, dateObject) {
			return that.formatDateTimeElement(dateTimeElement, dateObject.getSeconds());
		},

		formatYear: function formatYear(dateTimeElement, dateObject) {
			var yearValue = that.getFullYear(dateObject);
			return that.formatDateTimeElement(dateTimeElement, yearValue);
		},

		formatLastDigitOfYear: function formatLastDigitOfYear(dateTimeElement, dateObject) {
			var yearAsString = that.getFullYear(dateObject).toString();
			return yearAsString.substr(-dateTimeElement.value.length);
		},

		formatText: function formatText(dateTimeElement, dateObject) {
			return dateTimeElement.value.replace(/"/g, "");
		},

		formatAsIs: function formatAsIs(dateTimeElement, dateObject) {
			return dateTimeElement.value;
		}
	});

	this.getFullYear = function getFullYearDefaultImpl(dateObject) {
		return dateObject.getFullYear();
	};

	this.dateTimeElementTypes = Object.freeze({
		AD_INDICATOR: new DateTimeElementType('A\.D\.|AD'),
		MERIDIAN: new DateTimeElementType('[AP]\.M\.|[AP]M', that.formatters.formatMeridian),
		ERA_INDICATOR: new DateTimeElementType('B\.C\.|BC'),
		CENTURY: new DateTimeElementType('S?CC'),
		DAY_NAME: new DateTimeElementType('DAY'),
		ABBREV_DAY_NAME: new DateTimeElementType('DY'),
		DAY_OF_YEAR: new DateTimeElementType('DDD'),
		DAY_OF_MONTH: new DateTimeElementType('DD', that.formatters.formatDayOfMonth),
		SHORT_DATE: new DateTimeElementType('DS'),
		LONG_DATE: new DateTimeElementType('DL'),
		DAY_OF_WEEK: new DateTimeElementType('D', that.formatters.formatDayOfWeek),
		FULL_ERA: new DateTimeElementType('EE', that.formatters.formatLongEra),
		ABBREV_ERA: new DateTimeElementType('E', that.formatters.formatShortEra),
		FRACTIONAL_SECONDS: new DateTimeElementType('FF[1-9]'),
		HOUR_OF_DAY_24: new DateTimeElementType('HH24', that.formatters.format24Hour),
		HOUR_OF_DAY_12: new DateTimeElementType('HH(12)?', that.formatters.format12Hour),
		ISO_WEEK_OF_YEAR: new DateTimeElementType('IW'),
		ISO_YEAR: new DateTimeElementType('IY{0,3}', that.formatters.formatISOYear),
		JULIAN_DAY: new DateTimeElementType('J'),
		MINUTE: new DateTimeElementType('MI', that.formatters.formatMinute),
		MONTH: new DateTimeElementType('MM', that.formatters.formatMonth),
		LONG_MONTH_NAME: new DateTimeElementType('Month', that.formatters.formatLongMonthName),
		SHORT_MONTH_NAME: new DateTimeElementType('Mon', that.formatters.formatShortMonthName),
		QUARTER_OF_YEAR: new DateTimeElementType('Q'),
		ROMAN_NUMERAL_MONTH: new DateTimeElementType('RM'),
		LONG_ROUNDED_YEAR: new DateTimeElementType('RRRR'),
		SHORT_ROUNDED_YEAR: new DateTimeElementType('RR'),
		SECONDS_PAST_MIDNIGHT: new DateTimeElementType('SSSSS'),
		SECONDS: new DateTimeElementType('SS', that.formatters.formatSeconds),
		SHORT_TIME: new DateTimeElementType('TS'),
		TZ_DAYLIGHT_SAVING: new DateTimeElementType('TZD'),
		TZ_HOUR: new DateTimeElementType('TZH'),
		TZ_MINUTE: new DateTimeElementType('TZM'),
		TZ_REGION: new DateTimeElementType('TZR'),
		WEEK_OF_YEAR: new DateTimeElementType('WW'),
		WEEK_OF_MONTH: new DateTimeElementType('W'),
		LOCAL_RADIX: new DateTimeElementType('X'),
		FOUR_DIGIT_YEAR: new DateTimeElementType('S?YYYY', that.formatters.formatYear),
		SPELLED_OUT_YEAR: new DateTimeElementType('S?YEAR'),
		LAST_DIGIT_OF_YEAR: new DateTimeElementType('Y{1,3}', that.formatters.formatLastDigitOfYear),
		TEXT: new DateTimeElementType('"[^"]*"', that.formatters.formatText),
		PUNCTUATION: new DateTimeElementType('[-/,.;:]+', that.formatters.formatAsIs),
		WHITESPACE: new DateTimeElementType('\\s+', that.formatters.formatAsIs),
		UNPAD_MOD: new DateTimeElementType('fm'),
		STRICT_MOD: new DateTimeElementType('fx'),
		SINGLE_QUOTE: new DateTimeElementType('\'\'', that.formatters.formatAsIs)
	});

	// Javascript does not guarantee ordering of object properties (obviously)
	// but we "resolve" parsing ambiguities by letting first match win
	// thus we have to explicitly order the element types to avoid parse aliasing
	this.matchOrder = [
		this.dateTimeElementTypes.AD_INDICATOR,
		this.dateTimeElementTypes.MERIDIAN,
		this.dateTimeElementTypes.ERA_INDICATOR,
		this.dateTimeElementTypes.CENTURY,
		this.dateTimeElementTypes.DAY_NAME,
		this.dateTimeElementTypes.ABBREV_DAY_NAME,
		this.dateTimeElementTypes.DAY_OF_YEAR,
		this.dateTimeElementTypes.DAY_OF_MONTH,
		this.dateTimeElementTypes.SHORT_DATE,
		this.dateTimeElementTypes.LONG_DATE,
		this.dateTimeElementTypes.DAY_OF_WEEK,
		this.dateTimeElementTypes.FULL_ERA,
		this.dateTimeElementTypes.ABBREV_ERA,
		this.dateTimeElementTypes.FRACTIONAL_SECONDS,
		this.dateTimeElementTypes.HOUR_OF_DAY_24,
		this.dateTimeElementTypes.HOUR_OF_DAY_12,
		this.dateTimeElementTypes.ISO_WEEK_OF_YEAR,
		this.dateTimeElementTypes.ISO_YEAR,
		this.dateTimeElementTypes.JULIAN_DAY,
		this.dateTimeElementTypes.MINUTE,
		this.dateTimeElementTypes.MONTH,
		this.dateTimeElementTypes.LONG_MONTH_NAME,
		this.dateTimeElementTypes.SHORT_MONTH_NAME,
		this.dateTimeElementTypes.QUARTER_OF_YEAR,
		this.dateTimeElementTypes.ROMAN_NUMERAL_MONTH,
		this.dateTimeElementTypes.LONG_ROUNDED_YEAR,
		this.dateTimeElementTypes.SHORT_ROUNDED_YEAR,
		this.dateTimeElementTypes.SECONDS_PAST_MIDNIGHT,
		this.dateTimeElementTypes.SECONDS,
		this.dateTimeElementTypes.SHORT_TIME,
		this.dateTimeElementTypes.TZ_DAYLIGHT_SAVING,
		this.dateTimeElementTypes.TZ_HOUR,
		this.dateTimeElementTypes.TZ_MINUTE,
		this.dateTimeElementTypes.TZ_REGION,
		this.dateTimeElementTypes.WEEK_OF_YEAR,
		this.dateTimeElementTypes.WEEK_OF_MONTH,
		this.dateTimeElementTypes.LOCAL_RADIX,
		this.dateTimeElementTypes.FOUR_DIGIT_YEAR,
		this.dateTimeElementTypes.SPELLED_OUT_YEAR,
		this.dateTimeElementTypes.LAST_DIGIT_OF_YEAR,
		this.dateTimeElementTypes.TEXT,
		this.dateTimeElementTypes.PUNCTUATION,
		this.dateTimeElementTypes.WHITESPACE,
		this.dateTimeElementTypes.UNPAD_MOD,
		this.dateTimeElementTypes.STRICT_MOD,
		this.dateTimeElementTypes.SINGLE_QUOTE
	];

	this.numericalMonthTypes = [
		this.dateTimeElementTypes.MONTH
	];

	this.textualMonthTypes = [
		this.dateTimeElementTypes.SHORT_MONTH_NAME,
		this.dateTimeElementTypes.LONG_MONTH_NAME
	];

	this.yearTypes = [
		this.dateTimeElementTypes.ISO_YEAR,
		this.dateTimeElementTypes.LAST_DIGIT_OF_YEAR,
		this.dateTimeElementTypes.FOUR_DIGIT_YEAR
	];

	this.separatorTypes = [
		this.dateTimeElementTypes.PUNCTUATION,
		this.dateTimeElementTypes.WHITESPACE,
		this.dateTimeElementTypes.TEXT
	];


	this.parseDateTimeFormat = function parseDateTimeFormat(formatSpecifier) {
		if (formatSpecifier === undefined) {
			formatSpecifier = this.settingsContainer.dateformat;
		}

		var elements = [];
		var isUnpadded = false;
		var isStrict = false;

		var index = 0;
		var specifierLength = formatSpecifier.length;

		while (index < specifierLength) {
			var remainder = formatSpecifier.substring(index, specifierLength);
			var matchResult = null;

			if (matchResult = this.matchDateTimeElement(this.dateTimeElementTypes.UNPAD_MOD, remainder)) {
				isUnpadded = !isUnpadded;
			} else if (matchResult = this.matchDateTimeElement(this.dateTimeElementTypes.STRICT_MOD, remainder)) {
				isStrict = !isStrict;
			} else {
				for (var i = 0; i < this.matchOrder.length; i++) {
					var dateTimeElementType = this.matchOrder[i];
					matchResult = this.matchDateTimeElement(dateTimeElementType, remainder);
					if (matchResult !== null) {
						elements.push(new DateTimeElement(dateTimeElementType, matchResult, isUnpadded, isStrict));
						break;
					}
				}
			}
			if (matchResult === null) {
				throw "Failed to parse format specifier '"+ formatSpecifier + "': Unrecognized element at position " + index;
			}
			index += matchResult.length;
		}

		return elements;
	};

	this.matchDateTimeElement = function matchDateTimeElement(dateTimeElementType, inputString) {
		var matchResult = dateTimeElementType.matchRegexp.exec(inputString);

		if (matchResult === null || matchResult.index !== 0) return null;

		return matchResult[0];
	};

	this.formatDateTime = function formatDateTime(date, formatSpecifier) {
		var elements = this.parseDateTimeFormat(formatSpecifier);

		// check if there is era among elements, if yes we have to reset the year getter to work with Japanese calendar
		var containsEra = elements.some(function (element) {
			return (
				element.elementType === that.dateTimeElementTypes.FULL_ERA ||
				element.elementType === that.dateTimeElementTypes.ABBREV_ERA
			);
		});

		if (containsEra) {
			this.getFullYear = this.getJapaneseImperialYear
		}

		return this.formatDateTimeFromElements(elements, date);
	};

	this.formatDateTimeFromElements = function formatDateTimeFromElements(elements, dateObject) {
		return elements.map(function (element) {
			var formatterFunction = element.formatterFunction;
			if (formatterFunction === undefined) {
				throw "No formatting function associated with element type " + element.elementType.toString();
			}
			return formatterFunction(element, dateObject);
		}).join('');
	};

	this.formatMMYYDateString = function formatMMYYDateString(dateObject, dateFormat) {
		var elements = this.extractMMYYElements(this.parseDateTimeFormat(dateFormat));
		return this.formatDateTimeFromElements(elements, dateObject);
	};

	this.extractMMYYElements = function extractMMYYElements(dateFormatElements) {

		var elementsLength = dateFormatElements.length;
		var index = 0;
		var monthElement = null,
			yearElement = null,
			separator = null;

		// this complex logic is needed to preserve the rules from the original code
		// namely long months are replaced by short month names and some separators (punctuation, whitespace) are replaced
		// by some long forgotten rules
		while (index < elementsLength && (monthElement === null || yearElement === null || separator === null)) {
			var currentElement = dateFormatElements[index];
			var currentType = currentElement.elementType;
			var currentValue = currentElement.value;
			var currentIsUnpadded = currentElement.isUnpadded;
			var currentIsStrict = currentElement.isStrict;

			var nextElementType = index + 1 !== elementsLength ? dateFormatElements[index + 1].elementType : undefined;

			if (monthElement === null && this.numericalMonthTypes.indexOf(currentType) !== -1) {
				monthElement = currentElement;
			} else if (monthElement === null && this.textualMonthTypes.indexOf(currentType) !== -1) {
				monthElement = new DateTimeElement(
					this.dateTimeElementTypes.SHORT_MONTH_NAME, 'Mon', currentIsUnpadded, currentIsStrict);
			} else if (yearElement === null && this.yearTypes.indexOf(currentType) !== -1) {
				yearElement = currentElement;
			} else if (separator === null && this.separatorTypes.indexOf(currentType) !== -1) {
				if (currentValue === '-' || (currentValue === '.' && nextElementType !== this.dateTimeElementTypes.WHITESPACE)) {
					separator = currentElement;
				} else {
					separator = new DateTimeElement(
						this.dateTimeElementTypes.PUNCTUATION, '/', currentIsUnpadded, currentIsStrict);
				}
			}
			index++;
		}

		return [monthElement, separator, yearElement].filter(function (value) { return value !== null });
	};

	// strip the incoming datetime format of elements that may trip up the parsing functions define here
	this.preprocessDateTimeFormat = function preprocessDateTimeFormat(inputFormat) {
		return inputFormat.replace(/f[mx]|"/ig, "");
	}
}

var oracleDateTimeFormatterFactory = (function() {
	var _instance = null;
	return {
		getFormatter: function () {
			if (_instance === null) {
				_instance = new OracleDateTimeFormatter(
					window,
					{
						getJapaneseImperialEra: get_japanese_imperial_era,
						getShortJapaneseImperialEra: get_short_japanese_imperial_era,
						getJapaneseImperialYear: get_japanese_imperial_year
					},
					NLDate_short_months,
					NLDate_months
				);
			}
			return _instance;
		}
	};
})();



function NLDate_parseString(sDate, bDoAlert, id)
{
    var m=0;
    var d=0;
    var y=0;
    var val = String(sDate).trim();
    var fmterr = "";
    var year="";
    var year_char_index, month_char_index, day_char_index;
    var rtnDate = null, l, str, c, comps;

    if(!window.dateformat)
        window.dateformat = "fmMM/DDfm/YYYY"; 

	var dateformat = window.dateformat.replace(/f[mx]/gi, '').replace(/"/g, '');

    if(val == "")
    {
        return new Date();
    }
    else if(dateformat == "MM/DD/YYYY")
    {
        if (val.indexOf("/") != -1)
        {
            c = val.split("/");
            if(onlydigits(c[0])) m = parseInt(c[0],10);
            if(onlydigits(c[1])) d = parseInt(c[1],10);
            
            if ( d > 1970 )
            {
                year = y = d;
                d = 1;
            }
            else
            {
                if(onlydigits(c[2])) y = parseInt(c[2],10);
                year=c[2];
            }
        }
        else
        {
            l = val.length;
            str = val.substr(0,2-l%2); if(onlydigits(str)) m = parseInt(str,10);
            str = val.substr(2-l%2,2); if(onlydigits(str)) d = parseInt(str,10);
            str = val.substr(4-l%2);   if(onlydigits(str)) y = parseInt(str,10);
            year=str;
        }
    }
    else if(dateformat == "DD/MM/YYYY")
    {
        if (val.indexOf("/") != -1)
        {
            c = val.split("/");
            if(onlydigits(c[0])) d = parseInt(c[0],10);
            if(onlydigits(c[1])) m = parseInt(c[1],10);
            if(onlydigits(c[2])) y = parseInt(c[2],10);
            year=c[2];
        }
        else
        {
            l = val.length;
            str = val.substr(0,2-l%2); if(onlydigits(str)) d = parseInt(str,10);
            str = val.substr(2-l%2,2); if(onlydigits(str)) m = parseInt(str,10);
            str = val.substr(4-l%2);   if(onlydigits(str)) y = parseInt(str,10);
            year=str;
        }
    }
    else if(dateformat == "YYYY/MM/DD")
    {
        if (val.indexOf("/") != -1)
        {
            c = val.split("/");
            if(onlydigits(c[0])) y = parseInt(c[0],10);
            if(onlydigits(c[1])) m = parseInt(c[1],10);
            if(onlydigits(c[2])) d = parseInt(c[2],10);
            year=c[0];
        }
        else
        {
            l = val.length;
            str = val.substr(0,2-l%2); if(onlydigits(str)) y = parseInt(str,10);
            str = val.substr(2-l%2,2); if(onlydigits(str)) m = parseInt(str,10);
            str = val.substr(4-l%2);   if(onlydigits(str)) d = parseInt(str,10);
            year=str;
        }
    }
    else if(dateformat == "DD.MM.YYYY")
    {
        if (val.indexOf(".") != -1)
        {
            c = val.split(".");
            if(onlydigits(c[0])) d = parseInt(c[0],10);
            if(onlydigits(c[1])) m = parseInt(c[1],10);
            if(onlydigits(c[2])) y = parseInt(c[2],10);
            year=c[2];
        }
        else
        {
            l = val.length;
            str = val.substr(0,2-l%2); if(onlydigits(str)) d = parseInt(str,10);
            str = val.substr(2-l%2,2); if(onlydigits(str)) m = parseInt(str,10);
            str = val.substr(4-l%2);   if(onlydigits(str)) y = parseInt(str,10);
            year=str;
        }
    }
    else if(dateformat == "DD-Mon-YYYY")
    {
        if (val.indexOf("-") != -1)
        {
            c = val.split("-");
            if(onlydigits(c[0])) d = parseInt(c[0],10);
            m = getMonthIndex(c[1]);
            if(onlydigits(c[2])) y = parseInt(c[2],10);
            year=c[2];
        }
        else
        {
            l = val.length;
            str = val.substr(0,1+l%2); if(onlydigits(str)) d = parseInt(str,10);
            str = val.substr(1+l%2,3);
            m = getMonthIndex(str);
            str = val.substr(4+l%2);   if(onlydigits(str)) y = parseInt(str,10);
            year=str;
        }
    }
    else if(dateformat == "DD-MONTH-YYYY")
    {
        comps = val.split("-");
        if(onlydigits(comps[0]))
            d = parseInt(comps[0]);
        m = arrayIndexOf(NLDate_months, comps[1], true) + 1;
        if(onlydigits(comps[2]))
        {
            y = parseInt(comps[2]);
            year = y;
        }
    }
    else if(dateformat == "YYYY-MM-DD")
    {
        comps = val.split("-");
        if(onlydigits(comps[2]))
            d = parseInt(comps[2]);
        if(onlydigits(comps[1]))
            m = parseInt(comps[1]);
        if(onlydigits(comps[0]))
        {
            y = parseInt(comps[0]);
            year = y;
        }
    }
	else if(dateformat == "EEYY年MM月DD日")
    {
        year_char_index = val.indexOf(year_char_cn);
        month_char_index = val.indexOf(month_char_cn);
        day_char_index = val.indexOf(day_char_cn);
        if(onlydigits(val.substring(month_char_index+1,day_char_index)))
            d = parseInt(val.substring(month_char_index+1,day_char_index));
        if(onlydigits(val.substring(year_char_index+1,month_char_index)))
            m = parseInt(val.substring(year_char_index+1,month_char_index));
        var era = val.substring(0, 2);
        if(onlydigits(val.substring(2,year_char_index)))
        {
            y = get_gregorian_year(parseInt(val.substring(2,year_char_index)), era);
            year = y;
        }
    }
	else if(dateformat == "YYYY年MM月DD日")
    {
        year_char_index = val.indexOf(year_char_cn);
        month_char_index = val.indexOf(month_char_cn);
        day_char_index = val.indexOf(day_char_cn);
        if(onlydigits(val.substring(month_char_index+1,day_char_index)))
            d = parseInt(val.substring(month_char_index+1,day_char_index));
        if(onlydigits(val.substring(year_char_index+1,month_char_index)))
            m = parseInt(val.substring(year_char_index+1,month_char_index));
        if(onlydigits(val.substring(0,year_char_index)))
        {
            y = parseInt(val.substring(0,year_char_index));
            year = y;
        }
    }
    else if(dateformat == "EYY.MM.DD")
    {
        comps = val.split(".");
        if(onlydigits(comps[2]))
            d = parseInt(comps[2]);
        if(onlydigits(comps[1]))
            m = parseInt(comps[1]);
        var era = comps[0].substring(0, 1);
        if(onlydigits(comps[0].substring(1,comps[0].length)))
        {
            y = get_gregorian_year(parseInt(comps[0].substring(1,comps[0].length)), era);
            year = y;
        }
    }
    else if(dateformat == "DD. Mon YYYY")
    {
        comps = val.split(" ");
        if(onlydigits(comps[0].substring(0, comps[0].length - 1)))
            d = parseInt(comps[0].substring(0, comps[0].length - 1));
        m = getMonthIndex(comps[1]);
        if(onlydigits(comps[2]))
        {
            y = parseInt(comps[2]);
            year = y;
        }
    }
    else if(dateformat == "DD de MONTH de YYYY")
    {
        comps = val.split(" de ");
        if(onlydigits(comps[0]))
            d = parseInt(comps[0]);
        m = arrayIndexOf(NLDate_months, comps[1]) + 1;
        if(onlydigits(comps[2]))
        {
            y = parseInt(comps[2]);
            year = y;
        }
    }
	else if(dateformat == "YYYY년 MM월 DD일")
    {
        comps = val.split(" ");
        if(comps[2] && onlydigits(comps[2].substring(0, comps[2].length-1)))
            d = parseInt(comps[2].substring(0, comps[2].length-1));
        if(comps[1] && onlydigits(comps[1].substring(0, comps[1].length-1)))
            m = parseInt(comps[1].substring(0, comps[1].length-1));
        if(onlydigits(comps[0].substring(0, comps[0].length-1)))
        {
            y = parseInt(comps[0].substring(0, comps[0].length-1));
            year = y;
        }
    }
	else if(dateformat == "DD MONTH YYYY")
	{
		comps = val.split(" ");
		if(onlydigits(comps[0]))
			d = parseInt(comps[0]);
		m = arrayIndexOf(NLDate_months, comps[1], true) + 1;
		if(onlydigits(comps[2]))
		{
			y = parseInt(comps[2]);
			year = y;
		}
	}
	else if(dateformat == "DD MONTH, YYYY")
	{
		comps = val.split(" ");
		if(onlydigits(comps[0]))
			d = parseInt(comps[0]);
		m = arrayIndexOf(NLDate_months, comps[1] && comps[1].substring(0, comps[1].length-1), true) + 1;
		if(onlydigits(comps[2]))
		{
			y = parseInt(comps[2]);
			year = y;
		}
	}

    if(m==0 || d==0)
    {
        if(bDoAlert)
        {
            if(fmterr == "")
                fmterr = window.dateformat;
            alert("Invalid date value (must be "+window.userfacing_dateformat+")");
        }
    }
    else
    {
        if (y==0 && !onlydigits(year)) y = (new Date()).getFullYear();  
        if (isNaN(m) || isNaN(d) || isNaN(y) || m < 1 || m > 12 || d < 1 || d > 31 || (y >= 100 && y < 1000) || y > 9999)
            makeValidationQuirkLog('date', sDate, "Awkward Coersion of Date (Date Format is:" + window.dateformat + ")", id);
        if(m<1) m=1; else if(m>12) m=12;
        if(d<1) d=1; else if(d>31) d=31;
        if(y<100) y+=((y>=70)?1900:2000);
        if(y<1000) y*=10;
        if (y > 9999) y = (new Date()).getFullYear();

        year = y;
		rtnDate = validateDate(new Date(y, m-1, d), bDoAlert);
		if ( (rtnDate != null) && (y != nlGetFullYear(rtnDate) || m != rtnDate.getMonth() + 1 || d != rtnDate.getDate()))
		{
			rtnDate = validateDate(new Date(y, m-1, d, 12, 30), bDoAlert);
			if ( (rtnDate != null) && (y != nlGetFullYear(rtnDate) || m != rtnDate.getMonth() + 1 || d != rtnDate.getDate()))
			{
				rtnDate = null;
			}
		}        
    }

    return rtnDate;
}

function validateDate(dDate, bDoAlert)
{
	if (isNaN(dDate) || dDate.getTime() < -11636672400000)
	{
		dDate = null;
		if (bDoAlert)
			alert("Invalid date value (must be on or after "+getdatestring(new Date(-11636672400000))+")");
	}
	return dDate;
}


var NLAlertContext_CREDIT_CARD_NUMBERS_MUST_CONTAIN_BETWEEN_13_AND_20_DIGITS = "Credit card numbers must contain between 13 and 20 digits.";
var NLAlertContext_CREDIT_CARD_NUMBERS_MUST_CONTAIN_ONLY_DIGITS = "Credit card numbers must contain only digits.";
var NLAlertContext_EMAIL_ADDRESSES_MUST_MATCH = "Email addresses must match.";
var NLAlertContext_NETSUITE_DOES_NOT_ACCEPT_EMAIL_ADDRESSES_WITH_QUOTATION_MARKS_COMMAS_COLONS_SPACES_OR_GREATER_THAN_OR_LESS_THAN_SIGNS = "Please make sure there are no quotation marks, commas, colons, spaces, or greater than or less than signs.";
var NLAlertContext_PASSWORDS_DONT_MATCHN = "Passwords don\'t match.\n";
var NLAlertContext_PASSWORDS_CANNOT_BE_EMPTYN = "Passwords cannot be empty.\n";
var NLAlertContext_PASSWORDS_MUST_BE_AT_LEAST_1_CHARACTERS_LONGN = "Passwords must be at least {1} characters long.";
var NLAlertContext_PASSWORDS_MUST_CONTAIN_AT_LEAST_ONE_LETTER_AZN = "Passwords must contain at least one letter (A-Z).\n";
var NLAlertContext_PASSWORDS_MUST_CONTAIN_AT_LEAST_ONE_NUMBER_OR_SPECIAL_CHARACTERN = "Passwords must contain at least one number or special character.\n";
var NLAlertContext_PASSWORDS_MAY_CONTAIN_ONLY_LETTERS_NUMBERS_AND_SPECIAL_CHARACTERSN = "Passwords may contain only letters, numbers, and special characters.\n";
var NLAlertContext_OLD_AND_NEW_PASSWORDS_ARE_TOO_SIMILAR = "Old and new passwords are too similar.";
var NLAlertContext_PASSWORD_MUST_NOT_BE_THE_SAME_AS_THE_EMAIL_ADDRESS = "Password must not be the same as the email address";
var NLAlertContext_CREDIT_CARD_NUMBER_IS_NOT_VALID__PLEASE_CHECK_THAT_ALL_DIGITS_WERE_ENTERED_CORRECTLY = "Credit card number is not valid.  Please check that all digits were entered correctly.";
var NLAlertContext_NETSUITE_DOES_NOT_ACCEPT_EMAIL_ADDRESSES_WITH_QUOTATION_MARKS_COMMAS_COLONS_SPACES_OR_GREATER_THAN_OR_LESS_THAN_SIGNS = "Please make sure there are no quotation marks, commas, colons, spaces, or greater than or less than signs.";
var NLAlertContext_PLEASE_ENTER_A_VALID_EMAIL_ADDRESS = "Please enter a valid email address.";
var NLValidationUtil_SIMPLE_EMAIL_PATTERN = /^[-a-zA-Z0-9!#$%&'*+/=?^_`{|}~]+(?:\.[-a-zA-Z0-9!#$%&'*+/=?^_`{|}~]+)*@(?:[a-zA-Z0-9]+(?:-+[a-zA-Z0-9]+)*\.)+(?:xn--[-a-zA-Z0-9]+|[a-zA-Z]{2,16})$/i;
var NLAlertContext_THE_SPECFIED_ROUTING_NUMBER_FAILED_VALIDATION_FOR_ABA_ROUTING_NUMBERS = "The specified routing number failed validation for ABA Routing Numbers.";
var NLAlertContext_ABA_ROUTING_NUMBERS_MUST_BE_NINE_CHARACTERS = "ABA Routing Numbers must be nine characters.";
/**
 * check if the value is empty
 * @param val String being tested for whether it is empty (null or "")
 */
function isValEmpty(val)
{
    if (val === null || val === undefined)
        return true;
    val = new String(val);
    return (val.length == 0) || !/\S/.test(val);
}

/**
 * isHTMLValEmpty() returns true if the given string is empty or contains only whitespace, ignoring HTML markup
 * @param val String being tested for whether it is empty (null or "")
 */
function isHTMLValEmpty(val)
{
    if (isValEmpty(val))
        return true;
    val = val.replace(/&nbsp;|<(?!NL)[^>]*>/gi, '');
    return !/\S/.test(val);
}

/* works just like the SQL NVL function */
function nvl(val,val2)
{
    return val == null ? val2 : val;
}
// emptyIfNull(): return empty string if vall is null.
function emptyIfNull(val)
{
    return val == null ? '' : val;
}
// nullIfEmpty(): return null if val is null or empty.
function nullIfEmpty(val)
{
    return isValEmpty(val) ? null : val;
}
/*
 * Trims leading and trailing whitespace from a string.
 * Similar to Java's String.trim(), see corresponding doc there.
 */
function trim(str)
{
    return str.replace(/^\s+/,"").replace(/\s+$/,"");
}
function onlydigitsandchars(str)
{
    var re = new RegExp("([A-Za-z0-9]+)");
    return (re.exec(str)!=null && RegExp.$1==str);
}
function onlydigits(str)
{
    return /^[0-9]+$/.test(str);
}

/**
 * returns true if the value is null, empty, or evaluates to a math equivalent value of zero.
 * @param fieldval String being tested for whether it is empty or zero
 */
function isemptyorzero(fieldval)
{
    var val = fieldval;
    var isempty = isValEmpty(val);
    var iszero = val==0;
    return (isempty || iszero);
}

/**
 * returns true if the value is null, empty, or evaluates to a math equivalent value of zero.
 * @param fieldval String being tested for whether it is empty or zero
 */
function isNewRecord()
{
	var id = typeof nlapiGetField != undefined && nlapiGetField("id") != null ? nlapiGetFieldValue("id") :
			 typeof document != undefined && document.forms['main_form'].elements['id'] != null ? document.forms['main_form'].elements['id'] : "";
	return isValEmpty(id) || id == -1
}
/**
 * returns true if the current record is an existing record
 */
function isExistingRecord()
{
    return !isNewRecord();
}
/**
 * returns true if the current record is an existing record
 */
function getEditFlag()
{
    return isExistingRecord();
}
/**
 * Perform mandatory field check
 *
 * @param fields	Array of field names or field references (UI)
 * @param labels  	Array of field labels
 * @param values	Array of field values (only used during dynamic scripting contexts)
 * @param type		Sublist name if this is called for a machine (current line on an edit machine)
 * @param returnArray If true, return the labels as array, otherwise as comma separated string
 */
function checkMandatoryFields(fields, labels, values, type, returnArray)
{
	var skipCheck = (type === 'item' && window.is_adding_multiple_items);
	var result = [];
	for (var i = 0; !skipCheck && i < fields.length; i++)
	{
		if (fields[i] == null)
			continue;
		var val = values != null ? values[i] : fields[i].value;
		if ((new String(val)).indexOf(String.fromCharCode(3)) != -1)
		{
			var nvarray = val.split(String.fromCharCode(4));
			for (var j = 0; j < nvarray.length; j++)
			{
				var nv = nvarray[j].split(String.fromCharCode(3));
				if (nv[1] == 'T' && nv[3].length == 0)
					result.push(nv[2]);
			}
			continue;
		}

		if (values != null)
		{
			if ((type != null && !Machine_isMandatoryOnThisLine(type, fields[i], nlapiGetCurrentLineItemIndex(type))) || (type == null && !nlapiGetFieldMandatory(fields[i])))
				continue;
			if (isValEmpty(val))
				result.push(labels[i]);
		}
		else
		{
			if (!getRequired(fields[i]))
				continue;

			if (isSelect(fields[i]) || isPopupSelect(fields[i]))
			{
				val = getSelectValue(fields[i]);
				if (isValEmpty(val))
					result.push(labels[i]);
			}
			else if (window.getHtmlEditor != null && getHtmlEditor(fields[i].name) != null)
			{
				if (isValEmpty(fields[i].value.replace("<DIV></DIV>", "")))
					result.push(labels[i]);
			}
			else
			{
				if (isempty(fields[i]))
					result.push(labels[i]);
			}
		}
	}
	if (returnArray) while (result[0] === '') result.shift(); // emulate faulty behavior of the legacy implementation
	return returnArray ? result : result.join(', ');
}

/**
 * Perform unique field validation on an edit machine (executed during validateLine)
 *
 * @param name			machine name
 * @param uniquefields	Array of field names for unique fields
 * @param uniquelabels	Array of field labels for unique fields
 *
 * @return An array of the unique field labels if there is a validation error or null
 */
function checkUniqueFields(name, uniquefields, uniquelabels)
{
	if ( uniquefields == null || uniquefields.length == 0 )
		return null;
	for (var i=1; i<= nlapiGetLineItemCount(name)+1; i++)
	{
		if (i == nlapiGetCurrentLineItemIndex(name)) continue;
		var bAllEmpty = true, bMatch = true;
		for (var j=0; j < uniquefields.length; j++)
		{
			var f = uniquefields[j];
			if (!isValEmpty(getEncodedValue(name,i,f))) bAllEmpty = false;
			if (getEncodedValue(name,i,f) != nlapiGetCurrentLineItemValue(name, uniquefields[j]))
			{
				bMatch = false;
				break;
			}
		}
		if (bAllEmpty || !bMatch) continue;
		var labels = new Array();
		for (var k=0; k < uniquefields.length; k++)
		{
			labels.push(uniquelabels[k]);
		}
		return labels;
	}
    return null;
}

// checkccnumber(): check if value in form fld is valid credit card. If this is called from the UI (i.e. webstore) then fld is a DOM field
//					reference. Otherwise it is a String containing the name of the field (use SuiteScript API for setting field)
//               NOTE: this is not a perfect check by any means. it does
//                  not check that amex is 15 and visa/other is 16. it also
//                  doesn't do the visa checksum.
//            	DJ11sep2000 -- I added code to do the luhn checksum check.
//				YF10Nov2008 -- moved to NLRecordUtil.js from NLUtil.js (please keep this in sync with NLValidationUtil.luhnCheck(s))
function checkccnumber(fld)
{
//  Remove all spaces and dashes.
//  you must check for length 0 up front. if you don't
//  mac ie5 will crashes on the replace call below.
	var cardnum = typeof(fld) != "string" ? fld.value : nlapiGetFieldValue(fld);	
	if(cardnum.length > 0) cardnum = cardnum.replace(/ /gi,'');
    if(cardnum.length > 0) cardnum = cardnum.replace(/-/gi,'');

    if (cardnum.length<13 || cardnum.length>20)
    {
        alert(NLAlertContext_CREDIT_CARD_NUMBERS_MUST_CONTAIN_BETWEEN_13_AND_20_DIGITS);
        return false;
    }
    if (!onlydigits(cardnum))
    {
        alert(NLAlertContext_CREDIT_CARD_NUMBERS_MUST_CONTAIN_ONLY_DIGITS);
        return false;
    }

    // Perform Luhn check
    // http://www.ling.nwu.edu/~sburke/pub/luhn_lib.pl
    var no_digit = cardnum.length;
    var oddoeven = no_digit & 1;
    var sum = 0;

    for (var count = 0; count < no_digit; count++)
    {
        var digit = parseInt(cardnum.charAt(count),10);
        if (!((count & 1) ^ oddoeven))
        {
            digit *= 2;
            if (digit > 9)
            digit -= 9;
        }
        sum += digit;
    }
    if (sum % 10 != 0)
    {
        alert(NLAlertContext_CREDIT_CARD_NUMBER_IS_NOT_VALID__PLEASE_CHECK_THAT_ALL_DIGITS_WERE_ENTERED_CORRECTLY);
        return false;
    }

	eval( typeof(fld) != "string" ? "fld.value = cardnum" : "nlapiSetFieldValue(fld, cardnum, false)" );
    return true;
}

/**
 * Set preferred fields following the addition of a new line on an edit machine (executed after validateLine but before recalc)
 *
 * @param name 	sublist name
 * @param preferredfield	preferred field name
 * @param linenum	line number being added
 */
function setPreferredFields(name, preferredfield, preferredwithinfield, linenum)
{
	if (getEncodedValue(name,linenum,preferredfield) == 'T')
	{
		for (var i=1; i <= getLineCount(name)+1; i++)
		{
			if (i != linenum && getEncodedValue(name,i,preferredfield) == 'T')
            {
                if(preferredwithinfield == null || getEncodedValue(name,linenum,preferredwithinfield) == getEncodedValue(name,i,preferredwithinfield))
                    setEncodedValue(name,i,preferredfield,'F');
            }
        }
	}
	return true;
}

function escapeJSONChar(c)
{
    if(c == "\"" || c == "\\") return "\\" + c;
    else if (c == "\b") return "\\b";
    else if (c == "\f") return "\\f";
    else if (c == "\n") return "\\n";
    else if (c == "\r") return "\\r";
    else if (c == "\t") return "\\t";
    var hex = c.charCodeAt(0).toString(16);
    if(hex.length == 1) return "\\u000" + hex;
    else if(hex.length == 2) return "\\u00" + hex;
    else if(hex.length == 3) return "\\u0" + hex;
    else return "\\u" + hex;
}

function escapeJSONString(s)
{
    /* The following should suffice but Safari's regex is b0rken
       (doesn't support callback substitutions)
       return "\"" + s.replace(/([^\u0020-\u007f]|[\\\"])/g,
       escapeJSONChar) + "\"";
    */

    /* Rather inefficient way to do it */
    var parts = s.split("");
    for(var i=0; i < parts.length; i++) {
	var c =parts[i];
	if(c == '"' ||
	   c == '\\' ||
	   c.charCodeAt(0) < 32 ||
	   c.charCodeAt(0) >= 128)
	    parts[i] = escapeJSONChar(parts[i]);
    }
    return "\"" + parts.join("") + "\"";
}
toJSON = function toJSON(o)
{
    if (o == null) // note: if o is undefined, this statement is true
		return "null";
    else if(o.constructor == String || o.constructor.name == "String")
		return escapeJSONString(o);
    else if(o.constructor == Number || o.constructor.name == "Number")
		return o.toString();
    else if(o.constructor == Boolean || o.constructor.name == "Boolean")
		return o.toString();
    else if(o.constructor == Date || o.constructor.name == "Date")
		return '{javaClass: "java.util.Date", time: ' + o.valueOf() +'}';
    else if(o.constructor == Array || o.constructor.name == "Array"  || o.length >= 0)
	{
	    var v = [];
	    for (var i = 0; i < o.length; i++) v.push(toJSON(o[i]));
	    return "[" + v.join(", ") + "]";
    }
	else
	{
		var v = [];
		for(attr in o)
		{
	        if(o[attr] == null) v.push("\"" + attr + "\": null");
	        else if(typeof o[attr] == "function"); /* skip */
	        else v.push(escapeJSONString(attr) + ": " + toJSON(o[attr]));
		}
		return "{" + v.join(", ") + "}";
    }
}
// Used to parse quantity price schedules
function getQtyRate(schedstr,qty,marginal)
{
    var sched = schedstr.split(String.fromCharCode(5));
    var i;
    var cum_amount=0;
    var rate;
    for (i=0;i < sched.length;i+=2)
    {
       if (qty >= parseFloat(sched[i]) && (i+2>=sched.length || qty < parseFloat(sched[i+2])))
       {
          if (marginal && qty>0)
          {
            cum_amount+=(qty-parseFloat(sched[i]))*parseFloat(sched[i+1]);
            rate=cum_amount/qty;
          }
          else
            rate=sched[i+1];
          break;
       }
       else if (marginal && qty > 0)
          cum_amount += (parseFloat(sched[i+2])-parseFloat(sched[i]))*parseFloat(sched[i+1]);
    }
    return rate;
}

function parseFloatOrZero(f)
{
   var r=parseFloat(f);
   return isNaN(r) ? 0 : r;
}

function isValidUSZipCode(value)
{
    var re = /^\d{5}([\-]\d{4})?$/;
    return (re.test(value));
}

function checkemail(email,emptyok,alrt)
{
    // mirrors Java's String.trim() - remove leading and trailing whitespace
    email = trim(email);
    return checkemail2(email,email,emptyok,alrt);
}

function checkemail2(email_1,email_2,emptyok,alrt)
{
    var s_email = email_1;

    if (s_email != email_2)
    {
        alert(NLAlertContext_EMAIL_ADDRESSES_MUST_MATCH);
        return false;
    }
    if (emptyok && s_email.length==0)
    {
        return true;
    }
    return checkemailvalue(s_email,alrt);
}

function checkemailvalue(s_email,alrt)
{
	alrt = true;
	if (/\s|[,":<>]/.test(s_email))
	{
		if (alrt)
		{
			alert(NLAlertContext_PLEASE_ENTER_A_VALID_EMAIL_ADDRESS
					+ " " + NLAlertContext_NETSUITE_DOES_NOT_ACCEPT_EMAIL_ADDRESSES_WITH_QUOTATION_MARKS_COMMAS_COLONS_SPACES_OR_GREATER_THAN_OR_LESS_THAN_SIGNS);
		}
		return false;
	}

	if (!NLValidationUtil_SIMPLE_EMAIL_PATTERN.test(s_email))
	{
		if (alrt)
		{
			alert(s_email + ' ' + NLAlertContext_PLEASE_ENTER_A_VALID_EMAIL_ADDRESS);
		}
		return false;
	}

	return true;
}

function checkemailprefix(s_email)
{
	/*
	Return true if string appears to be an email prefix (eg. wbailey@netl).  Used by uber search.
	- Must have exactly one '@' preceded by one or more chars
	- Must not contain any of these chars: <space> , " : < >
	- Must not contain ".."
	NOTE: This is a rudimentary check, not full email validation. It can be upgraded to full validation by
	reusing logic from checkemailvalue().
	*/
	return /^[^@]+@[^@]*$/.test(s_email) && !/\s|[,":<>]|[.][.]/.test(s_email);
}


// checknotempty(): validate that field is not empty and return focus to offending field. %>
function checkvalnotempty(val,alertMessage)
{
	if (isValEmpty(val))
	{
		if (alertMessage)
		{
			alert(alertMessage);
		}
        return false;
    }
    return true;
}

function checkpassword(pwd1,pwd2,alrt,strictcheck,prevpwd,len,email)
{
    var strict = (strictcheck == true || strictcheck == null);
    var msg = getpassworderror(pwd1,pwd2,strict,prevpwd,len,email);
    if (msg != null)
    {
        if (alrt) alert(msg);
        return false;
    }
    else
        return true;
}

function getpassworderror(pwd1,pwd2,strictcheck,prevpwd,len,email)
{
    var strict = (strictcheck == true || strictcheck == null);
    var val = pwd1;
    if (len == null)
        len = 6;
    msg = "";

    if (pwd1 != pwd2)
    {
        msg += NLAlertContext_PASSWORDS_DONT_MATCHN;
    }
    else if (!strict)
    {
        if (val.length == 0)
            msg = NLAlertContext_PASSWORDS_CANNOT_BE_EMPTYN;
    }
    else
    {
        if (val.length < len)
        {
            msg += NLAlertContext_PASSWORDS_MUST_BE_AT_LEAST_1_CHARACTERS_LONGN.replace("{1}", String(len));
        }
        if (!/[A-Za-z]/.test(val))
        {
            msg += NLAlertContext_PASSWORDS_MUST_CONTAIN_AT_LEAST_ONE_LETTER_AZN;
        }
        if (!/[0-9!@#$%^&*.:;~'`*",_|= \<\>\/\\\+\?\-\(\)\[\]\{\}]/.test(val))
        {
            msg += NLAlertContext_PASSWORDS_MUST_CONTAIN_AT_LEAST_ONE_NUMBER_OR_SPECIAL_CHARACTERN;
        }
        if (!/^[A-Za-z0-9!@#$%^&*.:;~'`*",_|= \<\>\/\\\+\?\-\(\)\[\]\{\}]+$/.test(val))
        {
            msg += NLAlertContext_PASSWORDS_MAY_CONTAIN_ONLY_LETTERS_NUMBERS_AND_SPECIAL_CHARACTERSN;
        }
    }
    if (msg.length == 0 && prevpwd != null)
    {
        var oldval = prevpwd;
        var charDiffCount = 0;
        for (var i=0;i < val.length; i++)
        {
            var c = val.charAt(i);
            if (oldval.indexOf(c) == -1)
                charDiffCount++;
        }
        if (charDiffCount < 2)
            msg = NLAlertContext_OLD_AND_NEW_PASSWORDS_ARE_TOO_SIMILAR;
    }
	if (msg.length == 0 && email != null)
	{
		if (email == pwd1)
			msg = NLAlertContext_PASSWORD_MUST_NOT_BE_THE_SAME_AS_THE_EMAIL_ADDRESS;
	}
	if (msg.length > 0)
        return msg;
    else
        return null;
}

function validate_AbaRoutingNumber(routing)
{
	if (routing == null || routing.length == 0)
    {
        NS.form.setValid(true);
        return true;
    }
	var maxlen = 9;
	var validflag = true;
    var err = '';
    if (routing.length != maxlen)
    {
        err = NLAlertContext_ABA_ROUTING_NUMBERS_MUST_BE_NINE_CHARACTERS;
        validflag = false
    }
	var t = routing;
	var n = 0;
    for (i = 0; i < t.length; i += 3)
    {
        n += parseInt(t.charAt(i), 10) * 3 + parseInt(t.charAt(i + 1), 10) * 7 +  parseInt(t.charAt(i + 2), 10);
    }

	if (n != 0 && n % 10 == 0)
	{
        validflag = true;
	}
	else
	{
		err = NLAlertContext_THE_SPECFIED_ROUTING_NUMBER_FAILED_VALIDATION_FOR_ABA_ROUTING_NUMBERS +"("+routing+")";
        validflag = false;
	}


    if (err != '')
    {
		alert(err);
    }
    NS.form.setValid(validflag);
    return validflag;
}

//check if a character has Chinese/Japanese/Korean characters
function stringContainsCJKChar(str)
{
   if(str == null || str.length == 0)
      return false;
   var cjk = false;
   for (var i=0; i<str.length; i++)
   {
     var charcode = str.charCodeAt(i);
     if( (charcode >= 12352 && charcode <= 40959) || (charcode >= 44032 && charcode <= 55215))
     {
       cjk = true;
       break;
     }
   }
   return cjk;
}



function getEventKeypress(evnt)
{
    evnt = getEvent(evnt);

    return (evnt.which) ? evnt.which : evnt.keyCode;

}

function getEventMacCommandKey(evnt)
{
	
		return false;
	
}


/* Miscellaneous functions */
function dispatchFieldChanged(sublistName, fieldName, lineNum)
{
	NS.event.dispatchImmediate(NS.event.type.RECORD_FIELD_CHANGED, {sublistName:sublistName, fieldName:fieldName, linenum:lineNum});
}

function nsapiIsString(obj)
{
    return typeof obj === 'string' || obj instanceof String || nsapiInstanceOf(obj, 'String');
}
function nsapiInstanceOf(obj, typeName)
{
	if (typeof obj === 'undefined' || obj === null)
		return false;
	var rep = Object.prototype.toString.call(obj);
	if (rep.slice(8, -1) === typeName)
		return true;
	if (typeof obj.constructor === 'undefined')
		return false;
	if (typeof obj.constructor.name !== 'undefined')
		return obj.constructor.name === typeName;
	var m = /^function ([^( ]+)/.exec(obj.constructor.toString());
	return !!(m && m[1] == typeName);
}
/* Array utilities */
function arrayIndexOf(array, val, ignorecase)
{
    for ( var i = 0; array != null && i < array.length; i++ )
        if ( val == array[i] || (ignorecase && val != null && array[i] != null && val.toLowerCase() == array[i].toLowerCase()) )
            return i;
    return -1;
}
function arrayContains(array, val)
{
    return arrayIndexOf(array, val) >= 0;
}
function arrayAdd(array, val)
{
    if ( !arrayContains(array, val) )
        array.push(val);
}
function arrayRemove(array, val)
{
    var newarray = new Array();
    for ( var i = 0; i < array.length; i++ )
        if ( val != array[i] )
            newarray.push(array[i]);
    return newarray;
}
function getArrayIntersection(array1, array2)
{
    var resultArray = new Array();
    for (var i = 0; i < array1.length; i++)
    {
        for (var j = 0; j < array2.length; j++)
        {
            if (array1[i] == array2[j])
            {
                resultArray[resultArray.length] = array1[i];
                array2[j] = null;
                break;
            }
        }
    }
    return resultArray;
}
function isArray(obj)
{
	return obj instanceof Array || nsapiInstanceOf(obj, 'Array');
}
function nsapiEveryElementIs(array, pred)
{
    if (!isArray(array))
        return false;
    for (var i=0; i<array.length; ++i)
    {
        if (!pred(array[i]))
            return false;
    }
    return true;
}
function nsapiMap(array, func)
{
	var result = [];
	for (var i=0; i<array.length; ++i)
	{
		result.push(func(array[i]));
	}
	return result;
}
/* Search filter expression functions */
function nsapiIsSearchFilterExpression(array)
{
    return nsapiEveryElementIs(array, nsapiIsSearchFilterTerm);
}
function nsapiIsFlatSearchFilterList(array)
{
    return nsapiEveryElementIs(array, nsapiIsSearchFilterObject);
}
function nsapiIsSearchFilterTerm(obj)
{
    if (typeof obj === 'undefined' || !obj)
        return false;
    if (nsapiIsString(obj))
        return /not|and|or/i.test(obj);
    if (nsapiIsSearchFilterArray(obj))
        return true;
    return nsapiIsSearchFilterExpression(obj);
}
function nsapiNormalizeFilters(filters)
{
	return nsapiIsSearchFilter(filters) ? [filters] : (typeof filters === 'undefined' ? null : filters);
}
function nsapiIsSearchFilter(obj)
{
	return nsapiIsSearchFilterObject(obj) || nsapiIsSearchFilterArray(obj);
}
function nsapiIsSearchFilterObject(obj)
{
	return obj instanceof nlobjSearchFilter || nsapiInstanceOf(obj, 'nlobjSearchFilter');
}
function nsapiIsSearchFilterArray(arr)
{
	return isArray(arr) && arr.length >= 3 && nsapiIsString(arr[0]) && nsapiIsString(arr[1]) && !/^not$/i.test(arr[0]);
}
function nsapiCheckSearchFilterExpression(arrayObj, name)
{
    nsapiAssertTrue(arrayObj === null || nsapiIsSearchFilterExpression(arrayObj), 'SSS_INVALID_SRCH_FILTER_EXPR_OBJ_TYPE', name);
}
function nsapiCheckSearchFilterListOrExpression(arrayObj, name)
{
    nsapiAssertTrue(arrayObj === null || nsapiIsFlatSearchFilterList(arrayObj) || nsapiIsSearchFilterExpression(arrayObj), 'SSS_INVALID_SRCH_FILTER_EXPR_OBJ_TYPE', name);
}

// Given a translation string containing zero or more parameter strings, and zero or more comment strings, remove them
// and replace parameter strings with corresponding parameters passed into this function.
// - Although it looks like this function takes one argument, it takes an arbitrary number.
//   Example: format_message("Is Not {1:boolean value}", "True").
// - This function also handles choice formats starting with @@@, e.g. "@@@is {1:value} || is not {1:value}". In that
//   case the selector is the first parameter.
// - In addition to separate param args, all param args can be passed in in an array. In this case, the selector
//   is still separate from the other parameters. Example: format_message("Day {1:dom} of {2:month}", [ 4, 'June' ]).
function format_message(pattern)
{
	var len = format_message.arguments.length;
	var offset = 1;

	// Handle choice formats (not the real ones; just simple NetSuite-style choice formats).
	if (pattern.length >= 3 && pattern.substring(0, 3) == '@@@')
	{
		var choicePatterns = pattern.substring(3).split(/\s*\|\|\s*/);
		var selector = 0;
		if (len >= 2)
		{
			selector = format_message.arguments[1];
			if (typeof(selector) == 'boolean')
				selector = selector ? 0 : 1;
			else if (typeof(selector) == 'string')
				selector = parseInt(selector);
			if (typeof(selector) != 'number')
				selector = 0;
		}
		if (selector >= choicePatterns.length)
			selector = 0;
		pattern = choicePatterns[selector];

		offset = 2;
	}

	else if (pattern.length >= 2 && pattern.substring(0, 2) == '@@')
	{
		// No good solution here -- this method doesn't support native JDK formats with nested ChoiceFormat patterns.
		return '?';
	}

	// Allow passing in a single array of all arguments. This does NOT include the selector, if there is one.
	var params = format_message.arguments;
	if (len == (offset + 1) && format_message.arguments[offset].constructor == Array)
	{
		params = format_message.arguments[offset];
		offset = 0;
		len = params.length;
	}

	return pattern.replace(/{(?:(\d+)|:)[^}]*}/g,
		function(match, id)
		{
			var n = id ? (parseInt(id) - 1 + offset) : len;
			return (n < len) ? params[n] : ''
		});
}

function checkIsNotNegativeTime(field)
{
    var valid = true;
    if (field.value != null && field.value.match(/^\s*-/)) {
        alert('Invalid: Please enter a number greater than or equal to 0.');
        valid = false;
    }

    NS.form.setValid(valid);
    return valid;
}

function extract_date_time(str)
{
    var tmp_str = trim(str);
    var spaceIdx = getTimeStartIdx(str);
    if (spaceIdx > 0) {
        var date_str = tmp_str.substring(0, spaceIdx);
        var time_str = tmp_str.substring(spaceIdx+1, tmp_str.length);
        return { validflag:true, date:date_str, time: trim(time_str)};
    } else {
        alert("Invalid date/time (miss spaces between date and time)");
	}
    return { validflag:false };
}


    //Function to show field in the form.
//  on base of the name of element, call display function
//  display for element and parent element
function showField ( spanId, on )
{
	var spanInput = document.getElementById(spanId);
	display(spanInput, on );

	var elem = !!NS && !!NS.UI && !!NS.UI.Helpers && !!NS.UI.Helpers.getClosestAncestorFromClass &&
		NS.UI.Helpers.getClosestAncestorFromClass(document.getElementById(spanId), 'uir-field-wrapper');

	if (on && elem) {
		display(elem, on);
	}

	if (spanInput != null) {
		var parent = spanInput.parentNode;
		if(parent.nodeName == "LI" || (parent.nodeName == "TD" && parent.style.height == "22px"))
			display(parent, on);
	}
}

//Function to display or hide element
function display(elem, on )
{
	if (elem != null)
		elem.style.display = on ? '' : 'none';
}

function isNLNumericOrCurrencyFieldRequired(fld)
{
	var displayField = getNLNumericOrCurrencyDisplayField(fld);
	if (!displayField)
		return false;
	return isRequiredFieldClassName(displayField);
}

function setNLNumericOrCurrencyFieldRequired(fld, required)
{
	var displayField = getNLNumericOrCurrencyDisplayField(fld);
	if (!displayField)
		return false;
	return doSetRequired(displayField, fld.name, required);
}

/**
 *  NOTE:  if the field does not have the flag NLField.MANDATORY or NLField.POTENTIALLY_MANDATORY
 *  set, the mandatory style will be displayed on the form,
 *  but the validation alert will NOT occur on submit action.
 */
function setRequired(fld,required)
{
	if ( isNLDropDown(fld))
		getDropdown(fld).setRequired(required);
	else if ( isNLMultiDropDown( fld ) )
		getMultiDropdown(fld).setRequired(required);
	else if ( window.getHtmlEditor != null && getHtmlEditor( fld.name ) != null && getHtmlEditor(fld.name).setMandatory)
		getHtmlEditor( fld.name ).setMandatory( required );
	else if ( fld.form != null && fld.form.elements[fld.name+"_display"] != null )
	{
		if (typeof fld.form.elements[fld.name+"_display"].className == "undefined")
			fld.form.elements[fld.name+"_display"].className = "";
		var className = fld.form.elements[fld.name+"_display"].className;
		var fromClassName = (getRequired(fld) ? 'inputreq' : 'input');
		var toClassName = (required ? 'inputreq' : 'input');
		if (className.indexOf(fromClassName) < 0)
			className = toClassName + " " + className;
		else
			className = className.replace(fromClassName, toClassName);
		fld.form.elements[fld.name+"_display"].className = className;
		setFieldLabelRequired(fld.id, required);
	}
	else if (isNumericField(fld) || isCurrencyField(fld))
		return setNLNumericOrCurrencyFieldRequired(fld, required);
	else
		doSetRequired(fld, fld.id, required);
}

// internal method, do not call directly
function doSetRequired(fld, fldName, required)
{
	if (typeof fld.className == "undefined")
		fld.className = "";
	var className = fld.className;
	var alignRight = (className.indexOf('inputrt') >= 0);
	var fromClassName = 'input' + (alignRight ? 'rt' : '') + (getRequired(fld) ? 'req' : '');
	var toClassName = 'input' + (alignRight ? 'rt' : '') + (required ? 'req' : '');
	if (className.indexOf(fromClassName) < 0)
		className = toClassName + " " + className;
	else
		className = className.replace(fromClassName, toClassName);
	fld.className= className;
	if(fld.machine != undefined) {
		fldName = fld.machine.name + "_" + fldName;
	}
	setFieldLabelRequired(fldName, required);
}

//In 2010.2, the field label have an asterisk to indicate required field.
function setFieldLabelRequired(fldName, required, fldForm)
{
	if (fldName)
	{
		fldName = fldName.replace('inpt_', '');
		fldName = fldName.replace('hddn_', '');
		fldName = fldName.replace('_fs', '');

		var label = document.getElementById(fldName + '_fs_lbl');

		if (label)
		{
			// Only add the asterisk to the first child label
			if ((label.parentNode && label.parentNode.firstChild !== label) || (label.className && label.className.indexOf('uir-label-no-required-flag') !== -1)) {
				return;
			}

			// If I have a form object make sure that the label form and input form is the same.
			if (fldForm)
			{
				var labelForm = getParentElementByTag("form", label);
				if (labelForm && labelForm != fldForm)
				{
					return;
				}
			}

			var labels = label.getElementsByTagName("label");
			var asteriskLabel;
			for (var i = 0; i < labels.length; i++)
			{
				if (labels[i].className == 'uir-required-icon')
				{
					asteriskLabel = labels[i];
					break;
				}
			}

			if (required && !asteriskLabel)
			{
				asteriskLabel = document.createElement('label');
				asteriskLabel.className = 'uir-required-icon';
				asteriskLabel.textContent = '*';

				if (NS && NS.UI && NS.UI.Preferences && NS.UI.Preferences.horizontalLabelsEnabled)
				{
					label.insertBefore(asteriskLabel, label.firstChild);
				}
				else
				{
					label.appendChild(asteriskLabel);
				}
			}
			else if (!required && asteriskLabel)
			{
				label.removeChild(asteriskLabel);
			}
		}
	}
}

function getRequired(fld)
{
	if ( isNLDropDown(fld) )
		return getDropdown(fld).getRequired( );
	else if ( isNLMultiDropDown( fld ) )
		return getMultiDropdown(fld).getRequired( );
	else if ( window.getHtmlEditor != null && getHtmlEditor( fld.name ) )
		return getHtmlEditor( fld.name ).getMandatory( );
	else if ( fld.form != null && fld.form.elements[fld.name+"_display"] != null )
		return fld.form.elements[fld.name+"_display"].className != null && fld.form.elements[fld.name+"_display"].className.indexOf('inputreq') != -1;
	else if ( (isNumericField(fld) || isCurrencyField(fld)) && fld.name.indexOf("_formattedValue")==-1)
		return isNLNumericOrCurrencyFieldRequired(fld);
	else
		return isRequiredFieldClassName(fld);
}

function isRequiredFieldClassName(fld)
{
	return fld.className != null && (fld.className.indexOf('inputreq') != -1 || fld.className.indexOf('inputrtreq') != -1);
}

function disableSelect(sel, val, win)
{
	if (!isBackend && (sel != null))
	{
		var doc = win != null ? win.document : sel.document != null ? sel.document : window.document;
		if (sel.type == "select-one" || sel.type == "select-multiple")
			sel.disabled = val;
		else if (isNLDropDown(sel))
			getDropdown(sel, win).setDisabled(val);
		else if (isNLMultiDropDown(sel))
			getMultiDropdown(sel, win).setDisabled(val);
		else
		{
			var displaytext = sel.form.elements[sel.name+"_display"];
			if (displaytext != null)
				displaytext.disabled=val;
			var listlink = doc.getElementById(sel.name+"_popup_list");
			if (listlink != null)
				listlink.style.visibility = val ? "hidden" : "inherit";
			var searchlink = doc.getElementById(sel.name+"_popup_search");
			if (searchlink != null)
				searchlink.style.visibility = val ? "hidden" : "inherit";
			var alllink = doc.getElementById(sel.name+"_popup_all");
			if (alllink != null)
				alllink.style.visibility = val ? "hidden" : "inherit";
		}
		var newlink = doc.getElementById(sel.name+"_popup_new");
		if (newlink != null)
			newlink.style.visibility = val ? "hidden" : "inherit";
		var linklink = doc.getElementById(sel.name+"_popup_link");
		if (linklink != null)
			linklink.style.visibility = val ? "hidden" : "inherit";
		if(val) {
			if(sel.className.indexOf('uir-disabled') == -1){
				sel.className += ' uir-disabled';
			}
		} else {
			sel.className = sel.className.replace('uir-disabled','');
		}
	}
}

function updateFieldEditabilityFlags(fld, flag, val)
{
	// default implementation does nothing, but is overriden for SP2
}

function previewMedia(mediaid, bIsHref, document)
{
	if (bIsHref)
		mediaid = mediaid.substr(mediaid.lastIndexOf('/')+1);
	var url = '/core/media/previewmedia.nl?id='+mediaid;
	preview(url, 'prevmedia');
}

function preview(url, winname)
{
	var prms = 'location=no,width=600,height=500,menubar=yes,scrollbars=yes,resizable=yes';
	var win = window.open(url, winname, prms);
	win.focus();
}


function setOldToNewUIHandshake(win, deferred)
{
	if (win.egdirb) {
		if (win.egdirb.mainFormContext) {
			deferred.resolve({mainFormContext: win.egdirb.mainFormContext});
		} else {
			deferred.reject();

		}
	} else {
		win.egdirb = {
			handshake: {
				resolve: deferred.resolve,
				reject: deferred.reject
			}
		}
	}
}


function nlGetNewUIIframe(url)
{
	var deferred = NS.jQuery.Deferred();
	var iframe = document.createElement('IFRAME');
	iframe.src = url;
	iframe.onload = function() {setOldToNewUIHandshake(iframe.contentWindow, deferred)};

	return {
		iframe: iframe,
		deferred: deferred
	};
}


function nlExtOpenNewUIWindow(args)
{
	var deferred = NS.jQuery.Deferred();
	var extListeners = args.listeners || {};
	extListeners.afterrender = function() {
		setOldToNewUIHandshake(this.body.dom.contentWindow, deferred)
	};

	nlExtOpenWindow(args.url, args.winname, args.width, args.height, args.fld, args.scrollbars, args.winTitle, extListeners, args.triggerObj);

	return deferred;
}


function nlExtOpenWindow(url, winname, width, height, fld, scrollbars, winTitle, listeners, triggerObj)
{
	//TODO: is the following needed for this style of popup?
	url = addParamToURL (url, "ifrmcntnr", "T", true );

	if (!listeners)
		listeners = {};

	if ( window.doPageLogging ) // onunload and onbeforeunload events don't fire for popup requests. This is required in order to track end-to-end time
		logStartOfRequest( 'extpopup' );

	var xPos = null;
	var yPos = null;

	if (triggerObj != null && typeof triggerObj != 'undefined')
	{
		xPos = findPosX(triggerObj);
		yPos = findPosY(triggerObj);
	}

	var extWindow = new Ext.Window({
		title: (winTitle != undefined ? winTitle : winname),
		id: winname,
		name: winname,
		stateful: false,
		modal: true,
		autoScroll: scrollbars,
		width: parseInt(''+width) + 20,
		height: parseInt(''+height) + 30,
		style: 'background-color: #FFFFFF;',
		bodyStyle: 'background-color: #FFFFFF;',
		resizable: true,
		listeners : listeners,
		constrainHeader: true,
		bodyCfg: {
			tag: 'iframe',
			name: winname+'_frame',
			id: winname+'_frame',
			src: url,
			width: (width+4)+'px',
			height: height+'px',
			style: 'border: 0 none; background-color: #FFFFFF;'
		}
	});

	if ((!isValEmpty(xPos))&&(!isValEmpty(yPos)))
	{
		extWindow.x = xPos;
		extWindow.y = yPos;
	}

	extWindow.show();
	extWindow.syncSize();

	return extWindow;

}


function validateRescheduleDate(dateString, input) {
    if (validate_date(dateString, false).validflag === false)
    {
        alert("Invalid reschedule date");
        window.setTimeout(function () {
            input.select();
            input.focus();
            input.scrollIntoView();
        }, 0);
    }
}
