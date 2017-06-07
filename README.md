# Write-Log
Logging cmdlet framework for PowerShell  

Personally, I find that logging is underestimated for Microsoft scripting languages. During the design and creation of a script (or cmdlet) logging comes in handy but when the script gets deployed and something goes wrong you often wish that you had an even better logging in place.  
That is why I think that scripting languages as PowerShell (as well as its predecessor VBScript) should actually come with (better) native logging capabilities than what is available now.

*No interests in reading the whole background? Just jump to the **Usage** section.*

Best practice
-------------

Even before PowerShell existed, I had a similar need for a adequate logging function in VBScript. As a matter of fact, some of the concepts I was using for VBScript, I am still using in PowerShell. Meanwhile, I have extended my logging solution with a whole list of improvements and requirements I expect a `Write-Log` cmdlet to fulfill:

 - Robust and never cause the actual cmdlet to fail unexpectedly (even  
   when e.g. the access to the log file is for some reason denied)

 - The syntax should be simple to invoke and possibly be used as a   
   `Write-Host` command replacement

 - Except all data types and reveal the content

 - Capture unexpected native script errors

 - Inline pass-through to minimize additional code lines just for logging

 - An accurate (10ms) timestamp per entry for performance trouble   
   shooting

 - Standard troubleshooting information like:

  - Script version

  - PowerShell version

  - When it was ran (process start time)

  - How (parameters) and from where (location) it was ran

 - Information should be appended to a configurable log file which not grow indefinitely

 - Downwards compatible with PowerShell version 2

Robust
------

