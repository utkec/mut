//
//  ViewController.swift
//  The MUT v5
//
//  Created by Michael Levenick on 5/24/19.
//  Copyright © 2019 Levenick Enterprises, LLC. All rights reserved.
//

import Cocoa
import CSV
import Foundation
import SwiftyJSON

class ViewController: NSViewController, URLSessionDelegate, NSTableViewDelegate, DataSentDelegate {

    // Outlet of tab view to determine which tab is active
    @IBOutlet weak var tabViewOutlet: NSTabView!

    // Declare outlets for Buttons to change color and hide/show
    @IBOutlet weak var btnSubmitOutlet: NSButton!
    @IBOutlet weak var btnPreFlightOutlet: NSButton!
    @IBOutlet weak var btnCancelOutlet: NSButton!

    // Declare outlet for entire controller
    @IBOutlet var MainViewController: NSView!
    
    //MARK: TableView Outlets and actions
    //tableMain
    @IBOutlet weak var tableMain: NSTableView!
    //Identifier Table
    @IBOutlet weak var tblIdentifier: NSTableView!
    @IBOutlet weak var lblRecordType: NSTextField!
    
    //Scopes Table
    @IBOutlet weak var tblScopes: NSTableView!
    @IBOutlet weak var lblScopeType: NSTextField!
    
    
    
    //@IBOutlet weak var identifierHeader: NSTableHeaderView!
    //@IBOutlet weak var identifierText: NSTextField!

    // Progress bar and labels for runtime
    @IBOutlet weak var barProgress: NSProgressIndicator!
    @IBOutlet weak var lblCurrent: NSTextField!
    @IBOutlet weak var lblOf: NSTextField!
    @IBOutlet weak var lblEndLine: NSTextField!
    @IBOutlet weak var lblLine: NSTextField!
    
    @IBOutlet weak var lblStatus: NSTextField!
    
    // DropDowns for Attributes etc
    @IBOutlet weak var txtCSV: NSTextField!
    @IBOutlet weak var popRecordTypeOutlet: NSPopUpButton!
    @IBOutlet weak var popActionTypeOutlet: NSPopUpButton!
    @IBOutlet weak var txtPrestageID: NSTextField!
    
    var globalPathToCSV: NSURL!
    var globalToken: String!
    var globalURL: String!
    var globalExpiry: Int!
    var globalBase64: String!
    var globalEndpoint: String!
    //Added globalTab to contain all the scope tab endpoints for table drawing
    var globalTab: String!
    var xmlToPut: Data!
    var jsonToSubmit: Data!
    var globalDelimiter: UnicodeScalar!
    var csvArray = [[String]]()
    
    var delimiter = ","

    var cancelRun = false
    
    let dataPrep = dataPreparation()
    let tokenMan = tokenManagement()
    let xmlMan = xmlManager()
    let CSVMan = CSVManipulation()
    let APIFunc = APIFunctions()
    let popMan = popPrompt()
    let jsonMan = jsonManager()
    let logMan = logManager()
    
    // Declare variable for defaults on main view
    let mainViewDefaults = UserDefaults.standard
    
    //Variables used by tableViews
    var currentData : [[String: String]] = []
    var csvData : [[ String : String ]] = []
    var csvIdentifierData: [[String: String]] = []
    var scopeData: [[String: String]] = []
    
    // Arrays to populate dropdown menus
    let prestageActionArray = ["Add to Prestage","Remove from Prestage","Replace Existing Prestage"]
    let groupActionArray = ["Add to Static Group","Remove from Static Group","Replace Existing Static Group"]

    // Information used to confirm the header row of the CSV files
    let userCSV = ["Current Username","New Username","Full Name","Email Address","Phone Number","Position","LDAP Server ID","Site (ID or Name)","Managed Apple ID (Requires Jamf Pro 10.15+)"]
    
    let mobileDeviceCSV = ["Mobile Device Serial","Display Name","Asset Tag","Username","Real Name","Email Address","Position","Phone Number","Department","Building","Room","PO Number","Vendor","PO Date","Warranty Expires","Lease Expires","Site (ID or Name)"]

    let computerCSV = ["Computer Serial","Display Name","Asset Tag","Barcode 1","Barcode 2","Username","Real Name","Email Address","Position","Phone Number","Department","Building","Room","PO Number","Vendor","PO Date","Warranty Expires","Lease Expires","Site (ID or Name)"]
    
