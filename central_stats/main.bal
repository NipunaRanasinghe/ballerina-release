// Copyright (c) 2023, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/url;
import ballerina/os;
import ballerinax/googleapis.sheets as sheets;
import ballerina/time;

configurable string timeDuration = "24h";
configurable string SPREADSHEET_CLIENT_ID = os:getEnv("SPREADSHEET_CLIENT_ID");
configurable string SPREADSHEET_CLIENT_SECRET = os:getEnv("SPREADSHEET_CLIENT_SECRET");
configurable string SPREADSHEET_REFRESH_TOKEN = os:getEnv("SPREADSHEET_REFRESH_TOKEN");
configurable string SPREADSHEET_ID = os:getEnv("SPREADSHEET_ID");
configurable string applicationID = os:getEnv("APPLICATION_ID");
configurable string apiKey = os:getEnv("API_KEY");
const string x_api_key = "x-api-key";

time:Utc utc = time:utcNow();
time:Civil civil = time:utcToCivil(utc);
string dateOfQuery = civil.day.toString() + "/" + civil.month.toString() + "/" + civil.year.toString();

string queryPullCountOfBallerinaBallerinax = string `let mainTable_ballerina = customEvents
| where timestamp > ago(${timeDuration})
| where name == "package-pull"
| where customDimensions["organization"] == "ballerina" ;
let mainTable_ballerinax = customEvents
| where timestamp > ago(${timeDuration})
| where name == "package-pull"
| where customDimensions["organization"] == "ballerinax" ;
let ballerinaCount = mainTable_ballerina
| summarize org = "ballerina" ,Count = tostring(count()) ;
let ballerinaxCount = mainTable_ballerinax
| summarize org = "ballerinax" ,Count = tostring(count()) ;
let result = union ballerinaCount , ballerinaxCount ;
result;`;

string queryPullCountByCountry = string `let mainTable = customEvents
| where timestamp > ago(${timeDuration})
| where name == "package-pull";
let x = mainTable
| summarize Count = tostring(count()) by client_CountryOrRegion, Event = "package-pull" ;
x ;`;

string queryPushCount = string `let mainTable = customEvents
| where timestamp > ago(${timeDuration})
| where name == "package-push" ;
let x = mainTable
| summarize Count = tostring(count()) by client_CountryOrRegion, Event = "package-push" , package = tostring(customDimensions["name"]) , org = tostring(customDimensions["organization"]) ;
x ;`;

string queryDistDownloadCount = string `let mainTable = customEvents
| where timestamp > ago(${timeDuration})
| where name == "distribution-download";
let y = mainTable
| summarize Count = tostring(count()) by client_CountryOrRegion, Event = "distribution-download" , Version = tostring(customDimensions["downloadedDistVersion"]) ;
y;`;

string queryPackages = string `let mainTable = customEvents
| where timestamp > ago(${timeDuration})
| where name == "package-pull";
let x = mainTable
| summarize PullCount = tostring(count()) by tostring(customDimensions["name"]) ,  org = tostring(customDimensions["organization"])
| sort by PullCount desc;
x ;`;

sheets:ConnectionConfig spreadsheetConfig = {
    auth: {
        clientId: SPREADSHEET_CLIENT_ID,
        clientSecret: SPREADSHEET_CLIENT_SECRET,
        refreshUrl: sheets:REFRESH_URL,
        refreshToken: SPREADSHEET_REFRESH_TOKEN
    }
};

sheets:Client spreadsheetClient = check new (spreadsheetConfig);

public type HttpResponse record {
    Tables[] tables;
};

public type Tables record {
    string name;
    Column[] columns;
    string[][] rows;
};

public type Column record {
    string name;
    string 'type;
};

public function main() returns error? {
    http:Client http = check new http:Client(string `https://api.applicationinsights.io/v1/apps/${applicationID}`);

    // pull count - ballerina/ballerinax
    string encodedQuery = check url:encode(queryPullCountOfBallerinaBallerinax, "UTF-8");
    HttpResponse response = check http->/query.get({
            [x_api_key] : apiKey
        },
        query = encodedQuery
    );

    _ = check writeDataToSheet(response, spreadsheetClient, "Packages - on Pull packages count - ballerina_ballerinax");

    // pull count - country-wise
    encodedQuery = check url:encode(queryPullCountByCountry, "UTF-8");
    response = check http->/query.get({
            [x_api_key] : apiKey
        },
        query = encodedQuery
    );
    _ = check writeDataToSheet(response, spreadsheetClient, "Country-wise Count - Pull packages count");

    // push count
    encodedQuery = check url:encode(queryPushCount, "UTF-8");
    response = check http->/query.get({
            [x_api_key] : apiKey
        },
        query = encodedQuery
    );
    _ = check writeDataToSheet(response, spreadsheetClient, "Country-wise Count - Push packages count");

    // distribution download count
    encodedQuery = check url:encode(queryDistDownloadCount, "UTF-8");
    response = check http->/query.get({
            [x_api_key] : apiKey
        },
        query = encodedQuery
    );
    _ = check writeDataToSheet(response, spreadsheetClient, "Country-wise Count - Distribution download count");

    // packages - pull count
    encodedQuery = check url:encode(queryPackages, "UTF-8");
    response = check http->/query.get({
            [x_api_key] : apiKey
        },
        query = encodedQuery
    );
    _ = check writeDataToSheet(response, spreadsheetClient, "Packages - on Pull packages count");

}

# Description of the function.
#
# + response - Response of the http request
# + spreadsheetClient - spreadsheetClient configured
# + sheetName - name of the sheet needed to be created
# + return - Rows to be inserted to the excel sheet
#
public function writeDataToSheet(HttpResponse response, sheets:Client spreadsheetClient, string sheetName) returns error? {

    string[][] excelRows = [];
    foreach string[] row in response.tables[0].rows {
        row.push(dateOfQuery);
        excelRows.push(row);
    }

    sheets:A1Range a1Range = {
        sheetName: sheetName
    };
    foreach string[] values in excelRows {
        _ = check spreadsheetClient->appendValue(SPREADSHEET_ID, values, a1Range);
    }
}