If you want to go for a robust logging solution, you probably want to go with the native Start-Transcript cmdlet but you will probably find out that the  `Start-Transcript` lacks features, like timestamps, that you might expect from a proper logging cmdlet. You could go for a 3rd party solution but this usually means extra installation procedures and dependencies.  
So you decide to write it yourself but even the simplest solution where you just write information to a file might already cause an issue in the field: the file might not be accessible. It might even exist but your script is triggered twice and multiple instances run at the same time the log file might be open by one of instances and access is denied from the other instance  (see e.g.: https://stackoverflow.com/questions/5548283/powershell-scheduled-tasks-conflicts). And just at this point, logging should actually help you to troubleshoot what is going on as a repetitive trigger might also cause unexpected behavior in the script itself. For this particular example, the solution I present here buffers the output until it is able to write. But there are a lot more traps in writing a Write-Log cmdlet and correctly formatting the output.

Syntax
------

The syntax of the Write-Log cmdlet is similar to the native Write-Host command. This means that every unnamed argument is displayed and logged and as with the native Write-Host command the arguments are simply separated by a space and named arguments can be placed at the start and end (or even in between). To give you an idea, this is a valid syntax (just as in `Write-Host`):

    Write-Log "Information is separated with a space" and named arguments -Color:Yellow "can be placed anywhere"

*Note:* as in the above example commented text doesn't have to be quoted but it is recommended.

*Btw.* this is not so obvious to achieve as you might expect. The [only full solution][1] I found for this caused me some downvotes ☹. The drawback of this solution is that the unnamed arguments are limited, in the `Write-Log` case to 10 arguments which I think should be enough taken the smart data revealing in account *(you can always use commas which presents it in an array or modify the purposed Write-Log cmdlet)*.

Data revealing
--------------

For logging, I would expect specific value and object information to be conclusive, meaning that that the type, value and layout should be clear which is clearly not the case for the with the native Write-Host command. Try this:

    Write-Host $NotSet
    Write-Host ""
    Write-Host @()
    Write-Host @("")
    Write-Host @($Null)
    Write-Host @(@())
    Write-Host @(@(), @())

All the above commands have the same result (*nothing* is actually shown), yet there is a big difference in respect to the values and their types. E.g. if you try to invoke a method on the `$NotSet` (`$Null`, any variable that has not be set) value, it immediately results in an error which is not the case for the rest of the values. Besides a string has different properties then an array.
Also showing other values with Write-Host often do not reveal the potential cause of a script failure, take e.g.:

    Write-Host @("Zero", @("One", "Two"), "Three", "Four")

The above command simply results in: `Zero One Two Three Four`. Apart from the fact that this doesn’t reveal that is concerns something else then a string, it doesn’t show that it concerns an recursive array as well. This might not be a big deal if you enumerate it with a `ForEach` loop but might give you a complete different result as expected if you try to index the specific items (the third `[3]` item equals `Four` in this example). And then there is another PowerShell behavior that you might want to clear up: if it concerns an array with one single array embedded, it will be flatten automatically, meaning that `@(@("Test")")` is simplified to: `@("Test")`. In other words, it is quiet important that get a good view of this when you deal with arrays and items that are left in the pipeline by a function.
Hashtables are even worse:

    Write-Host @{one = 1; two = 2; three = 3}

This results in: `System.Collections.DictionaryEntry System.Collections.DictionaryEntry System.Collections.DictionaryEntry`, a mouth full but close to useless. 
And almost the same goes for (complex) objects, such as:

    Write-Host ([ADSI]"WinNT://./$Env:Username")

Knowing that the `Start-Transcript` creates a record of all or part of a Windows PowerShell session to a text file it is completely depended on the questionable `Write-Host` output. The good thing is although that it also captures any unexpected native errors which is commonly not done automatically in any custom `Write-Log` cmdlet. 

Native Errors
-------------

In the solution below, native errors are checked each time something is logged so that you can get an idea of where the error occurred during the process

Inline logging
--------------

With most custom solutions you might have to add additional lines if you want to describe and log the actual value:

    $FullName = ([ADSI]"WinNT://./$Env:Username").FullName
    Log "Full name:" $FullName

With the solution purposed below you can add a questionmark (`?`) after a value which will be returned for further use:

    $FullName = Log "Full name:" ([ADSI]"WinNT://./$Env:Username").FullName ?

Another inline logging example:	

    $LCID = Log "LCID" $Host.CurrentCulture.Parent.Parent.LCID ? "is used for" $Host.UI.RawUI.WindowTitle

Timestamp
---------

To debug performance issues, a timestamp with a accurate of 10ms is preceded in every entry you log:

    13:05:30.58	Full name test: John Doe
    13:05:30.60	LCID 127 is used for Windows PowerShell

*Note:* Multiline entries, containing linefeeds and carriage returns, are only preceded with a timestamp in the first line, the rest is nicely aligned with the current indent.)

Standard info
-------------

Each time you start a new session the following information is captured automatically:

    2017-05-24	Write-Log (version: 00.01.01, PowerShell version: 5.1.14393.1198)
    18:55:44.78	C:\Users\user\Write-Log\Write-Log.ps1 arguments

Where:
======

 - **2017-05-24** is the date the script is used
 - **Write-Log** is the bare name of the script
 - **version: 00.01.01** is the version of the script retrieved from the
   header info (see framework)
 - **PowerShell version: 5.1.14393.1198** is the actual PowerShell version
 - **18:55:44.78** is the time that the script process is started (and not
   the first time the Write-Log cmdlet is invoked)
 - **C:\Users\user\Write-Log\Write-Log.ps1** is the path from where the
   script is launched
 - **Arguments** any arguments that are supplied with the script

*Note:* As the first time entry is the process start time, you might notice that Windows takes quiet some additional time (depending on the internet access) before you script actually starts when it is signed.

Filing
------

By default log file resides at the location `%Temp%\<ScriptName>.log`.  
Under a user account this is normally: `C:\Users\<user>\AppData\Local\Temp\<ScriptName>.log`.  
Under the System account this is normally: `C:\Windows\Temp\<ScriptName>.log`.  
I considering this the best default place considering that log files might contain security and private information but you can always overrule the file location with the `-File` argument.
Every time a new script session is started, a separator (by default an empty line) is added followed by the standard info described above and each `Write-Log` entry is appended accordingly. 
If the size of the log file reaches more than **100k** (by default), the top session is removed so that it will at least contain the last session and never grow indefinitely.

