




function getShippingRateFromServer(xmlStr, isPackagesReload)
{
	try
    {
		Shipping.hideShipRateErrorAlert();
		var serverXmlStr = makeShippingRateCall(xmlStr);
    }
    catch(e)
    {
	    Shipping.showShipRateErrorAlert(e);
        return;
    }

	var serverXml = nlapiStringToXML(serverXmlStr);

	if (isPackagesReload)
	{
		var pkgsXml = ratingSelectNodes(serverXml, "/PackagesResponse/Packages/Package");
		if (pkgsXml != null)
		{
			var pkgsXmlErrorNode = ratingSelectNode(serverXml, "/PackagesResponse/Error");
			if (pkgsXmlErrorNode != null)
			{
				var errorMsg = getXMLValue(pkgsXmlErrorNode, "ErrorMessage", '');
				reloadPackagesError(errorMsg);
			}
			else
			{
				var packages = new Array(pkgsXml.length);
				for (var i = 0; i < pkgsXml.length; i++)
				{
					var pkg = new Array(7);
					pkg[0] = getXMLValue(pkgsXml[i], "CustomType", '');
					pkg[1] = getXMLValue(pkgsXml[i], "Weight", '');
					pkg[2] = getXMLValue(pkgsXml[i], "Length", '');
					pkg[3] = getXMLValue(pkgsXml[i], "Width", '');
					pkg[4] = getXMLValue(pkgsXml[i], "Height", '');
					pkg[5] = getXMLValue(pkgsXml[i], "Value", '');
					pkg[6] = getXMLValue(pkgsXml[i], "PackagingType", '');
					pkg[7] = getXMLValue(pkgsXml[i], "AmountWithTaxes", '');

					packages[i] = pkg;
				}
				reloadPackages(packages);
			}
		}
	}
	else
	{
		var shipmentsXml = ratingSelectNodes(serverXml, "/RatesResponse/Shipments/Shipment");
		if (shipmentsXml != null)
		{
			var shipments = new Array(shipmentsXml.length);
			for (var i = 0; i < shipmentsXml.length; i++)
			{
				var shipment = {};
				shipment['GroupId'] = getXMLValue(shipmentsXml[i], 'GroupId', 0);
				shipment['GroupWeight'] = getXMLValue(shipmentsXml[i], 'GroupWeight', 0);
				shipment['SrcAddress'] = getXMLValue(shipmentsXml[i], 'SrcAddress', '');
				shipment['DestAddress'] = getXMLValue(shipmentsXml[i], 'DestAddress', '');
				shipment['ShippingCarrier'] = getXMLValue(shipmentsXml[i], 'ShippingCarrier', '');
				shipment['ShippingMethod'] = getXMLValue(shipmentsXml[i], 'ShippingMethod', '');
				shipment['ShippingRate'] = getXMLValue(shipmentsXml[i], 'ShippingRate', 0.00);
				shipment['IsShippingTaxable'] = getXMLValue(shipmentsXml[i], 'IsShippingTaxable', 'F');
				shipment['HasHandlingAcct'] = getXMLValue(shipmentsXml[i], 'HasHandlingAcct', 'F');
				shipment['HandlingRate'] = getXMLValue(shipmentsXml[i], 'HandlingRate', 0.00);
				shipment['IsHandlingTaxable'] = getXMLValue(shipmentsXml[i], 'IsHandlingTaxable', 'F');
				shipment['TaxItem'] = getXMLValue(shipmentsXml[i], 'TaxItem', 0);
				shipment['TaxItemLabel'] = getXMLValue(shipmentsXml[i], 'TaxItemLabel', '');
				shipment['TaxItemRate'] = getXMLValue(shipmentsXml[i], 'TaxItemRate', 0);
				shipment['TaxItemRate2'] = getXMLValue(shipmentsXml[i], 'TaxItemRate2', 0);
				shipment['HandlingTaxItem'] = getXMLValue(shipmentsXml[i], 'HandlingTaxItem', 0);
				shipment['HandlingTaxItemLabel'] = getXMLValue(shipmentsXml[i], 'HandlingTaxItemLabel', '');
				shipment['HandlingTaxItemRate'] = getXMLValue(shipmentsXml[i], 'HandlingTaxItemRate', 0);
				shipment['HandlingTaxItemRate2'] = getXMLValue(shipmentsXml[i], 'HandlingTaxItemRate2', 0);
				shipment['ErrorMessage'] = getXMLValue(shipmentsXml[i], 'ErrorMessage', '');
				shipment['SrcAddressKey'] = getXMLValue(shipmentsXml[i], 'SrcAddressKey', '');
				shipment['DestAddressKey'] = getXMLValue(shipmentsXml[i], 'DestAddressKey', '');
				shipment['ShippingMethodKey'] = getXMLValue(shipmentsXml[i], 'ShippingMethodKey', '');
				shipments[i] = shipment;
			}
		}
		displayShippingItemRate(shipments);
	}
}

