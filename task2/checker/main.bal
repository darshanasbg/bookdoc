import ballerina/http;
import wso2/choreo.sendemail;
import ballerina/io;
import ballerina/mime;
import ballerina/task;
import ballerina/lang.runtime;
import ballerina/time;
// import thisarug/prettify;

configurable string ENDPOINT_URL = ?;
configurable string key = ?;
configurable string email = ?;
configurable string doc = ?;
configurable string[] hospitals = ?;

// Create http client
http:Client httpclient = check new (ENDPOINT_URL);
// Create a new email client
sendemail:Client emailClient = check new ();

public function main() returns error? {

    // Schedules the tasks to execute the job every second.
    task:JobId id1 = check task:scheduleJobRecurByFrequency(
                            new AppintmentJob(0, "1st Job"), 60);

    // Waits for 30 seconds.
    runtime:sleep(60000);

    // Unschedules the jobs.
    check task:unscheduleJob(id1);
}

// Creates a job to be executed by the scheduler.
class AppintmentJob {

    *task:Job;
    int i = 1;
    string jobIdentifier;

    // Executes this function when the scheduled trigger fires.
    public function execute() {
        self.i += 1;
        // io:println(self.jobIdentifier + ", MyCounter: ", self.i);

        do {
            // io:println("Doc: " + doc);
            // io:println("Hospitals: " + hospitals.toString());

	        Appointment[] aList = check getAppointments(doc, hospitals);

            // string atable1 = generateFullAppoinmentTable(aList);
            // io:println("Full Appoinment Table: \n", atable1);

            string atable2 = generateAvailableAppoinmentTable(aList, "AVAILABLE");

            if (atable2.length()>0) {
                io:println("Availble Appoinment Table: \n", atable2);

                string emailSubject = "Open Appoinments";
                string emailcontent = atable2;

                string _ = check emailClient->sendEmail(email, emailSubject, emailcontent);
                io:println("Successfully sent the email.");
            } else {
                time:Utc currentUtc = time:utcNow();
                time:Civil civil1 = time:utcToCivil(currentUtc);
                string emailString = check time:civilToEmailString(civil1, time:PREFER_TIME_ABBREV);
                // time:Zone? zone = time:getZone("Asia/Colombo");
                io:println(emailString + ": No Availble Appoinments");
            }
        } on fail var e {
        	io:println("Error occured: " + e.toString());
        }
    }

    isolated function init(int i, string jobIdentifier) {
        self.i = i;
        self.jobIdentifier = jobIdentifier;
    }
}

function getAppointments(string doc, string[] hospitals) returns Appointment[]|error {
    Appointment[] aList = [];

    foreach var hospital in hospitals {
        // Call API and get data
        json jsonResponse = check getData(doc, hospital);

        if (jsonResponse != null) {
            // Convert the json payload to a AppointmentList
            Appointment[] appointments = check convert(jsonResponse);
            foreach var arecord in appointments {
                aList.push(arecord);
            }
        }
    }

    return aList;
}

function getData(string docCode, string hosCode) returns json|error {
        http:Response hresponse = check httpclient->/doctorSessions.post({
        doctorNo: docCode,
        hosCode: hosCode,
        specializationId: "1",
        page: "0",
        offset: "0",
        appDate: "",
        price: ""
    }, {
        "x-ibm-client-id": key
    }, mime:APPLICATION_JSON);
    json jsonResponse = check hresponse.getJsonPayload();

    // string prettified = prettify:prettify(jsonResponse);
    // io:println(prettified);
    // io:println(jsonResponse.toString());

    return jsonResponse;
}

// function to convert jsonresponse to appointment reocrd list
function convert(json jsonResp) returns Appointment[]|error {

    Appointment[] aList = [];
    
        // Iterate through the JSON array
        if (jsonResp is json[]) {
            foreach var item in jsonResp {
                // Access properties of the JSON object
                Appointment appointment = {
                    appDate: check item.appDate,
                    remark: check item.remark,
                    hosname: check item.hosname,
                    amount: check item.amount,
                    tday: check item.tday,
                    ttime: check item.ttime,
                    maxPNo: check item.maxPNo
                };
                aList.push(appointment);
            }
        } else {
            // Handle the error
            io:println("Error: Not a JSON array");
        }
    
    // io:println("Converted the json payload to a Appointment Record List.");
    return aList;
}

function generateFullAppoinmentTable(Appointment[] appoinmentRecords) returns string {
    // Define the table header
    string[] columns = ["Date     ", "Day    ", "Time    ", "Hospital               ", "Number", "Amount", "Status"];
    string separator = " | ";
    string atable = separator;

    // Add the table header
    foreach var column in columns {
        atable = atable + column + separator;
    }
    atable = atable + "\n";
    
    // Add the table body
    foreach var arecord in appoinmentRecords {
        atable += separator
        + arecord.appDate + separator
        + arecord.tday + separator
        + arecord.ttime + separator
        + arecord.hosname + separator
        + arecord.maxPNo + separator
        + arecord.amount.toString() + separator
        + arecord.remark + separator
        + "\n";
    }
    // Add the table footer
    atable = atable + "\n";
    return atable;
}

function generateAvailableAppoinmentTable(Appointment[] appoinmentRecords, string status) returns string {
    // Define the table header
    string[] columns = ["Date      ", "Day   ", "Time  ", "Hospital                       ", "Num", "Amount", "Status"];
    string separator = " | ";
    string atable = separator;

    // Add the table header
    foreach var column in columns {
        atable = atable + column + separator;
    }
    atable = atable + "\n";
    
    // Add the table body
    boolean isAppointmentAvailable = false;
    foreach var arecord in appoinmentRecords {
        if(arecord.remark.equalsIgnoreCaseAscii(status)) {
            isAppointmentAvailable = true;

            atable += separator
            + arecord.appDate + separator
            + arecord.tday + separator
            + arecord.ttime + separator
            + arecord.hosname + separator
            + arecord.maxPNo + separator
            + arecord.amount.toString() + separator
            + arecord.remark + separator
            + "\n";
        }
    }
    // Add the table footer
    atable = atable + "\n";

    if (isAppointmentAvailable) {
        return atable;
    } else {
        return "";
    } 
}