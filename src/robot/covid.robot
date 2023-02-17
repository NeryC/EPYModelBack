*** Settings ***
Library           SeleniumLibrary
Library           OperatingSystem
Library           BuiltIn
Library           WebElement.py

*** Variables ***
${BROWSER}        ff
${URL}            https://public.tableau.com/app/profile/mspbs/viz/COVID19PY-Registros/Descargardatos
${DOWNLOAD_DIR}   ${CURDIR}${/}..${/}..${/}public${/}rawData


*** Test Cases ***
Registro Diario
    ${profile}=    create_ff_profile    ${DOWNLOAD_DIR}
    Open Browser    ${URL}    ${BROWSER}    ff_profile_dir=${profile}
    Sleep    5s
    Wait Until Element Is Enabled    //*[@id="root"]/div/footer/div[1]/div/div/div/div
    Click Element    //*[@id="root"]/div/footer/div[1]/div/div/div/div
    Sleep    5s
    Wait Until Element Is Enabled    //*[@id="root"]/div/footer/div[1]/div/div/div/ul/li[4]
    Click Element    //*[@id="root"]/div/footer/div[1]/div/div/div/ul/li[4]
    Sleep    35s

    Wait Until Element Is Enabled    //*[@id="root"]/div/header
    Click Element    //*[@id="root"]/div/header
    Sleep    10s

    Select Frame    //iframe[@allowtransparency='true']
    Sleep    20s
    Click Element    //*[@id="dijit_layout_LayoutContainer_0"]/div/div[2]
    Unselect Frame
    Sleep    15s
    Wait Until Element Is Enabled    //i[@id='downloadIcon']
    Click Element    //i[@id='downloadIcon']
    Sleep    15s
    Select Frame    //div[@id='embedded-viz-wrapper']//iframe
    Click Element    //div[@id='DownloadDialog-Dialog-Body-Id']//button[2]
    Sleep    15s
    Switch Window    new
    Click Element    //div[@id='Migrated Data']
    Sleep    10s
    Click Element    //button[@data-tb-test-id="download-data-Button"]

Fallecidos
    ${profile}=    create_ff_profile    ${DOWNLOAD_DIR}
    Open Browser    ${URL}    ${BROWSER}    ff_profile_dir=${profile}
    Sleep    5s
    Wait Until Element Is Enabled    //*[@id="root"]/div/footer/div[1]/div/div/div/div
    Click Element    //*[@id="root"]/div/footer/div[1]/div/div/div/div
    Sleep    5s
    Wait Until Element Is Enabled    //*[@id="root"]/div/footer/div[1]/div/div/div/ul/li[4]
    Click Element    //*[@id="root"]/div/footer/div[1]/div/div/div/ul/li[4]
    Sleep    35s

    Wait Until Element Is Enabled    //*[@id="root"]/div/header
    Click Element    //*[@id="root"]/div/header
    Sleep    10s

    Select Frame    //iframe[@allowtransparency='true']
    Sleep    20s
    Click Element    (//div[@class='dijitTabInnerDiv'])[4]
    Unselect Frame
    Sleep    15s
    Wait Until Element Is Enabled    //i[@id='downloadIcon']
    Click Element    //i[@id='downloadIcon']
    Sleep    15s
    Select Frame    //div[@id='embedded-viz-wrapper']//iframe
    Click Element    //div[@id='DownloadDialog-Dialog-Body-Id']//button[2]
    Sleep    15s
    Switch Window    new
    Click Element    //div[@id='Migrated Data']
    Sleep    10s
    Click Element    //button[@data-tb-test-id="download-data-Button"]

Descargar Datos
    ${profile}=    create_ff_profile    ${DOWNLOAD_DIR}
    Open Browser    ${URL}    ${BROWSER}    ff_profile_dir=${profile}
    Sleep    5s
    Wait Until Element Is Enabled    //*[@id="root"]/div/footer/div[1]/div/div/div/div
    Click Element    //*[@id="root"]/div/footer/div[1]/div/div/div/div
    Sleep    5s
    Wait Until Element Is Enabled    //*[@id="root"]/div/footer/div[1]/div/div/div/ul/li[4]
    Click Element    //*[@id="root"]/div/footer/div[1]/div/div/div/ul/li[4]
    Sleep    30s

    Wait Until Element Is Enabled    //*[@id="root"]/div/footer
    Click Element    //*[@id="root"]/div/footer
    Sleep    10s

    Wait Until Element Is Enabled    //i[@id='downloadIcon']
    Click Element    //i[@id='downloadIcon']
    Sleep    15s
    Select Frame    //div[@id='embedded-viz-wrapper']//iframe
    Click Element    //div[@id='DownloadDialog-Dialog-Body-Id']//button[2]
    Sleep    15s
    Switch Window    new
    Click Element    //div[@id='Migrated Data']
    Sleep    10s
    Click Element    //button[@data-tb-test-id="download-data-Button"]

End
    ${profile}=    create_ff_profile    ${DOWNLOAD_DIR}
    Open Browser    http://google.com    ${BROWSER}    ff_profile_dir=${profile}