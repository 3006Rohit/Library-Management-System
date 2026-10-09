$ErrorActionPreference = 'Stop'
$org = 'library-org'
$workbookPath = Join-Path $PSScriptRoot '..\Salesforce_Library_Demo_Data_100_Books.xlsx'
$outDir = Join-Path $PSScriptRoot '..\.tmp-library-import'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Invoke-SfQuery([string]$query) {
    $raw = & sf data query --target-org $org --query $query --result-format json
    return (($raw -join "`n") | ConvertFrom-Json).result.records
}

function Export-SheetRows($sheetName) {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $book = $excel.Workbooks.Open((Resolve-Path $workbookPath))
    try {
        $sheet = $book.Worksheets.Item($sheetName)
        $used = $sheet.UsedRange
        $headers = for ($c = 1; $c -le $used.Columns.Count; $c++) { $sheet.Cells.Item(1,$c).Text }
        $rows = @()
        for ($r = 2; $r -le $used.Rows.Count; $r++) {
            $item = [ordered]@{}
            for ($c = 1; $c -le $headers.Count; $c++) { $item[$headers[$c-1]] = $sheet.Cells.Item($r,$c).Text }
            $rows += [PSCustomObject]$item
        }
        return $rows
    } finally { $book.Close($false); $excel.Quit() }
}