    func userDidAuthenticate(base64Credentials: String, url: String, token: String, expiry: Int) {
        globalExpiry = expiry
        globalToken = token
        globalURL = url
        globalBase64 = base64Credentials
        if txtCSV.stringValue == "" {
            preferredContentSize = NSSize(width: 550, height: 490)
        } else {
            preferredContentSize = NSSize(width: 550, height: 550)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up delimiter
        if mainViewDefaults.value(forKey: "Delimiter") != nil {
            delimiter = mainViewDefaults.value(forKey: "Delimiter")! as! String
            logMan.infoWrite(logString: "A stored delimiter was found. Using the stored delimiter of \(delimiter) .")
        } else {
            logMan.infoWrite(logString: "No stored delimiter found. Using default delimiter of , .")
            delimiter = ","
        }
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueLogin" {
            let loginWindow: loginWindow = segue.destinationController as! loginWindow
            loginWindow.delegateAuth = self as DataSentDelegate
        }
    }

    override func viewWillAppear() {
        //resize the view
        super.viewWillAppear()
        preferredContentSize = NSSize(width: 550, height: 443)
        performSegue(withIdentifier: "segueLogin", sender: self)
    }
    
    //btnIdentifier reloads tableMain based on the index of the selected row in Identifier table
    @IBAction func btnIdentifier(_ sender: Any) {
        currentData = csvData
        let selectedIndex = tblIdentifier.clickedRow + 1
        //print("Selected Index is... \(selectedIndex)")
        let maxIndex = csvArray.count
        if selectedIndex == 0 {
            //print("selectedIndex is 0, not redrawing...")
        } else if
            selectedIndex < maxIndex {
            csvData = dataPrep.buildDict(rowToRead: selectedIndex, ofArray: csvArray)
            tableMain.reloadData()
        } else {
            //print("Index was out of range, not redrawing...")
        }
    }
    
    @IBAction func btnBrowse(_ sender: Any) {
        notReadyToRun()
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedFileTypes = ["csv"]
        openPanel.begin { (result) in
            if result.rawValue == NSFileHandlingPanelOKButton {
                
                // Set the global delim
                if self.delimiter == "," {
                    self.globalDelimiter = ","
                } else if self.delimiter == ";" {
                    self.globalDelimiter = ";"
                }
                
                self.globalPathToCSV = openPanel.url! as NSURL
                self.txtCSV.stringValue = self.globalPathToCSV.path!
                self.verifyCSV()
                
                self.csvArray.removeAll()
                
                // Perform the actual pre-flight checks
                let tabToGoTo = self.tabViewOutlet.selectedTabViewItem?.identifier as! String
                self.globalTab = tabToGoTo
                if tabToGoTo == "objects" {
                    self.attributePreFlightChecks()
                } else if tabToGoTo == "scope" {
                    self.scopePreFlightChecks()

                } else {
                    self.initialPreFlightChecks()
                }
            }
        }
    }

    @IBAction func btnPreFlightAction(_ sender: Any) {
        // Nuke the CSV array on every preflight so we don't get stuck with old data
        //csvArray.removeAll()

        // Perform the actual pre-flight checks
        let tabToGoTo = tabViewOutlet.selectedTabViewItem?.identifier as! String
        if tabToGoTo == "objects" {
            attributePreFlightChecks()
        } else if tabToGoTo == "scope" {
            if popActionTypeOutlet.titleOfSelectedItem?.isEmpty ?? true {
                _ = popMan.generalWarning(question: "No Action Selected", text: "It appears the dropdowns for record type and action are not populated.\n\nPlease select from the dropdowns what you would like to do, and try again.")
            } else {
                if !txtPrestageID.stringValue.isInt {
                    _ = popMan.generalWarning(question: "No Identifier Specified", text: "It appears the text box to specify the object ID is not a valid value.\n\nPlease enter a valid identifier in the box and try again.")
                } else {
                    readyToRun()
                    lblStatus.stringValue = "Looks good! Press 'Submit Updates' when you are ready to go."
                }
            }
        }
    }