Write-Log
---------

I have put the whole solution in a framework consisting of 3 major parts:

 1. Some definitions to store script directives (including script header
    info) in an easy accessible `My` object as e.g. `My.Version`.
 2. A cmdlet called `ConvertTo-Text` (alias `CText`) to reveal values and
    objects. This cmdlet is in fact a simplified version of the [PSON][2]
    solution I wrote (focused on revealing information rather that storing it).
 3. The actual `Write-Log` (alias `Log`) engine.

Usage
-----
Copy the above framework and insert your script into the `Main {}` function.  
Everywhere you would like to display and log information, use the `Log` command (similar to the `Write-Host` command syntax).  
Check the log file at: `%Temp%\<ScriptName>.Log`

Log File
--------

The above logging examples result in the following log file (`C:\Users\<user>\AppData\Local\Temp\<ScriptName>.log`):

<!-- language: lang-none -->

    2017-05-31	Write-Log (version: 01.00.02, PowerShell version: 5.1.14393.1198)
    13:00:49.00	C:\Users\User\PowerShell\Write-Log\Write-Log.ps1 
    13:00:49.71	Examples:
    13:00:49.72	Not set (null): $Null
    13:00:49.72	Empty string:
    13:00:49.73	If you want to quote a bare string, consider using CText: ""
    13:00:49.74	An empty array: @()
    13:00:49.74	An empty array embedded in another array: @() Note that PowerShell (and not Write-Log) flattens this.
    13:00:49.75	Two empty arrays embedded in another array: @(@(), @())
    13:00:49.76	An null in an empty array: @($Null)
    13:00:49.77	A hashtable: @{one = 1, three = 3, two = 2}
    13:00:49.78	A recursive hashtable: @{
               		one = @{
               			one = @{
               				one = 1, 
               				three = 3, 
               				two = 2
               			}, 
               			three = 3, 
               			two = 2
               		}, 
               		three = 3, 
               		two = 2
               	}
    13:00:49.79	The array @("One", "Two", "Three") is stored in $Numbers
    13:00:49.80	A hashtable in an array: @(@{one = 1, three = 3, two = 2})
    13:00:49.81	Character array: @(H, a, l, l, o,  , W, o, r, l, d)
    13:00:51.66	WinNT user object: {UserFlags: 66049, MaxStorage: -1, PasswordAge: 245487, PasswordExpired: 0, LoginHours: System.Byte[], FullName: John Doe, Description: , BadPasswordAttempts: 0, HomeDirectory: , LoginScript: , Profile: , HomeDirDrive: , Parameters: , PrimaryGroupID: 513, Name: DoeJ, MinPasswordLength: 0, MaxPasswordAge: 3628800, MinPasswordAge: 0, PasswordHistoryLength: 0, AutoUnlockInterval: 1800, LockoutObservationInterval: 1800, MaxBadPasswordsAllowed: 0, objectSid: System.Byte[], AuthenticationType: Secure, Children: @{}, Guid: "{D83F1060-1E71-11CF-B1F3-02608C9E7553}", ObjectSecurity: $Null, NativeGuid: "{D83F1060-1E71-11CF-B1F3-02608C9E7553}", NativeObject: {}, Parent: "WinNT://WORKGROUP/.", Password: $Null, Path: "WinNT://./doej", Properties: @{UserFlags = 66049, MaxStorage = -1, PasswordAge = 245487, PasswordExpired = 0, LoginHours = System.Byte[], FullName = John Doe, Description = , BadPasswordAttempts = 0, HomeDirectory = , LoginScript = , Profile = , HomeDirDrive = , Parameters = , PrimaryGroupID = 513, Name = doej, MinPasswordLength = 0, MaxPasswordAge = 3628800, MinPasswordAge = 0, PasswordHistoryLength = 0, AutoUnlockInterval = 1800, LockoutObservationInterval = 1800, MaxBadPasswordsAllowed = 0, objectSid = System.Byte[]}, SchemaClassName: "User", SchemaEntry: {AuthenticationType: $Null, Children: $Null, Guid: $Null, ObjectSecurity: $Null, Name: $Null, NativeGuid: $Null, NativeObject: $Null, Parent: $Null, Password: $Null, Path: $Null, Properties: $Null, SchemaClassName: $Null, SchemaEntry: $Null, UsePropertyCache: $Null, Username: $Null, Options: $Null, Site: $Null, Container: $Null}, UsePropertyCache: $True, Username: $Null, Options: $Null, Site: $Null, Container: $Null}
    13:00:51.70	Volatile Environment: {
               		Property: @(
               			"LOGONSERVER", 
               			"USERDOMAIN", 
               			"USERNAME", 
               			"USERPROFILE", 
               			"HOMEPATH", 
               			"HOMEDRIVE", 
               			"APPDATA", 
               			"LOCALAPPDATA", 
               			"USERDOMAIN_ROAMINGPROFILE"
               		), 
               		PSPath: "Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Volatile Environment", 
               		PSParentPath: "Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER", 
               		PSChildName: "Volatile Environment", 
               		PSDrive: {
               			Used: $Null, 
               			Free: $Null, 
               			CurrentLocation: "", 
               			Name: "HKCU", 
               			Provider: [ProviderInfo]..., 
               			Root: "HKEY_CURRENT_USER", 
               			Description: "The software settings for the current user", 
               			MaximumSize: $Null, 
               			Credential: [PSCredential]..., 
               			DisplayRoot: $Null
               		}, 
               		PSProvider: {
               			ImplementingType: [RuntimeType]..., 
               			HelpFile: "System.Management.Automation.dll-Help.xml", 
               			Name: "Registry", 
               			PSSnapIn: [PSSnapInInfo]..., 
               			ModuleName: "Microsoft.PowerShell.Core", 
               			Module: $Null, 
               			Description: "", 
               			Capabilities: ShouldProcess, Transactions, 
               			Home: "", 
               			Drives: [Collection`1]...
               		}, 
               		PSIsContainer: $True, 
               		SubKeyCount: 1, 
               		View: Default, 
               		Handle: {
               			IsInvalid: $False, 
               			IsClosed: $False
               		}, 
               		ValueCount: 9, 
               		Name: "HKEY_CURRENT_USER\Volatile Environment"
               	}
    13:00:51.74	My Object: @{
               		ID = "WriteLog", 
               		Name = "Write-Log", 
               		Folder = "C:\Users\User\PowerShell\Write-Log", 
               		Version = "01.00.02", 
               		Author = "Ronald Bode", 
               		Modified = "2017-05-31", 
               		Notes = " Author: Ronald Bode Version: 01.00.02 Created: 2009-03-18 Modified: 2017-05-31", 
               		File = {
               			PSPath: "Microsoft.PowerShell.Core\FileSystem::C:\Users\User\PowerShell", 
               			PSParentPath: "Microsoft.PowerShell.Core\FileSystem::C:\Users\User\PowerShell", 
               			PSChildName: "Write-Log.ps1", 
               			PSDrive: [PSDriveInfo]..., 
               			PSProvider: [ProviderInfo]..., 
               			PSIsContainer: $False, 
               			Mode: "-a----", 
               			VersionInfo: [FileVersionInfo]..., 
               			BaseName: "Write-Log", 
               			Target: [List`1]..., 
               			LinkType: $Null, 
               			Name: "Write-Log.ps1", 
               			Length: 7862, 
               			DirectoryName: "C:\Users\User\PowerShell\Write-Log", 
               			Directory: [DirectoryInfo]..., 
               			IsReadOnly: $False, 
               			Exists: $True, 
               			FullName: "C:\Users\User\PowerShell\Write-Log\Write-Log.ps1", 
               			Extension: ".ps1", 
               			CreationTime: 2017-05-08T14:23:12, 
               			CreationTimeUtc: 2017-05-08T12:23:12, 
               			LastAccessTime: 2017-05-08T14:23:12, 
               			LastAccessTimeUtc: 2017-05-08T12:23:12, 
               			LastWriteTime: 2017-05-31T13:00:45, 
               			LastWriteTimeUtc: 2017-05-31T11:00:45, 
               			Attributes: Archive
               		}, 
               		Title = "Write-Log", 
               		Arguments = "", 
               		Created = "2009-03-18", 
               		Description = " A PowerShell framework for sophisticated logging", 
               		Synopsis = " Write-Log", 
               		Path = "C:\Users\User\PowerShell\Write-Log\Write-Log.ps1", 
               		Contents = "<# .Synopsis Write-Log .Description A PowerShell framework for sophisticated log...", 
               		Help = ".Synopsis Write-Log .Description A PowerShell framework for sophisticated loggin..."
               	}
    13:00:51.75	End

