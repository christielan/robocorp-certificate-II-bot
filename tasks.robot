*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.Browser.Selenium    auto_close=${FALSE}
Library             SeleniumLibrary
Library             RPA.Tables
Library             RPA.HTTP
Library             RPA.PDF
Library             RPA.Archive
Library             RPA.FileSystem
Library             RPA.Dialogs
Library             RPA.Robocorp.Vault

Suite Teardown      Cleaup


*** Variables ***
${EXCEL_FILE_NAME}      orders.csv

${out_dir}              ${CURDIR}${/}output
${screenshot_dir}       ${out_dir}${/}screenshots
${receipt_dir}          ${out_dir}${/}receipts


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Open the robot order website
    ${orders}=    Get orders
    Log    ${orders}
    FOR    ${row}    IN    @{orders}
        Close the annoying modal
        Fill the form    ${row}
        Preview the robot
        Wait Until Keyword Succeeds    5x    0.5s    Submit the order
        ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
        Go to order another robot
    END
    Create a ZIP file of the receipts


*** Keywords ***
Open the robot order website
    Open Available Browser    https://robotsparebinindustries.com/#/robot-order

Ask user for CSV path
    RPA.Dialogs.Add heading    Insert URL for downloading CSV
    RPA.Dialogs.Add text input    URL for downloading CSV file    placeholder=Insert URL here
    ${url}=    RPA.Dialogs.Run Dialog
    # https://robotsparebinindustries.com/orders.csv
    RETURN    ${url}[URL for downloading CSV file]

Get orders
    [Documentation]    download order file and return csv file contents
    ${excel_file_url}=    RPA.Robocorp.Vault.Get Secret    url
    Log    ${excel_file_url}[order_page_url]
    RPA.HTTP.Download    ${excel_file_url}[order_page_url]    overwrite=True
    ${orders}=    RPA.Tables.Read table from CSV    ${EXCEL_FILE_NAME}
    RETURN    ${orders}

Close the annoying modal
    RPA.Browser.Selenium.Click Element    css:button.btn.btn-danger

Fill the form
    [Arguments]    ${row}
    # head (select from drop down)
    RPA.Browser.Selenium.Wait Until Element Is Visible    id:head
    RPA.Browser.Selenium.Select From List By Index    id:head    ${row}[Head]
    # body (select from input)
    RPA.Browser.Selenium.Click Element    id:id-body-${row}[Body]
    # leg (enter number)
    RPA.Browser.Selenium.Input Text    css:input[placeholder="Enter the part number for the legs"]    ${row}[Legs]
    # shipping
    RPA.Browser.Selenium.Input Text    id:address    ${row}[Address]

Preview the robot
    RPA.Browser.Selenium.Click Button    id:preview

Submit the order
    RPA.Browser.Selenium.Click Button    id:order
    # handle task failure
    RPA.Browser.Selenium.Wait Until Element Is Visible    id:receipt

Store the receipt as a PDF file
    [Arguments]    ${order_number}
    ${receipt_html}=    RPA.Browser.Selenium.Get Element Attribute    id:receipt    outerHTML
    ${receipt_pdf_path}=    Set Variable    ${receipt_dir}${/}receipt-${order_number}.pdf
    RPA.PDF.Html To Pdf    ${receipt_html}    ${receipt_pdf_path}
    RETURN    ${receipt_pdf_path}

Take a screenshot of the robot
    [Arguments]    ${order_number}
    ${receipt_screenshot_path}=    Set Variable    ${screenshot_dir}${/}robot-preview-${order_number}.png
    RPA.Browser.Selenium.Screenshot    id:robot-preview-image    ${receipt_screenshot_path}
    RETURN    ${receipt_screenshot_path}

Embed the robot screenshot to the receipt PDF file
    [Arguments]    ${screenshot}    ${pdf}
    RPA.PDF.Open Pdf    ${pdf}
    ${screenshot}=    Create List    ${screenshot}
    RPA.PDF.Add Files To Pdf    ${screenshot}    ${pdf}    append=True
    RPA.PDF.Close Pdf    ${pdf}

Go to order another robot
    RPA.Browser.Selenium.Click Button    id:order-another

Create a ZIP file of the receipts
    ${zip_file_name}=    Set Variable    ${OUTPUT_DIR}${/}all_receipts.zip
    RPA.Archive.Archive Folder With Zip    ${OUTPUT_DIR}${/}receipts    ${zip_file_name}

Cleaup
    RPA.Browser.Selenium.Close Browser
    RPA.FileSystem.Remove Directory    ${screenshot_dir}    recursive=True
    RPA.FileSystem.Remove Directory    ${receipt_dir}    recursive=True