function createRatesRequestXml(requestSrc, ratesCarrier, entityId, destCity, destState, destZip, destCountry, shipMethod, salesOrderId, isResidential, isThirdPartyAcct, thirdPartyCarrier, isPackagesReload, currency, tranFxRate, subsidiary, bIsItemLineRates, testId, nexusId, packages, items, isDefaultRequest, overrideShippingCost, isDynamicScriptingRequest, shipmentParameters)
{
	var ratesReqXml = '<RatesRequest>';
	ratesReqXml += createXMLElement('RequestSrc', requestSrc);
	ratesReqXml += createXMLElement('RatesCarrier', ratesCarrier);
	ratesReqXml += createXMLElement('EntityId', entityId);
	ratesReqXml += createXMLElement('IsItemLineRates', bIsItemLineRates);
	ratesReqXml += createXMLElement('DestCity', destCity);
	ratesReqXml += createXMLElement('DestState', destState);
	ratesReqXml += createXMLElement('DestZip', destZip);
	ratesReqXml += createXMLElement('DestCountry', destCountry);
	ratesReqXml += createXMLElement('ShipMethod', shipMethod);
	ratesReqXml += createXMLElement('SalesOrderId', salesOrderId);
	ratesReqXml += createXMLElement('IsResidential', isResidential);
	ratesReqXml += createXMLElement('IsThirdPartyAcct', isThirdPartyAcct);
	ratesReqXml += createXMLElement('ThirdPartyCarrier', thirdPartyCarrier);
	ratesReqXml += createXMLElement('IsPackagesReload', isPackagesReload);
	ratesReqXml += createXMLElement('IsDefaultRequest', isDefaultRequest);
	ratesReqXml += createXMLElement('Currency', currency);
	ratesReqXml += createXMLElement('TransactionFxRate', tranFxRate);
	ratesReqXml += createXMLElement('Subsidiary', subsidiary);
	ratesReqXml += createXMLElement('TestId', testId);
	ratesReqXml += createXMLElement('NexusId', nexusId);
	ratesReqXml += createXMLElement('OverrideShippingCost',overrideShippingCost);
	ratesReqXml += createXMLElement('IsDynamicScriptingRequest',isDynamicScriptingRequest);
    ratesReqXml += getAdditionalShipmentXML(shipmentParameters);
	ratesReqXml += getPackagesXML(packages);
	ratesReqXml += getItemsXML(items);
	ratesReqXml += '</RatesRequest>';
	return ratesReqXml;
}

function createXMLElement(nodeName, nodeValue)
{
    if (!isValEmpty(nodeValue)) {return ('<' + nodeName + '>' + nlapiEscapeXML(nodeValue) + '</' + nodeName + '>');} else {return '<' + nodeName + '/>';}
}

function getAdditionalShipmentXML(parameters)
{
    var result = '';
    if (parameters != null)
    {
        for (var paramKey in parameters)
        {
            result += createXMLElement(paramKey, parameters[paramKey]);
        }
    }

    return result;
}

function getPackagesXML(packages)
{
	var packagesXml = '<Packages>';
	if (packages != null && packages.length > 0)
	{
		for (var i = 0; i < packages.length; i++)
		{
			var pkg = packages[i];
			if (pkg != null && pkg != undefined)
			{
				packagesXml += '<Package>';
				packagesXml += createXMLElement('PackageNumber', pkg['PackageNumber']);
				packagesXml += createXMLElement('PackageLength', pkg['PackageLength']);
				packagesXml += createXMLElement('PackageWidth', pkg['PackageWidth']);
				packagesXml += createXMLElement('PackageHeight', pkg['PackageHeight']);
				packagesXml += createXMLElement('PackageWeight', pkg['PackageWeight']);
				packagesXml += createXMLElement('PackageType', pkg['PackageType']);
				packagesXml += createXMLElement('PackageInsuredValue', pkg['PackageInsuredValue']);
				packagesXml += createXMLElement('PackageSignatureOption', pkg['PackageSignatureOption']);
				packagesXml += createXMLElement('AdditionalHandling', pkg['AdditionalHandling']);
				packagesXml += createXMLElement('UseCOD', pkg['UseCOD']);
				packagesXml += createXMLElement('CODAmount', pkg['CODAmount']);
				packagesXml += createXMLElement('CODMethod', pkg['CODMethod']);
				packagesXml += createXMLElement('DeliveryConfirmation', pkg['DeliveryConfirmation']);
                packagesXml += createXMLElement('DryIceWeight', pkg['DryIceWeight']);
                packagesXml += createXMLElement('DryIceUnit', pkg['DryIceUnit']);
                packagesXml += createXMLElement('CODTransportationCharges', pkg['CODTransportationCharges']);
                packagesXml += createXMLElement('CODOtherCharge', pkg['CODOtherCharge']);
				packagesXml += '</Package>';
			}
		}
	}
	packagesXml += '</Packages>';
	return packagesXml;
}