Parameters
----------

`-File:` *File location*
========================

Default: `%Temp%\<ScriptName>.log`

Overrules the standard location of the log file. The Parameter can be used in conjunction with other parameters and log entries but should normally be used the first time that the `Write-Log` cmdlet is invoked.

`-Preserve:` *file size*
========================

Default: `100k`

The log file size that should be preserved to backtrack earlier scripting sessions.

`-Separator:` *separator string*
================================

Default: `empty line`

The separator is used to define sessions for human reading and limiting the log file sizes when it grows larger than the value define with the `-Preserve` argument

`-Color:` *SystemColor*
=======================

Default: `Host foregroundColor`

This parameter is similar to the `-ForegroundColor` parameter for `Write-Host` and defines in what color the log entry is displayed, it has no influences on how the log entry is written in the log file.

`-Delimiter:` *delimiter string*
================================

Default:  ` ` (Single Space)

Represents the delimiter between each value being logged.

`-Indent:` *number of tabs*
===========================

Default: `0`

Number of extra tabs behind the timestamp

`-Prefix`
=========

Used for prefixing value information and suppresses a newline:

    Log -Prefix "Value:"
    Log $Value

Results in:

    Value: 123

`-Depth:` *maximum recursion depth*
===================================

Default: `1`

The maximum depth of which an object, array or hashtable is recursively displayed and logged.

