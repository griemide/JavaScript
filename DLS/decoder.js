// script language="javascript" type="text/javascript" 
// (c)2016, Michael W. Gries
// creation date: 2016-09-22
// last modified: 2016-09-23

// history:
// 2016-09-22 creation (based on VRC project)

var DECODERVERSION = "14.11.27";
var DEBUG = false;
var sValue;
var aCodeBytes;
                                
var Datum = "1970-01-01"
var Zeit = "23:59:59"
var ATemp = 0;
var WTemp = 0;
var KTemp = 0;
var HKurve = 0;
var Betriebsart = "AUS";
var UOM = "°C";

// Global function
//var formatted = sprintf("The number is %.2f", 42);

// Load sprintf as shown above
//sprintf.attach(String.prototype);

// Now every string has a printf function available
//var formatted = "%s %s".printf("foo", "bar");

// Array size is 67 bytes; i.e. [00-66]
/*  Array-
 *  Pos.    Parameter Name
 *  00      Start Sequenz = 06(hex)
 *  18-19   Betriebsstatus
 *  21      DCF77 Status
 *  22      DCF77 Sekunde
 *  23      DCF77 Minute
 *  24      DCF77 Stunde
 *  25      DCF77 Wochentag
 *  26      DCF77 Tag
 *  27      DCF77 Monat
 *  28      DCF77 Jahr
 *  32-33   Aussentemperatur
 *  35-36   Vorlauftemperatur
 *  38-39   Speichertemperatur
 *  47-48   Heizkurven-Stellwert
 *  65      Sommer-/Winterbetrieb
 *  66      checksum (of last datagram term)
 */

/*  Div-    Mapping
 *  Pos     Parameter Name vs. Funktonseinheit
 *  [0]     Betriebsstatus
 *  [1]     DCF77 Status
 *  [2]     DCF77 Datum
 *  [3]     DCF77 Zeit
 *  [4]     DCF77 Wochentag
 *  [5]     Aussentemperatur
 *  [6]     Heizkurven-Stellwert
 *  [7]     Warmwassertemperatur
 *  [8]     Kesseltemperatur
 *  [9]     Betriebsart
 */

// 2014-05-31
function updateDatagram(){
    var sInnerText=document.form1.example.options[document.form1.example.selectedIndex].value;
    document.all.inputText.innerText=sInnerText;
    //markDatagramBytesUsed(sInnerText);
    document.all.statusText.innerText="Status: Valid datagram in Input Field detected";
}

// 2014-06-08
function markDatagramBytesUsed(sUpdateDatagram){
    var aInnerText = sUpdateDatagram.split(" ");
    var sInnerHTML="<span>";
    sInnerHTML.concat(aInnerText[6]);
    sInnerHTML.concat("</span>");
    document.all.inputText.innerHTML=sInnerHTML;
}

// 2014-05-31
function startDecoding() {
    sValue = document.all.inputText.value;
    if (sValue == "") {
        document.all.statusText.innerText="Status: no Datagram in Input Field (select example above or paste new code)";
    } else {
        document.all.statusText.innerText="Status: currently no decoder implemented";
    }
    copyDatagramToArray(sValue);
    decodeDatagram();
    activateCodeEntry();
}

// 2014-06-01
function clearCode() {
    //alert(document.referrer);
    document.all.inputText.innerText="";
    document.all.statusText.innerText="Status: no Datagram in Input Field (select example above or paste new code)";
    document.all.smsTEXT.value = "";
    document.all.smsOK.disabled = "disabled";
    hide_elements('Decode','Header');
    hide_elements('Div0','Div1','Div2','Div3','Div4','Div5','Div6','Div7','Div8','Div9');
}

function copyDatagramToArray(datagram) {
    aCodeBytes = datagram.split(" ");
}

function decodeDatagram() {
    document.all.statusText.innerText="Status: currently no decoder implemented";
    document.all.Header.innerText="[BytePos]: Wert   - Bemerkungen";
    decodeBetriebsstatus();
    decodeBetriebsart();
    document.all.statusText.innerText="Status: currently only 'Betriebsart' supported";
    decodeAussentemperatur();
    decodeWarmwassertemperatur();
    document.all.statusText.innerText="Status: currently only 'Betriebsart', 'WT' and 'Aussentemperatur' supported";
    decodeKesseltemperatur();
    decodeHeizkurvenStellwert();
    document.all.statusText.innerText="Status: currently only 'Betriebsart' and 'Aussentemperatur' supported";
    decodeDCF77status();
    decodeDCF77datum();
    decodeDCF77zeit();
    decodeWochentag();
    aggregateSMS();
    document.all.statusText.innerText="Status: decoding successfully completed. Decoder version: " + DECODERVERSION;
    document.getElementById("DecodeBlock").style.borderStyle="solid";
    document.getElementById("DecodeBlock").style.borderWidth="1px";
    document.getElementById("DecodeBlock").style.borderColor="lightgrey";
    //document.getElementById("Tools").style.visibility="visible";
    //document.getElementById("RefJS").style.visibility="visible";
    hide_elements('Tools','RefJS');
    show_elements('Decode','Header');
    show_elements('Div0','Div1','Div2','Div3','Div4','Div5','Div6','Div7','Div8','Div9');
} 

