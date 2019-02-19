#========================================================================================
# PowerShell Source File
#
# NAME: GetGroupContents.ps1
#
# Author: MLABworld
# Date: 7/26/18
#
# This can be used for automating the notifications to AD group owners requesting
# validation of group membership.
#========================================================================================
#
# Import ActiveDirectory PowerShell Module
Import-Module ActiveDirectory
#
# Array to hold the names of the AD Groups to be audited
# Define them like this "<GROUPNAME>," ... with no comma after the last entry
$GroupsToAudit =  @(
                "AD_GROUP_1",
                "AD_GROUP_2",
                "AD_GROUP_3"
                    )
# Initalize the $SentTo array
$SentTo = @() 
# Loop through the AD groups array
foreach ($Grp in $GroupsToAudit)
    {   # Array to hold the computer names and last logon
        $computers = @()
        # Get the members of the AD Group (this contains Computers)
        $GroupObj = Get-ADGroupMember $Grp
            # Add the computers and LastLogon to the array.
            foreach($member in $GroupObj)
            {
                # Get the Computer Name
                $computer = $member.name
                # Query SCCM for the last logged on user for the computer
                $userAcct = (Get-WmiObject -namespace root\sms\site_AOP -computer <SCCM_PRIMARY_SITE_SERVER> -Query "SELECT SMS_R_System.LastLogonUserName FROM SMS_R_System WHERE Name='$computer'").LastLogonUserName
                # Sometimes SCCM returns $null if there is no value for the LastLogonUserName. Test for that here and set the variable to a space if it's $null
                    If ($userAcct -eq $null)
                    { 
                        $userName = " "
                    }
                    else 
                    {
                        $userName = (Get-ADUser $userAcct -Properties DisplayName).DisplayName
                    }
                # Create a new variable to hold the computer name and last logon 
                $CompAndUser = $computer + " " + $userName
                # Add the newly discoverd computer and last logon to the Array
                $computers += $CompAndUser
            }
        # Count the number of computers in the array and format it so there is one per line
        $count = $GroupObj.Count
        $ftComputers = $computers -join "`n"
    
        # Get the email address for the Manager's account
        # Lookup ManagedBy Distinguished Name object
         $MgrDNObj = (get-adgroup $Grp -Properties managedby)
         # Store this value as a string
         $Mgr = $MgrDNObj.managedby
         # Lookup Email Address object using the manager's distingiushed name
         $MgrEmailObj = (Get-ADUser $Mgr -Properties EmailAddress)
         # Store this value as a string
         $MgrEmail = $MgrEmailObj.EmailAddress
         # Lookup the manager's First and last name
         $MgrFirstName = ((Get-Aduser $Mgr -Properties GivenName).GivenName)
         $MgrLastName = ((Get-Aduser $Mgr -Properties sn).sn)
         # Keep track of who got emailed
         $SentTo += "$MgrFirstname $MgrLastName for the $Grp group. Computer count = $count.`n"

         #########
         ## Send email to each recipient
         ##########
             Send-MailMessage `
             -From "VerifyGroupMembership@<DOMAIN>.com" `
             -To $MgrEmail `
             -Subject "Please validate Group Membership" `
             -SmtpServer "<SMTP_SERVER_NAME>" `
             -Body "Hello $MgrFirstName, `n
             As the person respolsible for the membership of the $Grp group, please verify that the following computers still belong in the group. `n
             Group $Grp contains $($count) computers. Here are their names and the last user to logon. `n$($ftComputers) `n
             Please respond stating that this infomation is correct or if there are any corrections that need to be made."
     }

 #########
 ## Send summary emil section
 ##########
 Send-MailMessage `
 -From "VerifyGroupMembership@<DOMAIN>.com" `
 -To "VerifyGroupMembership@<DOMAIN.com" `
 -Subject "Group Membership Validation Email Sent" `
 -SmtpServer "<SMTP_SERVER_NAME>" `
 -Body "Validation email sent to the following responsible parties. `n
 $SentTo"