function getItemsXML(items)
{
	var itemsXml = '<Items>';
	if (items != null && items.length > 0)
	{
		for (var i = 0; i < items.length; i++)
		{
			var item = items[i];
			if (item != null && item != undefined)
			{
				itemsXml += '<Item>';
				itemsXml += createXMLElement('ItemQuantity', item['ItemQuantity']);
				itemsXml += createXMLElement('ItemAmount', item['ItemAmount']);
				itemsXml += createXMLElement('ItemWeight', item['ItemWeight']);
				itemsXml += createXMLElement('ItemKey', item['ItemKey']);
				itemsXml += createXMLElement('ItemLocation', item['ItemLocation']);
				itemsXml += createXMLElement('ItemUnits', item['ItemUnits']);
				itemsXml += createXMLElement('ItemType', item['ItemType']);
				itemsXml += createXMLElement('ItemExcludeFromRateRequest', item['ItemExcludeFromRateRequest']);
				itemsXml += createXMLElement('ItemShipAddrKey', item['ItemShipAddrKey']);
				itemsXml += createXMLElement('ItemShipAddr1', item['ItemShipAddr1']);
				itemsXml += createXMLElement('ItemShipAddr2', item['ItemShipAddr2']);
				itemsXml += createXMLElement('ItemShipCity', item['ItemShipCity']);
				itemsXml += createXMLElement('ItemShipState', item['ItemShipState']);
				itemsXml += createXMLElement('ItemShipZip', item['ItemShipZip']);
				itemsXml += createXMLElement('ItemShipCountry', item['ItemShipCountry']);
				itemsXml += createXMLElement('ItemShipIsResidential', item['ItemShipIsResidential']);
				itemsXml += createXMLElement('ItemShipMethKey', item['ItemShipMethKey']);
                itemsXml += createXMLElement('ItemName', item['ItemName']);
                itemsXml += createXMLElement('ItemDescription', item['ItemDescription']);
                itemsXml += createXMLElement('ItemCountryOfManufacture', item['ItemCountryOfManufacture']);
                itemsXml += createXMLElement('ItemProducer', item['ItemProducer']);
                itemsXml += createXMLElement('ItemExportType', item['ItemExportType']);
                itemsXml += createXMLElement('ItemManufacturerName', item['ItemManufacturerName']);
                itemsXml += createXMLElement('ItemMultManufactureAddr', item['ItemMultManufactureAddr']);
                itemsXml += createXMLElement('ItemManufacturerAddr1', item['ItemManufacturerAddr1']);
                itemsXml += createXMLElement('ItemManufacturerCity', item['ItemManufacturerCity']);
                itemsXml += createXMLElement('ItemManufacturerState', item['ItemManufacturerState']);
                itemsXml += createXMLElement('ItemManufacturerZip', item['ItemManufacturerZip']);
                itemsXml += createXMLElement('ItemManufacturerTaxId', item['ItemManufacturerTaxId']);
                itemsXml += createXMLElement('ItemManufacturerTariff', item['ItemManufacturerTariff']);
                itemsXml += createXMLElement('ItemPreferenceCriterion', item['ItemPreferenceCriterion']);
                itemsXml += createXMLElement('ItemScheduleBNumber', item['ItemScheduleBNumber']);
                itemsXml += createXMLElement('ItemScheduleBQuantity', item['ItemScheduleBQuantity']);
                itemsXml += createXMLElement('ItemScheduleBCode', item['ItemScheduleBCode']);
                itemsXml += createXMLElement('ItemUnitsDisplay', item['ItemUnitsDisplay']);
                itemsXml += createXMLElement('ItemUnitPrice', item['ItemUnitPrice']);
				itemsXml += createXMLElement('ItemLine', item['ItemLine']);
				itemsXml += createXMLElement('ItemTotalQuantity', item['ItemTotalQuantity']);
				itemsXml += createXMLElement('ItemQuantityRemaining', item['ItemQuantityRemaining']);
				itemsXml += createXMLElement('ItemTotalAmount', item['ItemTotalAmount']);
				itemsXml += '</Item>';
			}
		}
	}
	itemsXml += '</Items>';
	return itemsXml;
}