function decodeBetriebsstatus() {
    var sID = "Div0";
    var sBetriebsstatus = "[19]-[20]: ";
    var sValue = aCodeBytes[18] + aCodeBytes[19];
    sBetriebsstatus += sValue;
    sBetriebsstatus += "&nbsp;&nbsp;";
    sBetriebsstatus += " - ";
    document.getElementById(sID).style.color="blue";
    switch (sValue) {
    case "0000":
        sBetriebsstatus += "Bereitschaft";
        document.getElementById(sID).style.color="green";
        break;
    case "0001":
        sBetriebsstatus += "Heizbetrieb";
        document.getElementById(sID).style.color="red";
        break;
    case "0002":
        sBetriebsstatus += "Warmwasser";
        break;
    case "0100":
        sBetriebsstatus += "Wartung";
        document.getElementById(sID).style.color="blue";
        break;
    case "0400":
        sBetriebsstatus += "Warmwasser (Pumpenachlauf)";
        break;
    case "0402":
        sBetriebsstatus += "Warmwasser (Pumpe ein)";
        break;
    case "0500":
        sBetriebsstatus += "Warmwasser (Pumpenachlauf) & Wartung";
        break;
    case "0501":
        sBetriebsstatus += "Heizbetrieb & Wartung";
        document.getElementById(sID).style.color="red";
        break;
    case "0502":
        sBetriebsstatus += "Warmwasser (Pumpe ein) & Wartung";
        break;
    default:
        sBetriebsstatus += "Betriebsstatus unbekannt";
        document.getElementById(sID).style.color="red";
        break;
    }
    sBetriebsstatus.charAt(1,1).fontcolor="red";
    document.getElementById(sID).innerHTML = sBetriebsstatus;
}

function decodeDCF77status() {
    var sID = "Div1";
    var sDCF77status;
    sDCF77status  = "[22]&nbsp;&nbsp;&nbsp;&nbsp; : ";
    sDCF77status += aCodeBytes[21];
    sDCF77status += "&nbsp;&nbsp;&nbsp;&nbsp;";
    sDCF77status += " - ";
    switch (aCodeBytes[21]) {
    case "00":
        sDCF77status += "DCF77: kein Empfang";
        break;
    case "01":
        sDCF77status += "DCF77: Empfang";
        break;
    case "02":
        sDCF77status += "DCF77: Synchonisierung";
        break;
    case "03":
        sDCF77status += "DCF77: Signal g&uuml;ltig";
        break;
    default:
        sDCF77status += "DCF77: Status unbekannt";
        break;
    }
    document.getElementById(sID).innerHTML = sDCF77status;
}

function decodeDCF77datum() {
    var sID = "Div2";
    var sDCF77datum = "[27]-[29]: ";
    var sValue = aCodeBytes[26] + aCodeBytes[27] + aCodeBytes[28];
    var iDay = parseInt(aCodeBytes[26],16);
    var iMonth = parseInt(aCodeBytes[27],16);
    var iYear = parseInt(aCodeBytes[28],16);
    var sDay = addLeadingZeros(iDay.toString(),2);
    var sMonth = addLeadingZeros(iMonth.toString(),2);
    var sYear = addLeadingZeros(iYear.toString(),2);
    sDCF77datum += sValue;
    sDCF77datum += " - ";
    sDCF77datum += "DCF77: Datum ";
    sDCF77datum += sDay;
    //sDCF77datum += ".";
    sDCF77datum += sMonth;
    //sDCF77datum += ".";
    sDCF77datum += sYear;
    sDCF77datum += " (20";
    sDCF77datum += sYear;
    sDCF77datum += "-";
    sDCF77datum += sMonth;
    sDCF77datum += "-";
    sDCF77datum += sDay;
    sDCF77datum += ")";
    document.getElementById(sID).innerHTML = sDCF77datum;
}