    func setRecordType() {
        let generalEndpoint = dataPrep.endpoint(csvArray: csvArray)
        if generalEndpoint == "scope" {
            // do stuff based on dropdowns
            if popRecordTypeOutlet.titleOfSelectedItem!.contains("Computer Prestage") {
                globalEndpoint = "computer-prestages"
                lblScopeType.stringValue = "Serial Number"
                globalTab = "scope"
            } else if popRecordTypeOutlet.titleOfSelectedItem!.contains("Mobile Device Prestage")  {
                globalEndpoint = "mobile-device-prestages"
                lblScopeType.stringValue = "Serial Number"
                globalTab = "scope"
            } else if popRecordTypeOutlet.titleOfSelectedItem! == "Computer Static Group" {
                globalEndpoint = "computergroups"
                lblScopeType.stringValue = "Serial Number"
                globalTab = "scope"
            } else if popRecordTypeOutlet.titleOfSelectedItem! == "Mobile Device Static Group" {
                globalEndpoint = "mobiledevicegroups"
                lblScopeType.stringValue = "Serial Number"
                globalTab = "scope"
            } else if popRecordTypeOutlet.titleOfSelectedItem! == "User Object Static Group" {
                globalEndpoint = "usergroups"
                lblScopeType.stringValue = "Username"
                globalTab = "scope"
            }
            
        } else {
            globalTab = "inventory"
            if generalEndpoint == "users" {
                lblRecordType.stringValue = "Users"
            } else if generalEndpoint == "computers" {
                lblRecordType.stringValue = "Computers"
            } else if generalEndpoint == "mobiledevices" {
                lblRecordType.stringValue = "Mobile Devices"
            }
            globalEndpoint = generalEndpoint
        }
    }
    
    func drawTables() {
        let currentTab = tabViewOutlet.selectedTabViewItem?.identifier as! String
        if currentTab == "objects" {
            
            // Old tab stuff goes here
            
            //csvData becomes the main table's data. Prints the second row of the CSV, skipping the header.
            csvData = dataPrep.buildDict(rowToRead: 1, ofArray: csvArray)
            //csvIdentifierData contains the data for the Identifier column.
            //csvIdentifierData = dataPrep.buildID(ofArray: csvArray, countArray: csvData)
            csvIdentifierData = dataPrep.buildID(ofArray: csvArray)
            
            /* Must set currentData to the data for the table we're reloading,
             as currentData is used by the numberOfRows function */
            currentData = csvData
            tableMain.reloadData()
            
            currentData = csvIdentifierData
            tblIdentifier.reloadData()
            
        } else if currentTab == "scope" {
            // New tab stuff goes here
            //print("drawTables Function, tab scope...")
            scopeData = dataPrep.buildScopes(ofArray: csvArray)
            //print("csvData: \(scopeData)")
            currentData = scopeData
            //print("currentData should be the same as csvData: \(currentData)")
            tblScopes.reloadData()
        }
        
    }

    @IBAction func btnExportCSV(_ sender: Any) {
        logMan.infoWrite(logString: "Saving CSV Templates to User's Downloads Directory.")
        CSVMan.ExportCSV()
    }
    
    @IBAction func submitRequests(_ sender: Any) {
        if ( globalEndpoint.contains("group") || globalEndpoint.contains("prestage") ) {
            let needNewToken = tokenMan.checkExpiry(expiry: globalExpiry)
            // Check and get a new token if needed, and performing prestage updates
            if globalEndpoint.contains("prestage") {
                if needNewToken {
                    _ = popMan.generalWarning(question: "Expired Token", text: "It appears that your token has expired. This can happen if the app sits open for too long.\n\nYou will now be taken back to the login window. Please log in again to generate a new token.")
                    //lblStatus.stringValue = ""
                    //tabViewOutlet.selectTabViewItem(at: 0)
                    performSegue(withIdentifier: "segueLogin", sender: self)
                }
            }
            let recordTypeOutlet = popRecordTypeOutlet.titleOfSelectedItem!
            let endpoint = popRecordTypeOutlet.selectedItem!.identifier!.rawValue
            let prestageID = txtPrestageID.stringValue
            var httpMethod: String!
            var objectType: String!
            var appendReplaceRemove: String!

            switch popActionTypeOutlet.titleOfSelectedItem! {
            case "Add to Prestage":
                httpMethod = "POST"
            case "Remove from Prestage":
                httpMethod = "DELETE"
            case "Replace Existing Prestage":
                httpMethod = "PUT"
            default:
                httpMethod = "POST"
            }

            switch popActionTypeOutlet.titleOfSelectedItem! {
            case "Add to Static Group":
                appendReplaceRemove = "append"
            case "Remove from Static Group":
                appendReplaceRemove = "remove"
            case "Replace Existing Static Group":
                appendReplaceRemove = "replace"
            default:
                appendReplaceRemove = "append"
            }

            switch popRecordTypeOutlet.titleOfSelectedItem! {
            case "Computer Static Group":
                objectType = "computers"
            case "Mobile Device Static Group":
                objectType = "mobiledevices"
            case "User Object Static Group":
                objectType = "users"
            default:
                objectType = "computers"
            }
            if !needNewToken {
                DispatchQueue.global(qos: .background).async {
                    self.submitScopeUpdates(recordTypeOutlet: recordTypeOutlet, endpoint: endpoint, prestageID: prestageID, httpMethod: httpMethod, objectType: objectType, appendReplaceRemove: appendReplaceRemove)
                }
            }

        } else {
            DispatchQueue.global(qos: .background).async {
                self.submitAttributeUpdates()
            }
        }
    }
    