`-Strip:` *length*
==================

Default: `80`

If enabled (-Strip >= 0), repetitive white spaces in embedded strings will be replaced by a single space and cut off at the given length (followed by 3 dots: ...)

`-Expand`
=========

Expand the object for better readability.
Example:

    Log $Host -Depth:3 -Expand

`-Type`
=======

Show the type of the (embedded) objects.

`-Delay`
========

Delays writing to the log file until the next `Write-Log` is invoked.

`-Debug`
========

Only when the script is launched with the -Debug parameter, the information is displayed and logged.
Example:

    Log $Host -Debug "Password:" $Password

`-Verbose`
==========

Only when the script is launched with the -Verbose parameter, the information is displayed and logged.

Note: a `Write-Log` without any parameters will usually not display or log anything, instead it will process delayed entries and check for native errors.


----------

2017-05-31 Update
-----------------

Added -Strip option _for embedded strings_: by default, repetitive white spaces will be replaced by a single space and cut off after 80 characters (followed by 3 dots: ...)



  [1]: https://stackoverflow.com/questions/15120597/passing-multiple-values-to-a-single-powershell-script-parameter/37973722#37973722
  [2]: http://stackoverflow.com/questions/15139552/save-hash-table-in-powershell-object-notation-pson/24854277#24854277