function decodeDCF77zeit() {
    var sID = "Div3";
    var sDCF77zeit = "[23]-[25]: ";
    var sValue = aCodeBytes[22] + aCodeBytes[23] + aCodeBytes[24];
    var iHour = parseInt(aCodeBytes[24],16);
    var iMinute = parseInt(aCodeBytes[23],16);
    var iSecond = parseInt(aCodeBytes[22],16);
    var sHour = addLeadingZeros(iHour.toString(),2);
    var sMinute = addLeadingZeros(iMinute.toString(),2);
    var sSecond = addLeadingZeros(iSecond.toString(),2);
    //var sHour = sprintf("%.2i",iHour);
    sDCF77zeit += sValue;
    sDCF77zeit += " - ";
    sDCF77zeit += "DCF77: Zeit ";
    sDCF77zeit += sSecond;
    //sDCF77zeit += ":";
    sDCF77zeit += sMinute;
    //sDCF77zeit += ":";
    sDCF77zeit += sHour;
    sDCF77zeit += " (";
    //sDCF77zeit += sHour;
    sDCF77zeit += sHour;
    sDCF77zeit += ":";
    sDCF77zeit += sMinute;
    sDCF77zeit += ":";
    sDCF77zeit += sSecond;
    sDCF77zeit += ")";
    document.getElementById(sID).innerHTML = sDCF77zeit;
}

function decodeWochentag() {
    var sID = "Div4";
    var sWochentag;
    sWochentag  = "[26]&nbsp;&nbsp;&nbsp;&nbsp; : ";
    sWochentag += aCodeBytes[25];
    sWochentag += "&nbsp;&nbsp;&nbsp;&nbsp;";
    sWochentag += " - ";
    switch (aCodeBytes[25]) {
    case "00":
        sWochentag += "DCF77: Montag";
        break;
    case "01":
        sWochentag += "DCF77: Dienstag";
        break;
    case "02":
        sWochentag += "DCF77: Mittwoch";
        break;
    case "03":
        sWochentag += "DCF77: Donnerstag";
        break;
    case "04":
        sWochentag += "DCF77: Freitag";
        break;
    case "05":
        sWochentag += "DCF77: Samstag";
        break;
    case "06":
        sWochentag += "DCF77: Sonntag";
        break;
    default:
        sWochentag += "DCF77: Unknown";
        break;
    }
    document.getElementById(sID).innerHTML = sWochentag;
}

function decodeAussentemperatur() {
    var sID = "Div5";
    var sAussentemperatur = "[33]-[34]: ";
    var sValue = aCodeBytes[32] + aCodeBytes[33];
    var iValue = parseInt(sValue, 16);
    // wenn negative Aussentenmperaturen:
    if ((iValue & 0x8000) > 0) {
       iValue = iValue - 0x10000;
    }
    var fValue = iValue / 16;
    fValue = round1Decimal(fValue);
    sAussentemperatur += sValue;
    sAussentemperatur += "&nbsp;&nbsp;";
    sAussentemperatur += " - ";
    sAussentemperatur += fValue.toString();
    sAussentemperatur += "&deg;C Aussentemperatur";
    document.getElementById(sID).innerHTML = sAussentemperatur;
}

function decodeHeizkurvenStellwert() {
    var sID = "Div6";
    var sHeizkurvenStellwert  = "[48]-[49]: ";
    var sValue = aCodeBytes[47] + aCodeBytes[48];
    var iValue = parseInt(sValue, 16);
    var fValue = iValue / 16; fValue = round1Decimal(fValue);
    sHeizkurvenStellwert += sValue;
    sHeizkurvenStellwert += "&nbsp;&nbsp;";
    sHeizkurvenStellwert += " - ";
    sHeizkurvenStellwert += fValue.toString();
    sHeizkurvenStellwert += "&deg;C Heizkurven-Stellwert";
    document.getElementById(sID).innerHTML = sHeizkurvenStellwert;
}

function decodeWarmwassertemperatur() {
    var sID = "Div7";
    var sWarmwassertemperatur = "[36]-[37]: ";
    var sValue = aCodeBytes[35] + aCodeBytes[36];
    var iValue = parseInt(sValue, 16);
    var fValue = iValue / 16;
    fValue = round1Decimal(fValue);
    sWarmwassertemperatur += sValue;
    sWarmwassertemperatur += "&nbsp;&nbsp;";
    sWarmwassertemperatur += " - ";
    sWarmwassertemperatur += fValue.toString();
    sWarmwassertemperatur += "&deg;C Warmwassertemperatur";
    document.getElementById(sID).innerHTML = sWarmwassertemperatur;
}

function decodeKesseltemperatur() {
    var sID = "Div8";
    var sKesseltemperatur  = "[39]-[40]: ";
    var sValue = aCodeBytes[38] + aCodeBytes[39];
    var iValue = parseInt(sValue, 16);
    var fValue = iValue / 16;
    fValue = round1Decimal(fValue);
    sKesseltemperatur += sValue;
    sKesseltemperatur += "&nbsp;&nbsp;";
    sKesseltemperatur += " - ";
    sKesseltemperatur += fValue.toString();
    sKesseltemperatur += "&deg;C Kesseltemperatur";
    document.getElementById(sID).innerHTML = sKesseltemperatur;
}