    func submitScopeUpdates(recordTypeOutlet: String, endpoint: String, prestageID: String, httpMethod: String, objectType: String, appendReplaceRemove: String) {
        var responseCode = 400

        DispatchQueue.main.async {
            self.guiAttributeRun()
        }

        logMan.infoWrite(logString: "Beginning CSV Parse - Scope update.")
        let csvArray = CSVMan.readCSV(pathToCSV: self.globalPathToCSV.path ?? "/dev/null", delimiter: globalDelimiter!)
        if recordTypeOutlet.contains("Prestage") {
            // Prestage updates here
            let versionLock = getCurrentPrestageVersionLock(endpoint: endpoint, prestageID: prestageID)
            var serialArray: [String]!
            serialArray = []
            if csvArray.count > 1 {
                for row in 1...(csvArray.count - 1) {
                    // Get the current row of the CSV for updating
                    let currentRow = csvArray[row]
                    serialArray.append(currentRow[0].trimmingCharacters(in: CharacterSet.whitespaces))
                }
                jsonToSubmit = jsonMan.buildJson(versionLock: versionLock, serialNumbers: serialArray)
                // Submit the JSON to the Jamf Pro API

                responseCode = APIFunc.updatePrestage(passedUrl: globalURL, endpoint: endpoint, prestageID: prestageID, jpapiVersion: "v1", token: globalToken, jsonToSubmit: jsonToSubmit, httpMethod: httpMethod, allowUntrusted: mainViewDefaults.bool(forKey: "Insecure"))
            } else {
                // Not enough rows in the CSV to run
            }
        } else {
            // Static Group updates here
            var serialArray: [String]!
            var xmlToPUT: Data!
            serialArray = []
            if csvArray.count > 1 {
                for row in 1...(csvArray.count - 1 ) {
                    let currentRow = csvArray[row]
                    serialArray.append(currentRow[0])
                }

                xmlToPUT = xmlMan.staticGroup(appendReplaceRemove: appendReplaceRemove, objectType: objectType, identifiers: serialArray)

                _ = APIFunc.putData(passedUrl: globalURL, credentials: globalBase64, endpoint: globalEndpoint, identifierType: "id", identifier: prestageID, allowUntrusted: mainViewDefaults.bool(forKey: "Insecure"), xmlToPut: xmlToPUT)
            }
        }

        DispatchQueue.main.async {
            self.guiAttributeDone()
            if responseCode == 200 {
                self.lblStatus.stringValue = "Successful update run complete. Check the MUT.log for details"
            } else {
                self.lblStatus.stringValue = "Update run failed. Check the MUT.log for details."
            }
        }
    }
    