function createXMLHttpRequest()
{
	try { return new ActiveXObject('Msxml2.XMLHTTP'); } catch (e) {}
	try { return new ActiveXObject('Microsoft.XMLHTTP'); } catch (e) {}
	try { return new XMLHttpRequest(); } catch (e) {}
	alert('XMLHttpRequest not supported!');
}

function createXMLElement(nodeName, nodeValue)
{
	if (!isValEmpty(nodeValue)) {return ('<' + nodeName + '>' + nlapiEscapeXML(nodeValue) + '</' + nodeName + '>');} else {return '<' + nodeName + '/>';}
}

function sendItemShipRequest(shipMethod)
{
	if (shipMethod == null || shipMethod.length == 0)
	{
		return;
	}

	var xmlStr = createItemShipRequestXml(shipMethod);
	var serverXmlStr = nlapiServerCall('/app/accounting/transactions/dynitemship.nl', 'getItemShipInfo', [xmlStr]);
	var serverXml = nlapiStringToXML(serverXmlStr);

	var shipMethod = getXMLValue(serverXml, "/ItemShipResponse/ShipMethod", '');
	var carrierForm = getXMLValue(serverXml, "/ItemShipResponse/CarrierForm", '');
	var serviceCode = getXMLValue(serverXml, "/ItemShipResponse/ShipperServiceCode", '');
	var isLabelEnabled = getXMLValue(serverXml, "/ItemShipResponse/IsLabelEnabled", 'F');
	var shipCostFunction = getXMLValue(serverXml, "/ItemShipResponse/ShipCostFunction", '');
	var handlingAccount = getXMLValue(serverXml, "/ItemShipResponse/HandlingAccount", '');
	var serviceGroupId = getXMLValue(serverXml, "/ItemShipResponse/ServiceGroupId", '');
	var shippingPartner = getXMLValue(serverXml, "/ItemShipResponse/ShippingPartner", '');
	var serviceGroupId = getXMLValue(serverXml, "/ItemShipResponse/ServiceGroupId", '');

	processItemShipResponse(shipMethod, carrierForm, serviceCode, isLabelEnabled, shipCostFunction, handlingAccount, shippingPartner, serviceGroupId);
}

function createItemShipRequestXml(shipMethod)
{
	var reqXml = '<ItemShipRequest>';
	reqXml += createXMLElement('ShipMethod', shipMethod);
	reqXml += '</ItemShipRequest>';
	return reqXml;
}


function createLocationsRequestXml(shipAddr1, shipAddr2, shipCity, shipState, shipZip, shipCountry, isResidential, shipDate, shipper, shippingMethod, locationId, saturdayHAL, testId)
{
	var ratesReqXml = '<LocationsRequest>';

	ratesReqXml += '<Context>';
	ratesReqXml += createXMLElement('Shipper', shipper);
	ratesReqXml += createXMLElement('ShippingMethod', shippingMethod);
	ratesReqXml += createXMLElement('LocationID', locationId);
	ratesReqXml += createXMLElement('IsFulfillment', 'T');
	ratesReqXml += createXMLElement('DestinationCountry', shipCountry);
	ratesReqXml += createXMLElement('TestId', testId);
	ratesReqXml += '</Context>';

	ratesReqXml += '<DestinationAddress>';
	ratesReqXml += createXMLElement('AddressLine1', shipAddr1);
	ratesReqXml += createXMLElement('AddressLine2', shipAddr2);
	ratesReqXml += createXMLElement('City', shipCity);
	ratesReqXml += createXMLElement('State', shipState);
	ratesReqXml += createXMLElement('PostalCode', shipZip);
	ratesReqXml += createXMLElement('Country', shipCountry);
	ratesReqXml += createXMLElement('IsResidential', isResidential);
	ratesReqXml += '</DestinationAddress>';

	ratesReqXml += createXMLElement('Date', shipDate);
	ratesReqXml += createXMLElement('SaturdayHAL', saturdayHAL);
	ratesReqXml += '</LocationsRequest>';

	return ratesReqXml;
}