function Run-BulkImport([string]$objectName, [string]$filePath) {
    if (-not (Test-Path $filePath)) { return }
    $result = & sf data import bulk --target-org $org --sobject $objectName --file $filePath --line-ending CRLF --wait 10 --json
    $json = (($result -join "`n") | ConvertFrom-Json)
    if ($LASTEXITCODE -ne 0 -or $json.status -ne 0) { throw "Bulk import failed for ${objectName}: $($result -join "`n")" }
    Write-Host "Imported $objectName from $([IO.Path]::GetFileName($filePath))"
}

function Run-BulkUpsert([string]$objectName, [string]$filePath, [string]$externalId) {
    if (-not (Test-Path $filePath)) { return }
    $result = & sf data upsert bulk --target-org $org --sobject $objectName --external-id $externalId --file $filePath --line-ending CRLF --wait 10 --json
    $json = (($result -join "`n") | ConvertFrom-Json)
    if ($LASTEXITCODE -ne 0 -or $json.status -ne 0) { throw "Bulk upsert failed for ${objectName}: $($result -join "`n")" }
    Write-Host "Upserted $objectName from $([IO.Path]::GetFileName($filePath))"
}

$authors = Export-SheetRows 'Authors'
$categories = Export-SheetRows 'Categories'
$books = Export-SheetRows 'Books'
$authorLinks = Export-SheetRows 'Book_Author_Links'
$categoryLinks = Export-SheetRows 'Book_Category_Links'
$copies = Export-SheetRows 'Book_Copies'

$existingAuthors = @(Invoke-SfQuery 'SELECT Id,Name FROM Author__c')
$existingAuthorNames = @{}; foreach ($r in $existingAuthors) { $existingAuthorNames[$r.Name] = $r.Id }
$newAuthors = $authors | Where-Object { -not $existingAuthorNames.ContainsKey($_.Author_Name) } | ForEach-Object { [PSCustomObject]@{Name=$_.Author_Name;Country__c=$_.Country} }
if ($newAuthors.Count) { $newAuthors | Export-Csv (Join-Path $outDir 'authors.csv') -NoTypeInformation -Encoding UTF8; Run-BulkImport 'Author__c' (Join-Path $outDir 'authors.csv') }

$existingCategories = @(Invoke-SfQuery 'SELECT Id,Name FROM Book_Category__c')
$existingCategoryNames = @{}; foreach ($r in $existingCategories) { $existingCategoryNames[$r.Name] = $r.Id }
$newCategories = $categories | Where-Object { -not $existingCategoryNames.ContainsKey($_.Category_Name) } | ForEach-Object { [PSCustomObject]@{Name=$_.Category_Name;Description__c=$_.Description;Active__c=($_.Active -eq 'TRUE' -or $_.Active -eq 'true')} }
if ($newCategories.Count) { $newCategories | Export-Csv (Join-Path $outDir 'categories.csv') -NoTypeInformation -Encoding UTF8; Run-BulkImport 'Book_Category__c' (Join-Path $outDir 'categories.csv') }

$existingAuthors = @(Invoke-SfQuery 'SELECT Id,Name FROM Author__c')
$authorIds = @{}; foreach ($r in $existingAuthors) { $authorIds[$r.Name] = $r.Id }
$existingCategories = @(Invoke-SfQuery 'SELECT Id,Name FROM Book_Category__c')
$categoryIds = @{}; foreach ($r in $existingCategories) { $categoryIds[$r.Name] = $r.Id }

$bookRows = $books | ForEach-Object { [PSCustomObject]@{
    Name=$_.Title; ISBN__c=$_.ISBN; Publisher__c=$_.Publisher; Publication_Year__c=$_.Publication_Year; Edition__c=$_.Edition; Language__c=$_.Language; Description__c=$_.Description; Cover_Image_URL__c=$_.Cover_Image_URL; Status__c=$_.Status; Total_Copies__c=$_.Total_Copies; Available_Copies__c=$_.Available_Copies
} }
$bookRows | Export-Csv (Join-Path $outDir 'books.csv') -NoTypeInformation -Encoding UTF8
Run-BulkImport 'Book__c' (Join-Path $outDir 'books.csv')

$isbnList = ($books | ForEach-Object { "'" + $_.ISBN.Replace("'", "\\'") + "'" }) -join ','
$bookRecords = @(Invoke-SfQuery "SELECT Id,ISBN__c FROM Book__c WHERE ISBN__c IN ($isbnList)")
$bookIds = @{}; foreach ($r in $bookRecords) { $bookIds[$r.ISBN__c] = $r.Id }

$existingAuthorLinks = @(Invoke-SfQuery 'SELECT Book__c,Author__c FROM Book_Author__c')
$authorLinkKeys = @{}; foreach ($r in $existingAuthorLinks) { $authorLinkKeys["$($r.Book__c)|$($r.Author__c)"] = $true }
$newAuthorLinks = foreach ($row in $authorLinks) { $key = "$($bookIds[$row.Book_ISBN])|$($authorIds[$row.Author_Name])"; if ($bookIds.ContainsKey($row.Book_ISBN) -and $authorIds.ContainsKey($row.Author_Name) -and -not $authorLinkKeys.ContainsKey($key)) { [PSCustomObject]@{Book__c=$bookIds[$row.Book_ISBN];Author__c=$authorIds[$row.Author_Name];Author_Order__c=$row.Author_Order} } }
if (@($newAuthorLinks).Count) { $newAuthorLinks | Export-Csv (Join-Path $outDir 'book-author-links.csv') -NoTypeInformation -Encoding UTF8; Run-BulkImport 'Book_Author__c' (Join-Path $outDir 'book-author-links.csv') }

$existingCategoryLinks = @(Invoke-SfQuery 'SELECT Book__c,Book_Category__c FROM Book_Category_Link__c')
$categoryLinkKeys = @{}; foreach ($r in $existingCategoryLinks) { $categoryLinkKeys["$($r.Book__c)|$($r.Book_Category__c)"] = $true }
$newCategoryLinks = foreach ($row in $categoryLinks) { $key = "$($bookIds[$row.Book_ISBN])|$($categoryIds[$row.Category_Name])"; if ($bookIds.ContainsKey($row.Book_ISBN) -and $categoryIds.ContainsKey($row.Category_Name) -and -not $categoryLinkKeys.ContainsKey($key)) { [PSCustomObject]@{Book__c=$bookIds[$row.Book_ISBN];Book_Category__c=$categoryIds[$row.Category_Name]} } }
if (@($newCategoryLinks).Count) { $newCategoryLinks | Export-Csv (Join-Path $outDir 'book-category-links.csv') -NoTypeInformation -Encoding UTF8; Run-BulkImport 'Book_Category_Link__c' (Join-Path $outDir 'book-category-links.csv') }

$copyRows = $copies | ForEach-Object { [PSCustomObject]@{Book__c=$bookIds[$_.Book_ISBN];Barcode__c=$_.Barcode;Status__c=$_.Status;Shelf_Location__c=$_.Shelf_Location;Acquisition_Date__c=$_.Acquisition_Date;Condition__c=$_.Condition;Price__c=$_.Price} }
$copyRows | Export-Csv (Join-Path $outDir 'book-copies.csv') -NoTypeInformation -Encoding UTF8
Run-BulkUpsert 'Book_Copy__c' (Join-Path $outDir 'book-copies.csv') 'Barcode__c'

Write-Host 'Library workbook import completed.'