    func submitAttributeUpdates() {
        logMan.infoWrite(logString: "Beginning CSV Parse - Attributes update.")
        let csvArray = CSVMan.readCSV(pathToCSV: self.globalPathToCSV.path ?? "/dev/null", delimiter: globalDelimiter!)
        
        // Set variables needed for the run
        var ea_ids = [String]()
        var ea_values = [String]()
        let headerRow = csvArray[0]
        let numberOfColumns = headerRow.count
        
        // Get the expected columns based off update type and calculate number of EAs present
        let expectedColumns = dataPrep.expectedColumns(endpoint: globalEndpoint!)
        
        let numberOfEAs = numberOfColumns - expectedColumns
        
        // If there are EAs, get a list of their EA IDs
        if numberOfEAs > 0 {
            ea_ids = dataPrep.eaIDs(expectedColumns: expectedColumns, numberOfColumns: numberOfColumns, headerRow: headerRow)
        }

        DispatchQueue.main.async {
            self.guiAttributeRun()
        }

        // Begin looping through the CSV sheet
        
        if csvArray.count > 1 {

            // LOOP FOR PROGRESS BAR BEGINS HERE
            updateLoop: for row in 1...(csvArray.count - 1) {
                // Get the current row of the CSV for updating
                let currentRow = csvArray[row]
                var identifierType: String!

                if cancelRun {
                    logMan.warnWrite(logString: "Update run cancelled by user on row \(row + 1) with identifier \(currentRow[0]).")
                    cancelRun = false
                    break updateLoop
                }

                DispatchQueue.main.async {
                    // progress bar updates during the run
                    self.lblEndLine.stringValue = "\(csvArray.count - 1)"
                    self.lblLine.stringValue = "\(row)"
                    self.barProgress.doubleValue = Double((100 * row / (csvArray.count - 1 )))
                }

                ea_values = [] // Reset the EA_values so that we aren't just appending

                // Populate the ea_values array if there are EAs to update
                if numberOfEAs > 0 {
                    ea_values = dataPrep.eaValues(expectedColumns: expectedColumns, numberOfColumns: numberOfColumns, currentRow: currentRow)
                }
                
                if globalEndpoint! == "users" {
                    // Generate the XML to submit
                    if currentRow[0].isInt {
                        if mainViewDefaults.value(forKey: "UserInts") != nil {
                            identifierType = "name"
                        } else {
                            identifierType = "id"
                        }
                    } else {
                        identifierType = "name"
                    }
                    xmlToPut = xmlMan.userObject(username: currentRow[1], full_name: currentRow[2], email_address: currentRow[3], phone_number: currentRow[4], position: currentRow[5], ldap_server: currentRow[6], ea_ids: ea_ids, ea_values: ea_values, site_ident: currentRow[7], managedAppleID: currentRow[8])
                } else if globalEndpoint! == "computers" {
                    if currentRow[0].isInt {
                        identifierType = "id"
                    } else {
                        identifierType = "serialnumber"
                    }
                    xmlToPut = xmlMan.macosObject(displayName: currentRow[1], assetTag: currentRow[2], barcode1: currentRow[3], barcode2: currentRow[4], username: currentRow[5], full_name: currentRow[6], email_address: currentRow[7], phone_number: currentRow[9], position: currentRow[8], department: currentRow[10], building: currentRow[11], room: currentRow[12], poNumber: currentRow[13], vendor: currentRow[14], poDate: currentRow[15], warrantyExpires: currentRow[16], leaseExpires: currentRow[17], ea_ids: ea_ids, ea_values: ea_values, site_ident: currentRow[18])
                } else if globalEndpoint! == "mobiledevices" {
                    if currentRow[0].isInt {
                        identifierType = "id"
                    } else {
                        identifierType = "serialnumber"
                    }
                    xmlToPut = xmlMan.iosObject(displayName: currentRow[1], assetTag: currentRow[2], username: currentRow[3], full_name: currentRow[4], email_address: currentRow[5], phone_number: currentRow[7], position: currentRow[6], department: currentRow[8], building: currentRow[9], room: currentRow[10], poNumber: currentRow[11], vendor: currentRow[12], poDate: currentRow[13], warrantyExpires: currentRow[14], leaseExpires: currentRow[15], ea_ids: ea_ids, ea_values: ea_values, site_ident: currentRow[16], airplayPassword: currentRow[17])
                    if currentRow[1] != "" {
                        // Enforce the mobile device name if the display name field is not blank
                        let xmlToPost = xmlMan.enforceName(deviceName: currentRow[1], serial_number: currentRow[0])
                        _ = APIFunc.enforceName(passedUrl: globalURL, credentials: globalBase64, allowUntrusted: mainViewDefaults.bool(forKey: "Insecure"), xmlToPost: xmlToPost)
                    }
                }
                
                // Submit the XML to the Jamf Pro API
                
                _ = APIFunc.putData(passedUrl: globalURL, credentials: globalBase64, endpoint: globalEndpoint!, identifierType: identifierType, identifier: currentRow[0], allowUntrusted: mainViewDefaults.bool(forKey: "Insecure"), xmlToPut: xmlToPut)
            }

            DispatchQueue.main.async {
                self.guiAttributeDone()
            }

        } else {
            // Not enough rows in the CSV to run
        }
    }
    
    func getCurrentPrestageVersionLock(endpoint: String, prestageID: String) -> Int {
        let myURL = dataPrep.generatePrestageURL(baseURL: globalURL, endpoint: endpoint, prestageID: prestageID, jpapiVersion: "v1")
        
        let response = APIFunc.getPrestageScope(passedUrl: myURL, token: globalToken, endpoint: endpoint, allowUntrusted: mainViewDefaults.bool(forKey: "Insecure"))
        do {
            let newJson = try JSON(data: response)
            let newVersionLock = newJson["versionLock"].intValue
            // Commenting out the previous serials array, as they are no longer needed. Leaving the code in case that changes.
            //let newSerials = newJson["assignments"][0]["serialNumber"].stringValue
            //let newSerialArray = newJson["assignments"].arrayValue.map {$0["serialNumber"].stringValue}
            return newVersionLock
        } catch let error as NSError {
            logMan.errorWrite(logString: "Failed to load: \(error.localizedDescription)")
            return -1
        }
    }
    