function buildLocation(halAddr1, halAddr2, halAddr3, halCity, halState, halPostalCode, halCountry, halLocationPhone)
{
	var location = new Array(8);

	location['AddressLine1'] = halAddr1;
	location['AddressLine2'] = halAddr2;
	location['AddressLine3'] = halAddr3;
	location['City'] = halCity;
	location['State'] = halState;
	location['PostalCode'] = halPostalCode;
	location['Country'] = halCountry;
	location['LocationPhone'] = halLocationPhone;
	location['one_line_representation'] = halAddr1 + ', ' + halCity + ' ' + halPostalCode;

	return location;
}

function getLocationsFromServer(xmlStr)
{
	var serverXmlStr = nlapiServerCall('/app/common/shipping/shipperlocationslookupxml.nl', 'getShipperLocations', [xmlStr]);
	var serverXml = nlapiStringToXML(serverXmlStr);
	var errorXml = nlapiSelectNodes(serverXml, '/LocationsResponse/Error');
	if (errorXml != null && errorXml.length > 0)
	{
		alert(getXMLValue(errorXml[0], 'ErrorMessage', 'An unexpected error occurred.'));
		return null;
	}

	var locationsXml = nlapiSelectNodes(serverXml, '/LocationsResponse/Locations/Location');
	var locations = new Array(0);
	if (locationsXml != null)
	{
		locations = new Array(locationsXml.length);
		for (var i = 0; i < locationsXml.length; i++)
		{
			var halAddr1 = getXMLValue(locationsXml[i], 'AddressLine1', '');
			var halAddr2 = getXMLValue(locationsXml[i], 'AddressLine2', '');
			var halAddr3 = getXMLValue(locationsXml[i], 'AddressLine3', '');
			var halCity = getXMLValue(locationsXml[i], 'City', '');
			var halState = getXMLValue(locationsXml[i], 'State', '');
			var halPostalCode = getXMLValue(locationsXml[i], 'PostalCode', '');
			var halCountry = getXMLValue(locationsXml[i], 'Country', '');
			var halLocationPhone = getXMLValue(locationsXml[i], 'LocationPhone', '');

			locations[i] = buildLocation(halAddr1, halAddr2, halAddr3, halCity, halState, halPostalCode, halCountry, halLocationPhone);
		}
	}

	return locations;
}
function getXMLValue(xmlDoc, xPath, defaultValue)
{
	// Set the return value to the passed in default.
	var xmlValue = defaultValue;

	if ((typeof xmlDoc != "undefined") && (xmlDoc != null))
	{
		var xmlNode = nsSelectNode(xmlDoc, xPath);
		if (xmlNode != null)
		{
			xmlValue = nsGetXMLValue(xmlNode);
		}
	}

	return xmlValue;
}

function ratingSelectNode(xmlDoc, path)
{
	return nsSelectNode(xmlDoc, path);
}

function ratingSelectNodes(xmlDoc, path)
{
	return nsSelectNodes(xmlDoc, path);
}

function makeShippingRateCall(xmlStr)
{
	return nlapiServerCall('/app/common/shipping/dynshippingxml.nl', 'getShippingRates', [xmlStr], null, 'POST');
}var ShippingCommon = new function()
{
this.buildAddressString = function (address)
{
	if (!this.isDefined(address))
	{
		return '';
	}
	var result = '';
	if (this.isDefined(address.addressLine1))
	{
		result += address.addressLine1 + ' ';
	}
	if (this.isDefined(address.addressLine2))
	{
		result += address.addressLine2 + ' ';
	}
	if (this.isDefined(address.addressLine3))
	{
		result += address.addressLine3 + ' ';
	}
	if (this.isDefined(address.city))
	{
		result += address.city + ', ';
	}
	if (this.isDefined(address.state))
	{
		result += address.state + ' ';
	}
	if (this.isDefined(address.postalCode))
	{
		result += address.postalCode + ' ';
	}
	if (this.isDefined(address.country))
	{
		result += address.country;
	}
	return result;
};
this.getCarrierGroup = function (carrier)
{
	if (carrier == 'ups')
	{
		return 'ups';
	}
	return 'nonups';
};
this.isDefined = function isDefined(obj)
{
	return typeof obj != 'undefined' && obj != null;
}
this.callIfDefined = function callIfDefined(eventHandler, params)
{
	if (typeof eventHandler != 'undefined')
	{
		return eventHandler.apply(undefined, params);
	}
	return true;
}
};