function decodeBetriebsart() {
    var sID = "Div9";
    var sBetriebsart;
    //sBetriebsart = document.getElementById("Div9").innerHTML;
    sBetriebsart  = "[66]&nbsp;&nbsp;&nbsp;&nbsp; : ";
    //sBetriebsart += aCodeBytes[65];  // array value may result in undefined
    switch (aCodeBytes[65]) {
    case undefined:
        sBetriebsart += "NaN";
        document.getElementById(sID).style.color="red";
        break;
    default:
        sBetriebsart += aCodeBytes[65];
        break;
    }
    sBetriebsart += "&nbsp;&nbsp;&nbsp;&nbsp;";
    sBetriebsart += " - ";
    switch (aCodeBytes[65]) {
    case "00":
        sBetriebsart += "Sommerbetrieb";
        Betriebsart = "Sommer";
        break;
    case "01":
        sBetriebsart += "Winterbetrieb";
        Betriebsart = "Winter";
        break;
    case undefined:
        sBetriebsart += "Undefined (set to NaN)";
        Betriebsart = "Kein Wert";
        break;
    default:
        sBetriebsart += "Wert nicht bekannt";
        Betriebsart = "Unbekannt";
        document.getElementById(sID).style.color="red";
        break;
    }
    document.getElementById(sID).innerHTML = sBetriebsart;
}

function secureStatus() {
    //alert(this.value);
    var sSecureValue = document.all.iPWD.value;
    //alert(sSecureValue);
    if (sSecureValue == "0815") {
        //alert(sSecureValue);
        document.all.iPWD.value = "";
        show_elements('javascript');
        show_elements('Tools','RefJS');
    }
}
// 2014-06-06
function secureSMS() {
    //alert(this.value);
    var sSecureValue = document.all.smsPWD.value;
    //alert(sSecureValue);
    if (sSecureValue == "0815") {
        //alert(sSecureValue);
        document.all.smsPWD.value = "";
        document.all.smsOK.disabled = "";
    }
}

// 2014-06-19
function aggregateSMS() {
    var smsTextLimit = 160;
    var smsAggregatedText = "AF104:\nStatus Heizung\n(VRC." + DECODERVERSION + ")\n";
    smsAggregatedText += Datum;
    smsAggregatedText += " ";
    smsAggregatedText += Zeit;
    smsAggregatedText += "\n";
    smsAggregatedText += "Aussentemperatur: ";
    smsAggregatedText += ATemp + UOM;
    smsAggregatedText += "\n";
    document.all.smsTEXT.value = smsAggregatedText;
    if (smsAggregatedText.length > smsTextLimit){
        document.all.smsTEXT.value = "SMS status: maximum number of characters for SMS exceeded";
        document.all.smsTEXT.style.color="red";
    }
}

function activateCodeEntry() {
    //alert(document.all.iPWD.disabled);
    document.all.iPWD.disabled = "";
    document.all.smsPWD.disabled = "";
}

// Elemente einblenden
// Mit show_elements() können einzelne oder mehrere Elemente
// via show_elements('ElementIDone','ElementIDtwo','ElementIDthree')
// eingeblendet werden.
function show_elements()  {
  var elementNames = show_elements.arguments;
  for (var i=0; i < elementNames.length; i++) {
     var elementName = elementNames[i];
     document.getElementById(elementName).style.visibility='visible';
   }
}

// HTML Elemente einblenden
// Mit hide_elements() können einzelne oder mehrere Elemente
// via hide_elements('ElementIDone','ElementIDtwo','ElementIDthree')
// ausgeblendet werden.
function hide_elements()  {
  var elementNames = hide_elements.arguments;
  for (var i=0; i < elementNames.length; i++) {
     var elementName = elementNames[i];
     document.getElementById(elementName).style.visibility='hidden';
   }
}

function isValidHex (hex) {
	var pattern = new RegExp('[^0-9a-fA-F]');
	return pattern.test(hex);
}

function round1Decimal(x) {
    var result = Math.round(x * 10) / 10 ; 
    return result;
}

function addLeadingZeros(number, length) {
    var num = '' + number;
    while (num.length < length) num = '0' + num;
    return num;
}

//not used yet
function hex2float(num) {
    var sign = (num & 0x80000000) ? -1 : 1;
    var exponent = ((num >> 23) & 0xff) - 127;
    var mantissa = 1 + ((num & 0x7fffff) / 0x7fffff);
    return sign * mantissa * Math.pow(2, exponent);
}