    func scopePreFlightChecks() {

        // If the user has actually selected a CSV template, then move on
        if txtCSV.stringValue != "" {
            //get the CSV from the "Browse" button and parse it into an array
            csvArray = CSVMan.readCSV(pathToCSV: self.globalPathToCSV.path!, delimiter: globalDelimiter!)
            if csvArray.count == 0 {
                // If there are no rows in the CSV
                _ = popMan.generalWarning(question: "Empty CSV Found", text: "It seems the CSV file you uploaded is malformed, or does not contain any data.\n\nPlease try a different CSV.")
            } else if csvArray.count == 1 {
                // If there is only 1 row in the CSV (header only)
                drawTables()
                _ = popMan.generalWarning(question: "No Data Found", text: "It seems the CSV file you uploaded does not contain any data outside of the header row.\n\nPlease select a CSV with updates for MUT to process.")
            } else {
                // If there is more than 1 column in the CSV
                if csvArray[0].count > 1 {
                    // If the CSV appears to not have good columns -- eg: wrong delimiter
                    _ = popMan.generalWarning(question: "Malformed CSV Found", text: "It seems there are too many columns in your CSV. Please try a different CSV file.\n\nIf you are using a delimiter other than comma, such as semi-colon, please select 'Change Delimiter' from Settings on the Menu bar.")
                } else {
                    // We end up here if all the pre-flight checks have been passed
                    setRecordType()
                    drawTables()
                }
            }
        }
    }
    
    func attributePreFlightChecks() {
        // If the user has actually selected a CSV template, then move on
        if txtCSV.stringValue != "" {
            //get the CSV from the "Browse" button and parse it into an array
            csvArray = CSVMan.readCSV(pathToCSV: self.globalPathToCSV.path!, delimiter: globalDelimiter!)
            
            if csvArray.count == 0 {
                // If there are no rows in the CSV
                _ = popMan.generalWarning(question: "Empty CSV Found", text: "It seems the CSV file you uploaded is malformed, or does not contain any data.\n\nPlease try a different CSV.")
            } else if csvArray.count == 1 {
                // If there is only 1 row in the CSV (header only)
                _ = popMan.generalWarning(question: "No Data Found", text: "It seems the CSV file you uploaded does not contain any data outside of the header row.\n\nPlease select a CSV with updates for MUT to process.")
            } else {
                // If there are less 6 columns in the CSV
                if csvArray[0].count <= 5 {
                    // If the CSV appears to not have good columns -- eg: wrong delimiter
                    _ = popMan.generalWarning(question: "Malformed CSV Found", text: "It seems there are not enough columns in your CSV file. Please try a different CSV file.\n\nIf you are using a delimiter other than comma, such as semi-colon, please select 'Change Delimiter' from Settings on the Menu bar.")
                } else {
                    // We end up here if all the pre-flight checks have been passed
                    drawTables()
                    //lblRecordType.objectValue = "Testing Labels"
                    setRecordType()
                    if verifyHeaders(endpoint: globalEndpoint, headers: csvArray[0]) {
                        readyToRun()
                        let numberOfColumns = csvArray[0].count

                        // Get the expected columns based off update type and calculate number of EAs present
                        let expectedColumns = dataPrep.expectedColumns(endpoint: globalEndpoint!)

                        let numberOfEAs = numberOfColumns - expectedColumns

                        // If there are EAs, get a list of their EA IDs
                        if numberOfEAs > 0 {

                            let ea_ids = dataPrep.eaIDs(expectedColumns: expectedColumns, numberOfColumns: numberOfColumns, headerRow: csvArray[0])
                            for ea in ea_ids {
                                if !ea.isInt {
                                    notReadyToRun()
                                    _ = popMan.generalWarning(question: "EA NOT INT", text: "a non int found")
                                }
                            }
                        }

                    } else {
                        _ = popMan.generalWarning(question: "Header Row Error", text: "It appears that the header row for your CSV does not match one of the provided templates.\n\nMUT requires that the template be kept exactly as-is, with the exception of adding Extension Attributes.\n\nPlease re-download the templates if you need to, add the data you would like to submit, and try again.")
                    }
                }
            }
        } else {
            _ = popMan.generalWarning(question: "No CSV Found", text: "Please use the Browse button to find a CSV file on your system with updates that you would like MUT to process.")
        }
    }
    
    func initialPreFlightChecks() {
        // If the user has actually selected a CSV template, then move on
        if txtCSV.stringValue != "" {
            //get the CSV from the "Browse" button and parse it into an array
            csvArray = CSVMan.readCSV(pathToCSV: self.globalPathToCSV.path!, delimiter: globalDelimiter!)
            
            if csvArray.count == 0 {
                // If there are no rows in the CSV
                _ = popMan.generalWarning(question: "Empty CSV Found", text: "It seems the CSV file you uploaded is malformed, or does not contain any data.\n\nPlease try a different CSV.")
            } else if csvArray.count == 1 {
                // If there is only 1 row in the CSV (header only)
                _ = popMan.generalWarning(question: "No Data Found", text: "It seems the CSV file you uploaded does not contain any data outside of the header row.\n\nPlease select a CSV with updates for MUT to process.")
            }
        } else {
            _ = popMan.generalWarning(question: "No CSV Found", text: "Please use the Browse button to find a CSV file on your system with updates that you would like MUT to process.")
        }
    }
    
    func verifyCSV() {
        // Nuke the CSV array on every preflight so we don't get stuck with old data
        csvArray.removeAll()
        
        if txtCSV.stringValue != "" {
            //get the CSV from the "Browse" button and parse it into an array
            csvArray = CSVMan.readCSV(pathToCSV: self.globalPathToCSV.path!, delimiter: globalDelimiter!)
            
            globalEndpoint = dataPrep.endpoint(csvArray: csvArray)
            
            if globalEndpoint == "Endpoint_Error" {
                _ = popMan.generalWarning(question: "CSV Error", text: "MUT is not able to read your CSV very well. Please try a different CSV.")
            } else if globalEndpoint == "scope" {
                if csvArray.count > 1 {
                    tabViewOutlet.selectTabViewItem(at: 2)
                    preferredContentSize = NSSize(width: 550, height: 550)
                    lblStatus.isHidden = false
                    lblStatus.stringValue = "Populate the dropdowns above, and then run your preflight check."
                }
            } else {
                if csvArray.count > 1 {
                    tabViewOutlet.selectTabViewItem(at: 1)
                    preferredContentSize = NSSize(width: 550, height: 550)
                    lblStatus.isHidden = false
                    lblStatus.stringValue = "Review the changes shown above. If everything looks good, hit submit."
                }
            }
            
        } else {
            _ = popMan.generalWarning(question: "No CSV Found", text: "Please use the Browse button to find a CSV file on your system with updates that you would like MUT to process.")
        }
    }
    
    func verifyHeaders(endpoint: String, headers: [String]) -> Bool {
        if endpoint == "computers" && headers.starts(with: computerCSV) {
            return true
        }
        if endpoint == "users" && headers.starts(with: userCSV) {
            return true
        }
        if endpoint == "mobiledevices" && headers.starts(with: mobileDeviceCSV) {
            return true
        }
        return false
    }
    
    func selectCorrectTab(endpoint: String) {
        if (endpoint == "computers" || endpoint == "users" || endpoint == "mobiledevices") {
            tabViewOutlet.selectTabViewItem(at: 0)
        } else if (endpoint.contains("prestages") || endpoint.contains("groups")){
            tabViewOutlet.selectTabViewItem(at: 1)
        }
    }

    func readyToRun() {
        btnSubmitOutlet.isHidden = false
        btnSubmitOutlet.becomeFirstResponder()
    }

    func notReadyToRun() {
        btnSubmitOutlet.isHidden = true
        lblStatus.stringValue = "Populate the dropdowns above, and then run your preflight check."
    }

    func guiAttributeRun() {
        btnSubmitOutlet.isHidden = true
        btnCancelOutlet.isHidden = false
        preferredContentSize = NSSize(width: 550, height: 570)
        lblCurrent.isHidden = false
        lblLine.isHidden = false
        lblEndLine.isHidden = false
        lblOf.isHidden = false
        barProgress.isHidden = false
        lblStatus.stringValue = "Running updates. See MUT.log for live status."
    }

    func guiAttributeDone() {
        btnSubmitOutlet.isHidden = false
        btnCancelOutlet.isHidden = true
        preferredContentSize = NSSize(width: 550, height: 550)
        lblCurrent.isHidden = true
        lblLine.isHidden = true
        lblEndLine.isHidden = true
        lblOf.isHidden = true
        barProgress.isHidden = true
        lblStatus.stringValue = "Updates complete. See MUT.log for details."
    }
    
    @IBAction func popRecordTypeAction(_ sender: Any) {
        notReadyToRun()
        popActionTypeOutlet.isEnabled = true
        txtPrestageID.isEnabled = true
        if (popRecordTypeOutlet.titleOfSelectedItem?.contains("Prestage"))! {
            popActionTypeOutlet.removeAllItems()
            popActionTypeOutlet.addItems(withTitles: prestageActionArray)
            txtPrestageID.placeholderString = "Prestage ID"
        } else {
            popActionTypeOutlet.removeAllItems()
            popActionTypeOutlet.addItems(withTitles: groupActionArray)
            txtPrestageID.placeholderString = "Group ID"
        }
        setRecordType()
        
    }
    
    @IBAction func popActionTypeAction(_ sender: Any) {
        notReadyToRun()
    }
    
    @IBAction func txtPrestageIdAction(_ sender: Any) {
        notReadyToRun()
    }

    @IBAction func btnCancelAction(_ sender: Any) {
        cancelRun = true
    }

}


//This entire extension handles the NSTableViews
extension ViewController: NSTableViewDataSource {
    
    //Counts number of rows in each dictionary before drawing cells
    //Unknown how the tableview function uses this value, as we never tell it to explicitly
    //It provides the upper limit to what "row" can be in the tableView function
    func numberOfRows(in tableView: NSTableView) -> Int {
        return (currentData.count)
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        //Initialize variables
        var identifierDict: [String: String] = [:]
        var attributeRow: [String: String] = [:]
        var scopeID: [String: String] = [:]
        //avoid index out of range if there are more rows in the original CSV than there are columns
        if row < csvData.count {
            attributeRow = csvData[row]
        }
        
        //avoid index out of range if there are more columns in the CSV than there are rows
        if csvIdentifierData.count > row {
            identifierDict = csvIdentifierData[row]
        }
        //print("globalTab for tableView is... \(globalTab)")
        if globalTab == "scope" {
            //print("scopeData : \(scopeData)")
            //print("scopeID : \(scopeID)")
            scopeID = scopeData[row]
        }

        
        //The following code matches values from the dictionaries with columns and cells from the tableviews
        //Then returns the cell
        guard let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as? NSTableCellView else { return nil }
        //3 columns, so 3 conditions. Right now the last condition is wrapped inside it's own conditional.
        //This may not be necessary
        
/* How this next part works:
 
         - if the tableColumn's identifier is "STRING", then it sets the cell equal to the value in dictionary[key]
         - returns that cell and increments row by 1, starts again.
         - this is repeated until row = rows
         - rows is set by function above this one, numberOfRows
 */
        
        if (tableColumn?.identifier)!.rawValue == "tableAttribute" {
            cell.textField?.stringValue = attributeRow["tableAttribute"] ?? "NO VALUE"
        } else if (tableColumn?.identifier)!.rawValue == "tableValue" {
            
            //If the value is unchanged, set text to systemBlue
            //IF value is CLEAR!, set text to systemRed
            cell.textField?.stringValue = attributeRow["tableValue"] ?? "NO VALUE"
            if attributeRow["tableValue"] == "(unchanged)" {
                cell.textField?.textColor = NSColor.systemBlue
            }
            else if attributeRow["tableValue"] == "WILL BE CLEARED" {
                cell.textField?.textColor = NSColor.systemRed
                //cell.textField?.font = NSFont.boldSystemFont(ofSize: 13.0)
            }
            else {
                cell.textField?.textColor = NSColor.controlTextColor
            }
        } else if (tableColumn?.identifier)!.rawValue == "csvIdentifier" {
            if csvIdentifierData.count > row {
                cell.textField?.stringValue = identifierDict["csvIdentifier"] ?? "NO VALUE"
                
            }
        } else if (tableColumn?.identifier)!.rawValue == "colScopes" {
    
            cell.textField?.stringValue = scopeID["scopeID"] ?? "NO VALUE"
        }
        //This cell will return while row < rows
        //print("returning cell...")
        return cell
    }
    
    // Clear Stored Values -- DO NOT DELETE
    // Although it appears to not be linked, it is tied to a menu option
    @IBAction func btnClearStored(_ sender: AnyObject) {
        //Clear all stored values
        if let bundle = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundle)
        }
    }
    
    // Change Delimiter -- DO NOT DELETE
    // Although it appears to not be linked, it is tied to a menu option
    @IBAction func btnChangeDelim(_ sender: AnyObject) {
        
        let newDelim = popPrompt().selectDelim(question: "Change Delimiter", text: "What would you like your new delimiter to be?")
        if newDelim == true {
            logMan.infoWrite(logString: "The new delimiter is comma. This delimiter will be stored to defaults.")
            delimiter = ","
            mainViewDefaults.set(delimiter, forKey: "Delimiter")
        } else {
            logMan.infoWrite(logString: "The new delimiter is semi-colon. This delimiter will be stored to defaults.")
            delimiter = ";"
            mainViewDefaults.set(delimiter, forKey: "Delimiter")
        }
    }

    
}
